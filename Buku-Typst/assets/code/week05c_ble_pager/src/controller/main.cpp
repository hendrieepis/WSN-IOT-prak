// ============================================================================
// MODUL 05C — Order Controller / Kasir (central)
//
// Memegang satu koneksi BLE untuk tiap pager, lalu mengirim perintah hanya ke
// pager yang dituju. Perintah diketikkan kasir di Serial Monitor:
//
//     READY 102     panggil pemilik pesanan pager 102
//     CANCEL 102    batalkan panggilan
//     LIST          tampilkan status semua pager
//
// Catatan penting: ini BUKAN broadcast. Tidak ada satu paket pun yang tersiar
// ke semua pager. Controller memilih objek koneksi milik pager tujuan, lalu
// menulis ke characteristic perintah pada koneksi itu saja.
//
// Batas perangkat keras: ESP32-H2 pada Arduino core ini hanya sanggup memegang
// DUA koneksi BLE serentak (koneksi ketiga membuat controller reboot). Karena
// itu koneksi tidak dipelihara terus-menerus untuk semua pager, melainkan
// dibuka saat sebuah pager dipanggil dan ditutup setelah pelanggan menekan
// ACK. Alamat hasil pemindaian tetap disimpan agar penyambungan berikutnya
// tidak perlu memindai ulang.
// ============================================================================
#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_CMD_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b1"     // controller -> pager
#define CHAR_STATUS_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"  // pager -> controller

#define SCAN_MS 5000
#define CONNECT_TIMEOUT_MS 4000

// Sengaja 2, bukan angka yang dikira-kira: koneksi ketiga membuat controller
// BLE ESP32-H2 gagal mengalokasikan callout dan board reboot.
#define MAX_KONEKSI 2

// Daftar pager yang dilayani. Menambah pager keempat cukup satu baris di sini
// plus satu environment baru di platformio.ini.
static const int PAGER_ID[] = {101, 102, 103};
static const int JUMLAH_PAGER = sizeof(PAGER_ID) / sizeof(PAGER_ID[0]);

static NimBLEAddress alamat[JUMLAH_PAGER];
static bool ditemukan[JUMLAH_PAGER] = {false};
static bool tersambung[JUMLAH_PAGER] = {false};
static bool memanggil[JUMLAH_PAGER] = {false};
static unsigned long mulaiPanggil[JUMLAH_PAGER] = {0};
static NimBLEClient *klien[JUMLAH_PAGER] = {nullptr};
static NimBLERemoteCharacteristic *charCmd[JUMLAH_PAGER] = {nullptr};

static bool putuskanSetelahAck[JUMLAH_PAGER] = {false};

static int jumlahTersambung() {
  int n = 0;
  for (int i = 0; i < JUMLAH_PAGER; i++) n += tersambung[i] ? 1 : 0;
  return n;
}

static int indeksDariId(int id) {
  for (int i = 0; i < JUMLAH_PAGER; i++)
    if (PAGER_ID[i] == id) return i;
  return -1;
}

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  ClientCallbacks(int idx) : _idx(idx) {}
  void onConnect(NimBLEClient *c) override {
    Serial.printf("Pager #%d terhubung\n", PAGER_ID[_idx]);
  }
  // Percobaan sambung ulang dikerjakan loop(), bukan di dalam callback ini:
  // memanggil connect() dari stack NimBLE membuat controller hang.
  void onDisconnect(NimBLEClient *c, int reason) override {
    bool sedangMemanggil = memanggil[_idx];
    tersambung[_idx] = false;
    charCmd[_idx] = nullptr;
    memanggil[_idx] = false;
    // Putus setelah ACK adalah hal biasa — slot koneksi memang sengaja
    // dilepas. Yang perlu diberitahukan hanya putus di tengah panggilan.
    if (sedangMemanggil)
      Serial.printf("[WARN ] Pager #%d terputus di tengah panggilan (reason %d)\n",
                    PAGER_ID[_idx], reason);
  }

private:
  int _idx;
};

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *d) override {
    for (int i = 0; i < JUMLAH_PAGER; i++) {
      char nama[16];
      snprintf(nama, sizeof(nama), "PAGER_%d", PAGER_ID[i]);
      if (!ditemukan[i] && d->getName() == nama) {
        alamat[i] = d->getAddress();
        ditemukan[i] = true;
        Serial.printf("Pager #%d ditemukan (RSSI %d dBm)\n", PAGER_ID[i], d->getRSSI());
      }
    }
  }
};

