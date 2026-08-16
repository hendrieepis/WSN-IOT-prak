// Minggu 16 — Proyek Komparatif: gateway C6 terima BLE lalu publish ke MQTT
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <WiFi.h>
#include <PubSubClient.h>

#define SERVICE_UUID    "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TELEM_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b2"

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

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress sensorAddr;
static bool doConnect = false;
static bool connected = false;

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  void onConnect(NimBLEClient *pClient) override { connected = true; Serial.println("BLE: terhubung ke sensor"); }
  void onDisconnect(NimBLEClient *pClient, int reason) override { connected = false; Serial.println("BLE: terputus"); }
};

// Callback notify NimBLE 2.x: sebuah fungsi, bukan objek callback
static void onTelemetry(NimBLERemoteCharacteristic *pChar, uint8_t *pData,
                        size_t length, bool isNotify) {
  char payload[64];
  size_t n = length < sizeof(payload) - 1 ? length : sizeof(payload) - 1;
  memcpy(payload, pData, n);
  payload[n] = '\0';

  Serial.printf("RX BLE: %s\n", payload);
  if (mqtt.connected()) {
    mqtt.publish(TOPIC_TELEM, payload);
    Serial.printf("Publish MQTT [%s]: %s\n", TOPIC_TELEM, payload);
  }
}

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *d) override {
    if (d->getName() == "CMP_SENSOR") {
      Serial.println("Sensor BLE ditemukan");
      sensorAddr = d->getAddress();
      doConnect = true;
      NimBLEDevice::getScan()->stop();
    }
  }
};

static bool connectToSensor() {
  NimBLEClient *pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(sensorAddr)) {
    Serial.println("BLE: gagal terhubung");
    NimBLEDevice::deleteClient(pClient);
    return false;
  }

  NimBLERemoteService *pService = pClient->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.println("BLE: service tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  NimBLERemoteCharacteristic *pChar = pService->getCharacteristic(CHAR_TELEM_UUID);
  if (pChar == nullptr) {
    Serial.println("BLE: characteristic tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  if (pChar->canNotify()) {
    pChar->subscribe(true, onTelemetry);
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Gateway (BLE -> MQTT) starting...");

  // Wi-Fi + MQTT
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);   // modem sleep memperburuk asosiasi saat sinyal lemah
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

  mqtt.setServer(MQTT_BROKER, MQTT_PORT);

  // BLE
  NimBLEDevice::init("CMP_GATEWAY");
  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // NimBLE 2.x: durasi dalam milidetik -> 5 detik
  Serial.println("Scanning sensor BLE...");
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

  if (doConnect) {
    if (connectToSensor()) Serial.println("BLE: koneksi berhasil");
    doConnect = false;
  }
  delay(10);
}
