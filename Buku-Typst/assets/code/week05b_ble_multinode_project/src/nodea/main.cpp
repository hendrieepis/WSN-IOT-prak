// ============================================================================
// MODUL 05B — Smart Sensor Jendela (Node A)
//
// Peran : BLE peripheral, dipasang di JENDELA 1.
// Sensor: tombol BOOT (GPIO9) mensimulasikan proximity/reed switch jendela.
//         Ditekan  -> jendela dianggap TERBUKA
//         Dilepas  -> jendela dianggap TERTUTUP
// Aktuator: LED RGB WS2812 onboard (GPIO8) berkedip sebentar tiap kali sensor
//         berubah, sebagai bukti visual bahwa sensor benar-benar terbaca.
// ============================================================================
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <Adafruit_NeoPixel.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_NOTIFY_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"

// Identitas sensor — dipakai sebagai prefiks payload agar hub bisa memisahkan
// sumber pesan tanpa bergantung pada urutan koneksi.
#define SENSOR_ID "JENDELA1"
#define BLE_NAME "SENSOR_JENDELA1"

// Waveshare ESP32-H2-DEV-KIT-N4: tombol BOOT (Key2) di GPIO9, aktif LOW
// dengan pull-up 10K di board; LED RGB WS2812 di GPIO8, urutan byte RGB.
#define PIN_SWITCH 9
#define PIN_LED 8
#define DEBOUNCE_MS 50
#define LED_ON_MS 300

Adafruit_NeoPixel strip(1, PIN_LED, NEO_RGB + NEO_KHZ800);

static bool deviceConnected = false;
static NimBLECharacteristic *pNotify = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    deviceConnected = true;
    Serial.println("Hub terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    deviceConnected = false;
    Serial.println("Hub terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

// Kedip non-blocking: warna diset sekarang, dimatikan oleh ledTick() nanti.
// delay() tidak dipakai agar loop tetap bisa membaca sensor selama LED menyala.
static unsigned long ledOffAt = 0;

static void ledFlash(uint8_t r, uint8_t g, uint8_t b) {
  strip.setPixelColor(0, strip.Color(r, g, b));
  strip.show();
  ledOffAt = millis() + LED_ON_MS;
}

static void ledTick() {
  if (ledOffAt && millis() >= ledOffAt) {
    strip.setPixelColor(0, 0);
    strip.show();
    ledOffAt = 0;
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("Smart sensor JENDELA 1 (peripheral) starting...");

  pinMode(PIN_SWITCH, INPUT_PULLUP);
  strip.begin();
  strip.setBrightness(50);
  strip.clear();
  strip.show();

  NimBLEDevice::init(BLE_NAME);

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  pNotify = pService->createCharacteristic(CHAR_NOTIFY_UUID, NIMBLE_PROPERTY::NOTIFY);
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName(BLE_NAME);
  pAdvertising->start();

  Serial.println("Menunggu hub... (tekan tombol BOOT = jendela dibuka)");
}

void loop() {
  ledTick();

  // --- Pembacaan proximity switch dengan debounce -------------------------
  static bool lastStable = HIGH;      // HIGH = tidak ditekan = jendela tertutup
  static bool lastRaw = HIGH;
  static unsigned long lastChange = 0;
  static uint32_t eventCount = 0;

  bool raw = digitalRead(PIN_SWITCH);
  if (raw != lastRaw) {
    lastRaw = raw;
    lastChange = millis();
  }
  if (millis() - lastChange < DEBOUNCE_MS || raw == lastStable) return;

  lastStable = raw;
  bool isOpen = (raw == LOW);  // tombol ditekan -> LOW -> jendela terbuka
  ++eventCount;

  // Indikator lokal: merah saat terbuka, hijau saat tertutup kembali.
  if (isOpen) ledFlash(255, 0, 0);
  else        ledFlash(0, 255, 0);

  // Payload: "<ID>:<STATE>:<nomor event>" — nomor event dipakai hub untuk
  // mendeteksi kejadian yang hilang saat pengukuran jarak.
  String msg = String(SENSOR_ID) + (isOpen ? ":OPEN:" : ":CLOSED:") + String(eventCount);

  if (deviceConnected) {
    pNotify->setValue((const uint8_t *)msg.c_str(), msg.length());
    pNotify->notify();
    Serial.println("Notify: " + msg);
  } else {
    // Sensor tetap bekerja (LED berkedip) walau hub belum tersambung —
    // pesannya yang hilang, bukan pembacaannya.
    Serial.println("Sensor aktif tapi hub belum tersambung: " + msg);
  }
}
