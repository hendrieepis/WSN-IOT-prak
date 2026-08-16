#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TX_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_RX_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a9"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress node1Addr;
static bool doConnect = false;
static bool connected = false;
static NimBLEClient *pClient = nullptr;
static NimBLERemoteCharacteristic *pRxCharacteristic = nullptr;
static unsigned long lastSend = 0;

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  void onConnect(NimBLEClient *pClient) override {
    connected = true;
    Serial.println("Terhubung ke Node1");
  }
  void onDisconnect(NimBLEClient *pClient, int reason) override {
    connected = false;
    Serial.println("Terputus dari Node1");
  }
};

// Callback notify NimBLE 2.x: sebuah fungsi, bukan objek callback
static void onNotify(NimBLERemoteCharacteristic *pChar, uint8_t *pData,
                     size_t length, bool isNotify) {
  Serial.print("RX dari Node1: ");
  Serial.write(pData, length);
  Serial.println();
}

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *advertisedDevice) override {
    if (advertisedDevice->getName() == "NODE1_H2") {
      Serial.println("Node1 ditemukan");
      node1Addr = advertisedDevice->getAddress();
      doConnect = true;
      NimBLEDevice::getScan()->stop();
    }
  }
};

static bool connectToNode1() {
  pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(node1Addr)) {
    Serial.println("Gagal terhubung");
    NimBLEDevice::deleteClient(pClient);
    pClient = nullptr;
    return false;
  }

  NimBLERemoteService *pService = pClient->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.println("Service tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  NimBLERemoteCharacteristic *pTx = pService->getCharacteristic(CHAR_TX_UUID);
  pRxCharacteristic = pService->getCharacteristic(CHAR_RX_UUID);
  if (pTx == nullptr || pRxCharacteristic == nullptr) {
    Serial.println("Characteristic tidak ditemukan");
    pClient->disconnect();
    return false;
  }

  if (pTx->canNotify()) {
    pTx->subscribe(true, onNotify);
  }

  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Node2 (BLE Client) starting...");

  NimBLEDevice::init("NODE2_H2");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // NimBLE 2.x: durasi dalam milidetik -> 5 detik

  Serial.println("Scanning Node1...");
}

void loop() {
  if (doConnect) {
    if (connectToNode1()) {
      Serial.println("Koneksi berhasil");
    }
    doConnect = false;
  }

  if (connected && pRxCharacteristic && millis() - lastSend > 3000) {
    lastSend = millis();
    String msg = "Halo dari Node2 (" + String(millis()) + ")";
    // response = true: CHAR_RX hanya punya property WRITE (bukan WRITE_NR)
    pRxCharacteristic->writeValue((const uint8_t *)msg.c_str(), msg.length(), true);
    Serial.println("TX ke Node1: " + msg);
  }
}