// Payload status dari pager: "<id>:ACK:<milidetik tanggap>"
static void tanganiStatus(int idx, const char *data, size_t len) {
  char buf[40];
  size_t n = len < sizeof(buf) - 1 ? len : sizeof(buf) - 1;
  memcpy(buf, data, n);
  buf[n] = '\0';

  if (strstr(buf, ":ACK") == nullptr) {
    Serial.printf("[WARN ] Status tidak dikenal dari pager #%d: %s\n", PAGER_ID[idx], buf);
    return;
  }

  double tanggapPager = 0;
  const char *p = strrchr(buf, ':');
  if (p) tanggapPager = atol(p + 1) / 1000.0;

  double tanggapKasir = memanggil[idx] ? (millis() - mulaiPanggil[idx]) / 1000.0 : 0;
  memanggil[idx] = false;
  // Pemutusan dikerjakan loop(), bukan di sini: memanggil disconnect() dari
  // dalam callback notify berarti membongkar koneksi dari stack NimBLE sendiri.
  putuskanSetelahAck[idx] = true;

  Serial.printf("[ACK  ] Pager #%d diambil pelanggan - %.1f s menurut pager, "
                "%.1f s menurut kasir\n",
                PAGER_ID[idx], tanggapPager, tanggapKasir);
}

static void pastikanScan() {
  NimBLEScan *pScan = NimBLEDevice::getScan();
  if (!pScan->isScanning()) pScan->start(SCAN_MS, false);
}

static bool sambungkan(int idx) {
  int id = PAGER_ID[idx];
  if (klien[idx] == nullptr) {
    klien[idx] = NimBLEDevice::createClient();
    klien[idx]->setClientCallbacks(new ClientCallbacks(idx));
    // Default library 30 detik: satu percobaan ke pager mati akan menahan
    // loop() selama itu, sehingga kasir tidak bisa mengetik perintah.
    klien[idx]->setConnectTimeout(CONNECT_TIMEOUT_MS);
  }

  NimBLEScan *pScan = NimBLEDevice::getScan();
  if (pScan->isScanning()) pScan->stop();

  if (!klien[idx]->connect(alamat[idx])) {
    Serial.printf("Gagal terhubung ke pager #%d\n", id);
    return false;
  }

  NimBLERemoteService *pService = klien[idx]->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.printf("Service pager #%d tidak ditemukan\n", id);
    klien[idx]->disconnect();
    return false;
  }

  charCmd[idx] = pService->getCharacteristic(CHAR_CMD_UUID);
  NimBLERemoteCharacteristic *pStatus = pService->getCharacteristic(CHAR_STATUS_UUID);
  if (charCmd[idx] == nullptr || pStatus == nullptr) {
    Serial.printf("Characteristic pager #%d tidak lengkap\n", id);
    klien[idx]->disconnect();
    return false;
  }

  // Subscribe wajib diulang tiap kali menyambung: nilai CCCD hilang saat
  // koneksi putus karena kedua sisi tidak melakukan bonding.
  pStatus->subscribe(true, [idx](NimBLERemoteCharacteristic *c, uint8_t *data, size_t len,
                                 bool isNotify) { tanganiStatus(idx, (const char *)data, len); });

  tersambung[idx] = true;
  return true;
}

// Lepaskan koneksi pager yang panggilannya sudah selesai, supaya slot koneksi
// kembali tersedia untuk pager berikutnya.
static void lepaskanSlot() {
  for (int i = 0; i < JUMLAH_PAGER; i++) {
    if (!putuskanSetelahAck[i]) continue;
    putuskanSetelahAck[i] = false;
    if (klien[i] && klien[i]->isConnected()) {
      klien[i]->disconnect();
      Serial.printf("[LEPAS] Koneksi pager #%d ditutup - slot koneksi kembali bebas\n",
                    PAGER_ID[i]);
    }
  }
}

static void kirimPerintah(int idx, const char *cmd) {
  // Inilah inti modul ini: perintah ditulis ke SATU objek koneksi. Pager lain
  // tidak menerima apa pun — bukan karena menyaring, tetapi karena paketnya
  // memang tidak pernah dikirim ke mereka.
  if (!charCmd[idx]->writeValue((const uint8_t *)cmd, strlen(cmd), true)) {
    Serial.printf("[GAGAL] Perintah %s ke pager #%d tidak terkirim\n", cmd, PAGER_ID[idx]);
    return;
  }
  Serial.printf("[KIRIM] %s -> pager #%d saja (pager lain tidak menerima apa pun)\n", cmd,
                PAGER_ID[idx]);
}

