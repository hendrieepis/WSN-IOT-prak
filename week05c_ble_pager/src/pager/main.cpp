// ============================================================================
// MODUL 05C — Pager Pelanggan (peripheral)
//
// Satu unit pager restoran. Menunggu perintah dari controller kasir, lalu
// memanggil pelanggan dengan LED dan buzzer sampai tombol ACK ditekan.
//
// Nomor pager datang dari build flag (-DPAGER_ID=101) sehingga ketiga unit
// memakai file source yang sama persis.
// ============================================================================
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <Adafruit_NeoPixel.h>

#ifndef PAGER_ID
#define PAGER_ID 101
#endif

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_CMD_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b1"     // controller -> pager
#define CHAR_STATUS_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"  // pager -> controller

// Waveshare ESP32-H2-DEV-KIT-N4
#define PIN_LED 8      // WS2812 onboard, urutan byte RGB
#define PIN_BUZZER 10  // buzzer pasif di header, bukan strapping pin
#define PIN_ACK 9      // tombol BOOT (Key2), aktif LOW, pull-up 10K di board

#define DEBOUNCE_MS 50
#define BEEP_MS 250       // panjang satu nada dan satu jeda
#define BEEP_HZ 2400      // nada buzzer saat memanggil
#define BLINK_MS 250      // kedip LED saat memanggil

Adafruit_NeoPixel strip(1, PIN_LED, NEO_RGB + NEO_KHZ800);

static bool memanggil = false;         // sedang memanggil pelanggan?
static bool buzzerAktif = false;       // tone() sedang berjalan?
static unsigned long mulaiPanggil = 0; // untuk mengukur waktu tanggap
static bool terhubung = false;
static NimBLECharacteristic *pStatus = nullptr;

static void berhentiMemanggil() {
  memanggil = false;
  // noTone() pada pin yang tidak sedang berbunyi memunculkan galat di log,
  // dan panggilan bisa berhenti saat buzzer sedang di fase diam.
  if (buzzerAktif) {
    noTone(PIN_BUZZER);
    buzzerAktif = false;
  }
  strip.setPixelColor(0, 0);
  strip.show();
}

class CmdCallbacks : public NimBLECharacteristicCallbacks {
public:
  void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo &connInfo) override {
    String cmd = String(pChar->getValue().c_str());
    cmd.trim();

    if (cmd == "READY") {
      // Perintah ini hanya tiba di pager yang dituju controller. Tidak ada
      // penyaringan nomor di sini: pemilihan tujuan terjadi di sisi controller,
      // lewat koneksi mana perintah dikirim.
      memanggil = true;
      mulaiPanggil = millis();
      Serial.printf("[PANGGIL] Pesanan siap — menunggu tombol ACK\n");
    } else if (cmd == "CANCEL") {
      berhentiMemanggil();
      Serial.println("[BATAL  ] Panggilan dibatalkan kasir");
    } else {
      Serial.printf("[WARN   ] Perintah tidak dikenal: %s\n", cmd.c_str());
    }
  }
};

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    terhubung = true;
    Serial.println("Controller terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    terhubung = false;
    Serial.println("Controller terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  Serial.printf("Pager #%d starting...\n", PAGER_ID);

  pinMode(PIN_ACK, INPUT_PULLUP);
  pinMode(PIN_BUZZER, OUTPUT);
  strip.begin();
  strip.setBrightness(60);
  strip.clear();
  strip.show();

  char nama[16];
  snprintf(nama, sizeof(nama), "PAGER_%d", PAGER_ID);
  NimBLEDevice::init(nama);

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);

  NimBLECharacteristic *pCmd =
      pService->createCharacteristic(CHAR_CMD_UUID, NIMBLE_PROPERTY::WRITE);
  pCmd->setCallbacks(new CmdCallbacks());

  pStatus = pService->createCharacteristic(CHAR_STATUS_UUID, NIMBLE_PROPERTY::NOTIFY);
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName(nama);
  pAdvertising->start();

  Serial.printf("Menunggu controller... (nama BLE: %s)\n", nama);
}

// Kedip LED dan bunyi buzzer dijalankan tanpa delay() supaya tombol ACK tetap
// terbaca selama pager sedang berbunyi.
static void tandaPanggilan() {
  static unsigned long tik = 0;
  static bool nyala = false;
  if (millis() - tik < BEEP_MS) return;
  tik = millis();
  nyala = !nyala;

  if (nyala) {
    strip.setPixelColor(0, strip.Color(255, 0, 0));
    tone(PIN_BUZZER, BEEP_HZ);
    buzzerAktif = true;
  } else {
    strip.setPixelColor(0, 0);
    if (buzzerAktif) {
      noTone(PIN_BUZZER);
      buzzerAktif = false;
    }
  }
  strip.show();
}

void loop() {
  if (memanggil) tandaPanggilan();

  // --- tombol ACK dengan debounce ----------------------------------------
  static bool stabil = HIGH, mentah = HIGH;
  static unsigned long berubah = 0;

  bool baca = digitalRead(PIN_ACK);
  if (baca != mentah) {
    mentah = baca;
    berubah = millis();
  }
  if (millis() - berubah < DEBOUNCE_MS || baca == stabil) return;
  stabil = baca;

  if (baca != LOW) return;  // hanya tepi turun (tombol mulai ditekan)

  if (!memanggil) {
    Serial.println("[INFO   ] Tombol ditekan, tetapi tidak ada panggilan aktif");
    return;
  }

  unsigned long tanggap = millis() - mulaiPanggil;
  berhentiMemanggil();

  char msg[32];
  snprintf(msg, sizeof(msg), "%d:ACK:%lu", PAGER_ID, tanggap);
  if (terhubung) {
    pStatus->setValue((const uint8_t *)msg, strlen(msg));
    pStatus->notify();
  }
  Serial.printf("[ACK    ] Pelanggan menekan tombol setelah %.1f s\n", tanggap / 1000.0);
}
