#include <Arduino.h>
#include <NimBLEDevice.h>

// Node B = relay: client ke A (menerima) sekaligus server ke C (meneruskan)

#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_RELAY_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26b4"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress nodeAAddr;
static bool doConnect = false;
static bool connected = false;
static NimBLECharacteristic *pRelayOut = nullptr;  // notify ke C

static String pendingForward = "";
static volatile bool hasPending = false;

// --- Bagian server (untuk Node C) ---
class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    Serial.println("Node C terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    Serial.println("Node C terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

// --- Bagian client (ke Node A) ---
class ClientCallbacks : public NimBLEClientCallbacks {
public:
  void onConnect(NimBLEClient *pClient) override { connected = true; Serial.println("Terhubung ke Node A"); }
  void onDisconnect(NimBLEClient *pClient, int reason) override { connected = false; Serial.println("Terputus dari Node A"); }
};

// Callback notify NimBLE 2.x: sebuah fungsi, bukan objek callback
static void onNotifyFromA(NimBLERemoteCharacteristic *pChar, uint8_t *pData,
                          size_t length, bool isNotify) {
  char buf[64];
  size_t n = length < sizeof(buf) - 1 ? length : sizeof(buf) - 1;
  memcpy(buf, pData, n);
  buf[n] = '\0';
  Serial.printf("Terima dari A: %s (diteruskan)\n", buf);
  pendingForward = buf;
  hasPending = true;
}

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *d) override {
    if (d->getName() == "MESH_NODE_A") {
      Serial.println("Node A ditemukan");
      nodeAAddr = d->getAddress();
      doConnect = true;
      NimBLEDevice::getScan()->stop();
    }
  }
};

static bool connectToA() {
  NimBLEClient *pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(nodeAAddr)) {
    Serial.println("Gagal terhubung ke A");
    NimBLEDevice::deleteClient(pClient);
    return false;
  }

  NimBLERemoteService *pService = pClient->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.println("Service A tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  NimBLERemoteCharacteristic *pChar = pService->getCharacteristic(CHAR_RELAY_UUID);
  if (pChar == nullptr) {
    Serial.println("Characteristic A tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  if (pChar->canNotify()) {
    pChar->subscribe(true, onNotifyFromA);
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Node B (relay) starting...");

  NimBLEDevice::init("MESH_NODE_B");

  // Server untuk C
  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  pRelayOut = pService->createCharacteristic(CHAR_RELAY_UUID, NIMBLE_PROPERTY::NOTIFY);
  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("MESH_NODE_B");
  pAdvertising->start();

  // Client ke A
  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // NimBLE 2.x: durasi dalam milidetik -> 5 detik

  Serial.println("Menunggu A dan C...");
}

void loop() {
  if (doConnect) {
    if (connectToA()) Serial.println("Koneksi ke A berhasil");
    doConnect = false;
  }

  if (hasPending) {
    hasPending = false;
    pRelayOut->setValue((const uint8_t *)pendingForward.c_str(), pendingForward.length());
    pRelayOut->notify();
    Serial.println("Teruskan ke C: " + pendingForward);
  }
}