static void tampilkanDaftar() {
  Serial.printf("--- Status pager (%d/%d slot koneksi terpakai) ---\n", jumlahTersambung(),
                MAX_KONEKSI);
  for (int i = 0; i < JUMLAH_PAGER; i++) {
    const char *st = memanggil[i]    ? "MEMANGGIL"
                     : tersambung[i] ? "tersambung"
                     : ditemukan[i]  ? "terdaftar"
                                     : "BELUM TERLIHAT";
    Serial.printf("  #%d : %-14s", PAGER_ID[i], st);
    if (tersambung[i] && memanggil[i])
      Serial.printf(" (%.0f s berjalan)", (millis() - mulaiPanggil[i]) / 1000.0);
    Serial.println();
  }
}

static void bantuan() {
  Serial.printf("Perintah: READY <id> | CANCEL <id> | LIST | HELP  "
                "(maksimum %d panggilan berjalan bersamaan)\n", MAX_KONEKSI);
}

static void olahPerintah(String baris) {
  baris.trim();
  if (baris.length() == 0) return;
  baris.toUpperCase();

  if (baris == "LIST") {
    tampilkanDaftar();
    return;
  }
  if (baris == "HELP") {
    bantuan();
    return;
  }

  int spasi = baris.indexOf(' ');
  if (spasi < 0) {
    Serial.printf("[GAGAL] Perintah tidak dikenal: %s\n", baris.c_str());
    bantuan();
    return;
  }

  String kata = baris.substring(0, spasi);
  int id = baris.substring(spasi + 1).toInt();
  int idx = indeksDariId(id);

  if (idx < 0) {
    Serial.printf("[GAGAL] Pager #%d tidak terdaftar\n", id);
    return;
  }
  if (kata == "READY") {
    if (!ditemukan[idx]) {
      Serial.printf("[GAGAL] Pager #%d belum pernah terlihat - pastikan pager menyala\n", id);
      return;
    }
    if (!tersambung[idx] && jumlahTersambung() >= MAX_KONEKSI) {
      Serial.printf("[GAGAL] Slot koneksi penuh (%d/%d). Tunggu ACK panggilan berjalan "
                    "atau CANCEL salah satunya.\n",
                    jumlahTersambung(), MAX_KONEKSI);
      return;
    }
    if (!tersambung[idx] && !sambungkan(idx)) {
      Serial.printf("[GAGAL] Tidak bisa menyambung ke pager #%d\n", id);
      return;
    }
    kirimPerintah(idx, "READY");
    memanggil[idx] = true;
    mulaiPanggil[idx] = millis();
  } else if (kata == "CANCEL") {
    if (!tersambung[idx]) {
      Serial.printf("[GAGAL] Pager #%d tidak sedang dipanggil\n", id);
      return;
    }
    kirimPerintah(idx, "CANCEL");
    memanggil[idx] = false;
    putuskanSetelahAck[idx] = true;
  } else {
    Serial.printf("[GAGAL] Perintah tidak dikenal: %s\n", kata.c_str());
    bantuan();
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("Order Controller (kasir) starting...");

  NimBLEDevice::init("ORDER_CONTROLLER");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(SCAN_MS, false);

  Serial.println("Mencari pager...");
}

void loop() {
  static bool siapDiumumkan = false;
  static String baris = "";

  lepaskanSlot();

  // Pemindaian dibiarkan berjalan sampai seluruh pager pernah terlihat, supaya
  // alamatnya siap dipakai begitu kasir memanggil.
  bool semuaTerlihat = true;
  for (int i = 0; i < JUMLAH_PAGER; i++) semuaTerlihat &= ditemukan[i];
  if (!semuaTerlihat) pastikanScan();

  if (semuaTerlihat && !siapDiumumkan) {
    Serial.printf("Seluruh %d pager terdaftar - kasir siap menerima perintah\n", JUMLAH_PAGER);
    bantuan();
    siapDiumumkan = true;
  }

  // Baris perintah dari Serial Monitor kasir
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (baris.length()) {
        olahPerintah(baris);
        baris = "";
      }
    } else if (baris.length() < 32) {
      baris += c;
    }
  }
}
