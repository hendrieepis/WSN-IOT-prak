#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_NOTIFY_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"

static bool deviceConnected = false;
static NimBLECharacteristic *pNotify = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    deviceConnected = true;
    Serial.println("Central terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    deviceConnected = false;
    Serial.println("Central terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Node B (peripheral) starting...");

  NimBLEDevice::init("MULTI_NODE_B");

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  pNotify = pService->createCharacteristic(CHAR_NOTIFY_UUID, NIMBLE_PROPERTY::NOTIFY);
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("MULTI_NODE_B");
  pAdvertising->start();

  Serial.println("Menunggu central...");
}

void loop() {
  static unsigned long last = 0;
  static uint32_t count = 0;
  if (deviceConnected && millis() - last > 3000) {
    last = millis();
    String msg = "B:" + String(++count);
    pNotify->setValue((const uint8_t *)msg.c_str(), msg.length());
    pNotify->notify();
    Serial.println("Notify: " + msg);
  }
}
