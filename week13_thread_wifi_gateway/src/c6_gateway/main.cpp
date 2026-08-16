// Minggu 13 — Thread -> Wi-Fi Gateway: C6 terima telemetry Thread, teruskan via Wi-Fi
#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "OThread.h"
#include "OThreadUDP.h"
#include "esp_openthread.h"
#include "esp_openthread_lock.h"
#include <openthread/thread.h>
#include "esp_netif.h"
#include "esp_coexist.h"

const char *WIFI_SSID = "NAMA_WIFI";
const char *WIFI_PASS = "PASSWORD_WIFI";

// Batas waktu menunggu Wi-Fi/MQTT saat boot; melewati batas ini setup() tetap
// dilanjutkan agar kegagalan sisi IP tidak menyembunyikan sisi radio lain.
const unsigned long WIFI_TIMEOUT_MS = 30000;
// Jeda antar percobaan sambung ulang. Harus lebih panjang dari durasi
// asosiasi pada sinyal lemah, kalau tidak percobaan berikutnya justru
// membatalkan yang sedang berjalan.
const unsigned long WIFI_RETRY_MS = 20000;
const unsigned long MQTT_TIMEOUT_MS = 15000;

// Endpoint tujuan di sisi Wi-Fi (ganti sesuai server Anda)
const char *SERVER_URL = "http://httpbin.org/post";

const char OT_NETWORK_NAME[] = "ESP_OT_GW";
const uint8_t  OT_CHANNEL = 15;
const uint16_t OT_PAN_ID  = 0xABCD;
const uint8_t  OT_EXTPANID[OT_EXT_PAN_ID_SIZE] = {0xDE, 0xAD, 0x00, 0xBE, 0xEF, 0x00, 0xCA, 0xFE};
const uint8_t  OT_NETKEY[OT_NETWORK_KEY_SIZE] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff};

const uint16_t PORT = 5050;
const uint8_t  GROUP_BYTES[16] = {0xff, 0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xab, 0xcd};
const IPAddress GROUP(IPv6, GROUP_BYTES);

// Prefix mesh-local dipaksa sama di H2 dan C6. DataSet::initNew() mengacak
// prefix ini per board; node dengan prefix berbeda tetap bisa attach, tetapi
// trafik multicast mesh (ff03::/16) tidak akan sampai ke gateway.
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] = {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};

// Harus dipanggil sebelum OThread.start() (stack masih berhenti).
static void applyMeshLocalPrefix() {
  otMeshLocalPrefix prefix;
  memcpy(prefix.m8, OT_ML_PREFIX, OT_MESH_LOCAL_PREFIX_SIZE);
  esp_openthread_lock_acquire(portMAX_DELAY);
  otThreadSetMeshLocalPrefix(esp_openthread_get_instance(), &prefix);
  esp_openthread_lock_release();
}

// Board ini punya dua netif sekaligus (Wi-Fi STA dan OpenThread). Pastikan
// default netif lwIP tetap Wi-Fi STA supaya trafik IPv4 keluar (HTTP/MQTT)
// punya rute yang benar. Catatan hasil uji: ini praktik yang benar, tetapi
// BUKAN obat untuk kegagalan TCP karena starvation koeksistensi — lihat
// Bagian 7 README.
static void restoreWifiAsDefaultNetif() {
  esp_netif_t *sta = esp_netif_get_handle_from_ifkey("WIFI_STA_DEF");
  if (sta == nullptr) {
    Serial.println("Netif Wi-Fi STA tidak ditemukan; rute IPv4 mungkin salah.");
    return;
  }
  esp_err_t err = esp_netif_set_default_netif(sta);
  Serial.printf("Default netif dikembalikan ke Wi-Fi STA (err=%d)\n", (int)err);
}

OThreadUDP OtUdp;

