#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TX_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_RX_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a9"

static bool deviceConnected = false;
static NimBLECharacteristic *pTxCharacteristic = nullptr;
static unsigned long lastSend = 0;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    deviceConnected = true;
    Serial.println("Client terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    deviceConnected = false;
    Serial.println("Client terputus, mulai advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

// Dipanggil saat Node2 menulis ke CHAR_RX; isinya digemakan balik lewat notify
class RxCallbacks : public NimBLECharacteristicCallbacks {
public:
  void onWrite(NimBLECharacteristic *pCharacteristic, NimBLEConnInfo &connInfo) override {
    NimBLEAttValue value = pCharacteristic->getValue();
    if (value.length() > 0) {
      Serial.print("RX dari Node2: ");
      Serial.println(value.c_str());

      pTxCharacteristic->setValue(value.data(), value.length());
      pTxCharacteristic->notify();
    }
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Node1 (BLE Server) starting...");

  NimBLEDevice::init("NODE1_H2");

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(CHAR_TX_UUID, NIMBLE_PROPERTY::NOTIFY);
  NimBLECharacteristic *pRxCharacteristic = pService->createCharacteristic(CHAR_RX_UUID, NIMBLE_PROPERTY::WRITE);
  pRxCharacteristic->setCallbacks(new RxCallbacks());
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("NODE1_H2");
  pAdvertising->start();

  Serial.println("Menunggu koneksi dari Node2...");
}

void loop() {
  if (deviceConnected && millis() - lastSend > 2000) {
    lastSend = millis();
    String msg = "Hello dari Node1 (" + String(millis()) + ")";
    pTxCharacteristic->setValue((const uint8_t *)msg.c_str(), msg.length());
    pTxCharacteristic->notify();
    Serial.println("TX ke Node2: " + msg);
  }
}
