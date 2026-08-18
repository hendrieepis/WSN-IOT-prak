// ============================================================================
// MODUL 05B — Hub Smart Home (Central)
//
// Peran : BLE central, memelihara dua koneksi sekaligus ke smart sensor
//         jendela (Node A) dan pintu (Node B), lalu menerjemahkan payload
//         mentah menjadi status ruangan yang bisa dibaca manusia.
//         Sensor yang hilang disambungkan kembali otomatis, tanpa reset hub.
// Aktuator: LED RGB WS2812 onboard (GPIO8) sebagai lampu status ruangan —
//         kuning bila ada sensor hilang, merah bila ada bukaan, hijau bila
//         semua sensor terpantau dan tertutup.
// ============================================================================
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <Adafruit_NeoPixel.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_NOTIFY_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"

#define PIN_LED 8

#define SCAN_MS 5000            // lama satu putaran scan
#define RETRY_MS 3000           // jeda antar-percobaan sambung ulang
#define CONNECT_TIMEOUT_MS 4000 // batas satu percobaan connect (default lib 30 s)
#define RETRIES_BEFORE_RESCAN 3 // gagal sekian kali -> alamat dicari ulang

// Daftar sensor yang dilayani hub. Menambah sensor ketiga cukup menambah satu
// baris di sini — sisa kode sudah berbasis indeks.
struct SensorInfo {
  const char *bleName;  // nama advertising yang dicari saat scan
  const char *label;    // nama yang ditampilkan di log
};

static const SensorInfo SENSORS[] = {
    {"SENSOR_JENDELA1", "Jendela 1"},
    {"SENSOR_PINTU1", "Pintu 1"},
};
static const int SENSOR_COUNT = sizeof(SENSORS) / sizeof(SENSORS[0]);

// State per sensor. Alamat disalin (bukan pointer hasil scan) agar tetap valid
// setelah scan berhenti.
static NimBLEAddress addr[SENSOR_COUNT];
static bool found[SENSOR_COUNT] = {false};       // alamatnya sudah diketahui
static bool connected[SENSOR_COUNT] = {false};   // tautan sedang hidup
static bool isOpen[SENSOR_COUNT] = {false};      // jendela/pintu terbuka?
static NimBLEClient *client[SENSOR_COUNT] = {nullptr};

// Bahan sambung ulang otomatis
static uint8_t retries[SENSOR_COUNT] = {0};
static unsigned long nextTry[SENSOR_COUNT] = {0};
static unsigned long lostAt[SENSOR_COUNT] = {0};

Adafruit_NeoPixel strip(1, PIN_LED, NEO_RGB + NEO_KHZ800);

// Lampu status ruangan. Urutan prioritas dipilih supaya kondisi paling
// meragukan yang menang: sensor hilang lebih penting daripada "semua aman",
// karena hub tidak tahu apa yang terjadi di sisi sensor itu.
static void updateStatusLed() {
  bool anyLost = false, anyOpen = false;
  for (int i = 0; i < SENSOR_COUNT; i++) {
    anyLost |= !connected[i];
    anyOpen |= isOpen[i];
  }
  if (anyLost)      strip.setPixelColor(0, strip.Color(255, 150, 0));  // kuning
  else if (anyOpen) strip.setPixelColor(0, strip.Color(255, 0, 0));    // merah
  else              strip.setPixelColor(0, strip.Color(0, 255, 0));    // hijau
  strip.show();
}

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  ClientCallbacks(int idx) : _idx(idx) {}
  void onConnect(NimBLEClient *pClient) override {
    Serial.printf("%s terhubung\n", SENSORS[_idx].label);
  }
  // Callback ini berjalan di task NimBLE. Di sini hanya ditandai; percobaan
  // sambung ulang dikerjakan loop() — memanggil connect() dari dalam callback
  // stack BLE adalah cara cepat membuat hub hang.
  void onDisconnect(NimBLEClient *pClient, int reason) override {
    connected[_idx] = false;
    lostAt[_idx] = millis();
    nextTry[_idx] = millis() + RETRY_MS;
    retries[_idx] = 0;
    updateStatusLed();
    Serial.printf("[WARN ] %s terputus (reason %d) - mencoba sambung ulang\n",
                  SENSORS[_idx].label, reason);
  }

private:
  int _idx;
};

// Kumpulkan hasil scan untuk semua sensor (tanpa menghentikan scan)
class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *d) override {
    for (int i = 0; i < SENSOR_COUNT; i++) {
      if (!found[i] && d->getName() == SENSORS[i].bleName) {
        addr[i] = d->getAddress();
        found[i] = true;
        nextTry[i] = 0;  // alamat baru: coba sambung pada iterasi loop berikutnya
        Serial.printf("%s ditemukan (RSSI %d dBm)\n", SENSORS[i].label, d->getRSSI());
      }
    }
  }
};

