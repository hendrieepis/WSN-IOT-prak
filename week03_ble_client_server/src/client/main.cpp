#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_COUNTER_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b0"
#define CHAR_CMD_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26b1"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress serverAddr;
static bool doConnect = false;
static bool connected = false;
static NimBLERemoteCharacteristic *pCounter = nullptr;
static NimBLERemoteCharacteristic *pCmd = nullptr;

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  void onConnect(NimBLEClient *pClient) override {
    connected = true;
    Serial.println("Terhubung ke server");
  }
  void onDisconnect(NimBLEClient *pClient, int reason) override {
    connected = false;
    Serial.println("Terputus dari server");
  }
};

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *advertisedDevice) override {
    if (advertisedDevice->getName() == "GATT_SERVER") {
      Serial.println("Server ditemukan");
      serverAddr = advertisedDevice->getAddress();
      doConnect = true;
      NimBLEDevice::getScan()->stop();
    }
  }
};

static bool connectToServer() {
  NimBLEClient *pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(serverAddr)) {
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

  pCounter = pService->getCharacteristic(CHAR_COUNTER_UUID);
  pCmd = pService->getCharacteristic(CHAR_CMD_UUID);
  if (pCounter == nullptr || pCmd == nullptr) {
    Serial.println("Characteristic tidak ditemukan");
    pClient->disconnect();
    return false;
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("GATT Client starting...");

  NimBLEDevice::init("GATT_CLIENT");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // NimBLE 2.x: durasi dalam milidetik -> 5 detik

  Serial.println("Scanning server...");
}

void loop() {
  if (doConnect) {
    if (connectToServer()) {
      Serial.println("Koneksi berhasil");
    }
    doConnect = false;
  }

  if (!connected) return;

  static unsigned long lastRead = 0;
  if (millis() - lastRead > 2000) {
    lastRead = millis();
    NimBLEAttValue value = pCounter->readValue();
    Serial.print("READ counter = ");
    Serial.println(value.c_str());
  }

  static unsigned long lastWrite = 0;
  if (millis() - lastWrite > 5000) {
    lastWrite = millis();
    const char *cmd = "ON";
    // response = true: CHAR_CMD hanya punya property WRITE (bukan WRITE_NR)
    pCmd->writeValue((const uint8_t *)cmd, strlen(cmd), true);
    Serial.println("WRITE perintah: ON");
  }
}