void setup() {
  Serial.begin(115200);

  // URUTAN PENTING: Thread dinyalakan LEBIH DULU, baru Wi-Fi.
  // Wrapper OpenThread Arduino memanggil esp_event_loop_create_default() dan
  // menganggap ESP_ERR_INVALID_STATE sebagai kegagalan fatal. Kalau Wi-Fi
  // diinisialisasi duluan, event loop default sudah ada, sehingga
  // OThread.begin() gagal dan board panic
  // ("assert failed: otTaskletsSignalPending"). Sebaliknya, stack Wi-Fi
  // Arduino memang mentoleransi event loop yang sudah dibuat.

  // 1) Thread sebagai leader
  OThread.begin(false);
  // Dataset selalu ditulis ulang agar H2 dan C6 memakai parameter identik,
  // termasuk saat board masih menyimpan dataset dari modul sebelumnya.
  DataSet ds;
  ds.initNew();
  ds.setNetworkName(OT_NETWORK_NAME);
  ds.setChannel(OT_CHANNEL);
  ds.setPanId(OT_PAN_ID);
  ds.setExtendedPanId(OT_EXTPANID);
  ds.setNetworkKey(OT_NETKEY);
  OThread.commitDataSet(ds);
  applyMeshLocalPrefix();

  // 2) Wi-Fi disambungkan SEBELUM OThread.start()
  WiFi.mode(WIFI_STA);
  // JANGAN setSleep(false) di board yang juga menjalankan 802.15.4:
  // koeksistensi Wi-Fi + 802.15.4 pada ESP32-C6 mengandalkan modem sleep
  // untuk membagi airtime. Mematikannya membuat Wi-Fi meminta radio 100 %
  // sementara Thread juga selalu RX, sehingga TCP keluar hampir selalu gagal
  // (gejala: HTTP -1 / MQTT rc=-2 padahal IP sudah didapat).
  WiFi.setSleep(true);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.printf("Konek Wi-Fi %s", WIFI_SSID);
  // Batasi penantian: kalau SSID/password salah atau AP tidak ada, setup()
  // tetap lanjut supaya sisi radio lain (Thread/BLE) tetap bisa diamati.
  // Wi-Fi dicoba ulang di loop().
  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < WIFI_TIMEOUT_MS) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nWi-Fi OK, IP: %s | RSSI: %d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    Serial.printf("\nWi-Fi GAGAL setelah %lu s (status=%d). Lanjut tanpa Wi-Fi;\n"
                  "periksa WIFI_SSID/WIFI_PASS dan pastikan AP memancar di 2,4 GHz.\n",
                  WIFI_TIMEOUT_MS / 1000UL, (int)WiFi.status());
  }

  // Beri prioritas radio ke Wi-Fi sebelum 802.15.4 dinyalakan.
  esp_err_t coexErr = esp_coex_preference_set(ESP_COEX_PREFER_WIFI);
  Serial.printf("coex preference = WIFI (err=%d)\n", (int)coexErr);

  // 3) Baru radio Thread dinyalakan
  OThread.networkInterfaceUp();
  OThread.start();

  Serial.println("Menunggu attach Thread...");
  while (OThread.otGetDeviceRole() < OT_ROLE_CHILD) {
    delay(250);
  }
  Serial.printf("Thread attached as: %s\n", OThread.otGetStringDeviceRole());

  restoreWifiAsDefaultNetif();

  OtUdp.beginMulticast(GROUP, PORT);


  Serial.println("Gateway siap (Thread -> Wi-Fi).");
}

void forwardToWifi(const char *payload) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi terputus, skip forward");
    return;
  }
  HTTPClient http;
  // Timeout dilonggarkan: saat berbagi radio dengan 802.15.4, balasan server
  // bisa datang jauh lebih lambat dari default 5 detik.
  http.setConnectTimeout(8000);
  http.setTimeout(8000);
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");

  String body = String("{\"sensor\":\"h2\",\"data\":\"") + payload + "\"}";
  int code = http.POST(body);
  Serial.printf("Forward via Wi-Fi -> %s | HTTP %d\n", SERVER_URL, code);
  http.end();
}

// Sambung ulang Wi-Fi berkala; tanpa ini gateway tidak pernah pulih setelah AP
// sempat mati, padahal sisi Thread-nya tetap jalan.
static void maintainWifi() {
  static unsigned long lastTry = 0;
  if (WiFi.status() == WL_CONNECTED) return;
  if (millis() - lastTry < WIFI_RETRY_MS) return;
  lastTry = millis();
  // JANGAN WiFi.disconnect() di sini: pada sinyal lemah, asosiasi bisa perlu
  // > 10 detik, dan memutusnya tiap percobaan membuat Wi-Fi tidak pernah
  // selesai menyambung.
  Serial.printf("Wi-Fi belum tersambung (status=%d), mencoba lagi...\n",
                (int)WiFi.status());
  WiFi.begin(WIFI_SSID, WIFI_PASS);
}

void loop() {
  maintainWifi();

  while (int n = OtUdp.parsePacket()) {
    char buf[64];
    int got = OtUdp.read((uint8_t *)buf, (n < (int)sizeof(buf) - 1) ? n : (int)sizeof(buf) - 1);
    buf[got] = '\0';
    Serial.printf("RX via Thread [%s]: %s\n", OtUdp.remoteIP().toString().c_str(), buf);
    forwardToWifi(buf);
  }
  delay(10);
}
