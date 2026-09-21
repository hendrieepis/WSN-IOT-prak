#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TELEM_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26b2"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress sensorAddr;
static bool doConnect = false;
static bool connected = false;

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  void onConnect(NimBLEClient *pClient) override {
    connected = true;
    Serial.println("Terhubung ke sensor");
  }
  void onDisconnect(NimBLEClient *pClient, int reason) override {
    connected = false;
    Serial.println("Terputus dari sensor");
  }
};

// Callback notify NimBLE 2.x: sebuah fungsi, bukan objek callback
static void onTelemetry(NimBLERemoteCharacteristic *pChar, uint8_t *pData,
                        size_t length, bool isNotify) {
  Serial.print("Telemetry diterima: suhu = ");
  Serial.write(pData, length);
  Serial.println(" C");
}

class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *advertisedDevice) override {
    if (advertisedDevice->getName() == "TELEM_SENSOR") {
      Serial.println("Sensor ditemukan");
      sensorAddr = advertisedDevice->getAddress();
      doConnect = true;
      NimBLEDevice::getScan()->stop();
    }
  }
};

static bool connectToSensor() {
  NimBLEClient *pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(new ClientCallbacks());

  if (!pClient->connect(sensorAddr)) {
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

  NimBLERemoteCharacteristic *pTelemetry = pService->getCharacteristic(CHAR_TELEM_UUID);
  if (pTelemetry == nullptr) {
    Serial.println("Characteristic tidak ditemukan");
    pClient->disconnect();
    return false;
  }
  if (pTelemetry->canNotify()) {
    pTelemetry->subscribe(true, onTelemetry);
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Monitor Node starting...");

  NimBLEDevice::init("TELEM_MONITOR");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // NimBLE 2.x: durasi dalam milidetik -> 5 detik

  Serial.println("Scanning sensor...");
}

void loop() {
  if (doConnect) {
    if (connectToSensor()) {
      Serial.println("Koneksi berhasil, menunggu telemetry...");
    }
    doConnect = false;
  }
}
