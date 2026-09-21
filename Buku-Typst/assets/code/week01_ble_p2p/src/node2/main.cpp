#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress node1Addr;
static bool doConnect = false;
static bool connected = false;

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
  NimBLEClient *pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(node1Addr)) {
    Serial.println("Gagal terhubung");
    NimBLEDevice::deleteClient(pClient);
    return false;
  }

  NimBLERemoteService *pService = pClient->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.println("Service tidak ditemukan");
    pClient->disconnect();
    return false;
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Node2 (BLE Central) starting...");

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

  static unsigned long lastPrint = 0;
  if (connected && millis() - lastPrint > 5000) {
    lastPrint = millis();
    Serial.println("Status: H2 <-> H2 terhubung");
  }
}
