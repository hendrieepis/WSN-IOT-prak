#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_RELAY_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26b4"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress nodeBAddr;
static bool doConnect = false;
static bool connected = false;

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  void onConnect(NimBLEClient *pClient) override { connected = true; Serial.println("Terhubung ke Node B"); }
  void onDisconnect(NimBLEClient *pClient, int reason) override { connected = false; Serial.println("Terputus dari Node B"); }
};

// Callback notify NimBLE 2.x: sebuah fungsi, bukan objek callback
static void onNotifyFromB(NimBLERemoteCharacteristic *pChar, uint8_t *pData,
                          size_t length, bool isNotify) {
  Serial.printf("Pesan tiba (via A -> B -> C): %.*s\n", (int)length, (const char *)pData);
}

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *d) override {
    if (d->getName() == "MESH_NODE_B") {
      Serial.println("Node B ditemukan");
      nodeBAddr = d->getAddress();
      doConnect = true;
      NimBLEDevice::getScan()->stop();
    }
  }
};

static bool connectToB() {
  NimBLEClient *pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(nodeBAddr)) {
    Serial.println("Gagal terhubung ke B");
    NimBLEDevice::deleteClient(pClient);
    return false;
  }

  NimBLERemoteService *pService = pClient->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.println("Service B tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  NimBLERemoteCharacteristic *pChar = pService->getCharacteristic(CHAR_RELAY_UUID);
  if (pChar == nullptr) {
    Serial.println("Characteristic B tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  if (pChar->canNotify()) {
    pChar->subscribe(true, onNotifyFromB);
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Node C (penerima akhir) starting...");

  NimBLEDevice::init("MESH_NODE_C");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // NimBLE 2.x: durasi dalam milidetik -> 5 detik

  Serial.println("Scanning Node B...");
}

void loop() {
  if (doConnect) {
    if (connectToB()) Serial.println("Koneksi ke B berhasil");
    doConnect = false;
  }
}
