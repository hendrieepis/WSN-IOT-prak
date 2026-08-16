#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_RELAY_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26b4"

static bool relayConnected = false;
static NimBLECharacteristic *pRelay = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    relayConnected = true;
    Serial.println("Node B terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    relayConnected = false;
    Serial.println("Node B terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Node A (sumber pesan) starting...");

  NimBLEDevice::init("MESH_NODE_A");

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  pRelay = pService->createCharacteristic(CHAR_RELAY_UUID, NIMBLE_PROPERTY::NOTIFY);

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("MESH_NODE_A");
  pAdvertising->start();

  Serial.println("Menunggu relay (Node B)...");
}

void loop() {
  static unsigned long last = 0;
  static uint32_t count = 0;
  if (relayConnected && millis() - last > 4000) {
    last = millis();
    String msg = "A:" + String(++count);
    pRelay->setValue((const uint8_t *)msg.c_str(), msg.length());
    pRelay->notify();
    Serial.println("Kirim ke B: " + msg);
  }
}