// Payload node berbentuk "<ID>:<STATE>:<nomor event>", mis. "PINTU1:OPEN:3".
// Nomor event dibandingkan dengan yang terakhir diterima untuk menemukan
// kejadian yang hilang di udara.
static void handleEvent(int idx, const char *payload, size_t len) {
  static uint32_t lastSeq[SENSOR_COUNT] = {0};

  char buf[48];
  size_t n = len < sizeof(buf) - 1 ? len : sizeof(buf) - 1;
  memcpy(buf, payload, n);
  buf[n] = '\0';

  const char *state = strchr(buf, ':');
  const char *seqStr = state ? strchr(state + 1, ':') : nullptr;
  if (!state || !seqStr) {
    Serial.printf("[WARN ] payload tidak dikenal dari %s: %s\n", SENSORS[idx].label, buf);
    return;
  }

  bool opened = (strncmp(state + 1, "OPEN", 4) == 0);
  uint32_t seq = strtoul(seqStr + 1, nullptr, 10);

  if (lastSeq[idx] && seq > lastSeq[idx] + 1)
    Serial.printf("[LOSS ] %s: %lu kejadian tidak sampai ke hub\n", SENSORS[idx].label,
                  (unsigned long)(seq - lastSeq[idx] - 1));
  lastSeq[idx] = seq;

  isOpen[idx] = opened;
  updateStatusLed();

  Serial.printf("%s [%7.3f s] %s %s (event #%lu)\n", opened ? "[ALARM]" : "[INFO ]",
                millis() / 1000.0, SENSORS[idx].label,
                opened ? "TERBUKA" : "tertutup kembali", (unsigned long)seq);
}

static void ensureScanning() {
  NimBLEScan *pScan = NimBLEDevice::getScan();
  if (!pScan->isScanning()) pScan->start(SCAN_MS, false);
}

// Sambung + subscribe. Dipakai untuk koneksi pertama maupun sambung ulang;
// objek client dipakai ulang karena jumlah client NimBLE terbatas.
static bool connectAndSubscribe(int idx) {
  const char *label = SENSORS[idx].label;

  if (client[idx] == nullptr) {
    client[idx] = NimBLEDevice::createClient();
    client[idx]->setClientCallbacks(new ClientCallbacks(idx));
    // Default library 30 detik: satu percobaan ke sensor yang mati akan
    // menahan loop() selama itu, sehingga logika retry/scan-ulang di bawah
    // praktis tidak pernah jalan. 4 detik membuatnya benar-benar berputar.
    client[idx]->setConnectTimeout(CONNECT_TIMEOUT_MS);
  }

  // Scan dan connect berebut radio yang sama — hentikan dulu.
  NimBLEScan *pScan = NimBLEDevice::getScan();
  if (pScan->isScanning()) pScan->stop();

  if (!client[idx]->connect(addr[idx])) {
    Serial.printf("Gagal terhubung ke %s\n", label);
    return false;
  }

  NimBLERemoteService *pService = client[idx]->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.printf("Service %s tidak ditemukan\n", label);
    client[idx]->disconnect();
    return false;
  }

  NimBLERemoteCharacteristic *pChar = pService->getCharacteristic(CHAR_NOTIFY_UUID);
  if (pChar == nullptr) {
    Serial.printf("Characteristic %s tidak ditemukan\n", label);
    client[idx]->disconnect();
    return false;
  }

  if (pChar->canNotify()) {
    // Subscribe WAJIB diulang tiap kali menyambung: nilai CCCD hilang saat
    // koneksi putus karena kedua sisi tidak melakukan bonding.
    // notify_callback NimBLE 2.x adalah std::function -> lambda boleh menangkap
    // indeks sensor. Inilah yang membuat hub tahu asal pesan — bukan prefiks
    // pada payload.
    if (!pChar->subscribe(true, [idx](NimBLERemoteCharacteristic *c, uint8_t *data, size_t length,
                                      bool isNotify) { handleEvent(idx, (const char *)data, length); })) {
      Serial.printf("Gagal subscribe ke %s\n", label);
      client[idx]->disconnect();
      return false;
    }
  }

  connected[idx] = true;
  retries[idx] = 0;
  updateStatusLed();
  return true;
}

// Dipanggil tiap iterasi loop: jaga agar semua sensor tetap tersambung.
static void maintainLinks() {
  unsigned long now = millis();

  for (int i = 0; i < SENSOR_COUNT; i++) {
    if (connected[i]) continue;

    if (!found[i]) {  // alamat belum/tidak lagi diketahui -> cari lewat scan
      ensureScanning();
      continue;
    }
    if ((long)(now - nextTry[i]) < 0) continue;
    nextTry[i] = now + RETRY_MS;

    if (connectAndSubscribe(i)) {
      if (lostAt[i])
        Serial.printf("[PULIH] %s tersambung lagi setelah %.1f s\n", SENSORS[i].label,
                      (millis() - lostAt[i]) / 1000.0);
      lostAt[i] = 0;
    } else if (++retries[i] >= RETRIES_BEFORE_RESCAN) {
      // Board sensor mungkin sudah restart dengan alamat lain — buang alamat
      // lama dan cari ulang lewat scan.
      Serial.printf("%s tidak menjawab %d kali - scan ulang\n", SENSORS[i].label, retries[i]);
      found[i] = false;
      retries[i] = 0;
      ensureScanning();
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("Hub Smart Home (BLE central) starting...");

  strip.begin();
  strip.setBrightness(50);
  updateStatusLed();  // kuning: belum ada sensor yang terpantau

  NimBLEDevice::init("HUB_RUMAH");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(SCAN_MS, false);  // scan 5 detik (ms di NimBLE 2.x)

  Serial.println("Mencari smart sensor jendela dan pintu...");
}

void loop() {
  static bool announced = false;

  maintainLinks();

  bool allUp = true;
  for (int i = 0; i < SENSOR_COUNT; i++) allUp &= connected[i];
  if (allUp && !announced) {
    Serial.println("Semua sensor terpantau - sistem siaga");
    announced = true;
  } else if (!allUp) {
    announced = false;  // supaya pesan siaga muncul lagi setelah pulih
  }

  delay(100);
}
