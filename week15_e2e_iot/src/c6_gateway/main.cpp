// Minggu 15 — End-to-End IoT: gateway C6 terima Thread lalu publish ke MQTT
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
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
// Jeda percobaan MQTT dipisah dari jeda Wi-Fi: saat Wi-Fi sudah sehat,
// tidak ada alasan menunggu selama asosiasi ulang.
const unsigned long MQTT_RETRY_MS = 4000;
const unsigned long MQTT_TIMEOUT_MS = 15000;

// Broker MQTT. Banyak jaringan kampus memblokir port 1883 keluar sehingga
// test.mosquitto.org tidak terjangkau (gejala: rc=-2 dan "Host is unreachable").
// Bila itu terjadi, jalankan `python3 tools/mqtt_broker.py` di laptop lalu ganti
// baris di bawah dengan alamat IP laptop tersebut, mis. "192.168.110.74".
const char *MQTT_BROKER = "test.mosquitto.org";
const uint16_t MQTT_PORT = 1883;
const char *TOPIC_TELEM = "praktikum/h2/telemetri";

const char OT_NETWORK_NAME[] = "ESP_OT_E2E";
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
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

void setup() {
  Serial.begin(115200);

  // URUTAN PENTING: Thread dinyalakan LEBIH DULU, baru Wi-Fi.
  // Wrapper OpenThread Arduino memanggil esp_event_loop_create_default() dan
  // menganggap ESP_ERR_INVALID_STATE sebagai kegagalan fatal. Kalau Wi-Fi
  // diinisialisasi duluan, event loop default sudah ada, sehingga
  // OThread.begin() gagal dan board panic
  // ("assert failed: otTaskletsSignalPending"). Sebaliknya, stack Wi-Fi
  // Arduino memang mentoleransi event loop yang sudah dibuat.

  // 1) Thread leader
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


  // Beri prioritas radio ke Wi-Fi sebelum 802.15.4 dinyalakan. Tanpa ini,
  // trafik TCP keluar hampir selalu gagal saat stack Thread aktif.
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

  // 4) Terakhir MQTT (butuh Wi-Fi sudah siap)
  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  unsigned long mqttStart = millis();
  while (!mqtt.connected() && millis() - mqttStart < MQTT_TIMEOUT_MS) {
    Serial.printf("Konek MQTT %s:%d ...\n", MQTT_BROKER, MQTT_PORT);
    if (!mqtt.connect("esp32c6-gateway")) {
      Serial.printf("Gagal (rc=%d)\n", mqtt.state());
      delay(2000);
    }
  }
  if (mqtt.connected()) {
    Serial.println("MQTT terhubung");
  } else {
    Serial.println("MQTT belum terhubung. Lanjut; dicoba ulang di loop().");
  }


  Serial.println("Gateway siap (H2 -> Thread -> C6 -> MQTT).");
}


// Pemeliharaan koneksi IP, dijalankan berkala dari loop().
// Rate-limited: tanpa ini, mqtt.connect() dipanggil tiap iterasi loop dan
// membanjiri Serial dengan kegagalan DNS saat Wi-Fi/broker tidak tersedia.
static void maintainNetwork(const char *clientId) {
  static unsigned long lastWifiTry = 0;
  static unsigned long lastMqttTry = 0;

  if (WiFi.status() == WL_CONNECTED) {
    // Wi-Fi sehat: percobaan MQTT tidak boleh ikut terkunci jeda panjang milik
    // Wi-Fi, kalau tidak kesempatan menyambung jadi jauh lebih sedikit.
    if (mqtt.connected() || millis() - lastMqttTry < MQTT_RETRY_MS) return;
    lastMqttTry = millis();
    if (mqtt.connect(clientId)) {
      Serial.println("MQTT terhubung");
    } else {
      Serial.printf("MQTT gagal (rc=%d), coba lagi %lu detik\n",
                    mqtt.state(), MQTT_RETRY_MS / 1000UL);
    }
    return;
  }

  if (millis() - lastWifiTry < WIFI_RETRY_MS) return;
  lastWifiTry = millis();
  {
    // JANGAN WiFi.disconnect() di sini: pada sinyal lemah, asosiasi bisa perlu
    // > 10 detik, dan memutusnya tiap percobaan membuat Wi-Fi tidak pernah
    // selesai menyambung. Cukup picu ulang WiFi.begin() dengan jeda panjang.
    Serial.printf("Wi-Fi belum tersambung (status=%d), mencoba lagi...\n",
                  (int)WiFi.status());
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    return;                       // MQTT percuma dicoba tanpa Wi-Fi
  }
}

void loop() {
  maintainNetwork("esp32c6-gateway");
  mqtt.loop();

  while (int n = OtUdp.parsePacket()) {
    char buf[64];
    int got = OtUdp.read((uint8_t *)buf, (n < (int)sizeof(buf) - 1) ? n : (int)sizeof(buf) - 1);
    buf[got] = '\0';
    Serial.printf("RX via Thread: %s\n", buf);

    // Laporkan apa adanya: hop Thread bisa sukses walau hop MQTT gagal.
    if (mqtt.connected() && mqtt.publish(TOPIC_TELEM, buf)) {
      Serial.printf("Publish MQTT [%s]: %s\n", TOPIC_TELEM, buf);
    } else {
      Serial.printf("Publish MQTT GAGAL (mqtt=%d), pesan Thread tidak diteruskan: %s\n",
                    mqtt.state(), buf);
    }
  }
  delay(10);
}
