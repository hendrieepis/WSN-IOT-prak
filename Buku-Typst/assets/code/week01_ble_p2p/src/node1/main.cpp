#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

static bool connected = false;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    connected = true;
    Serial.println("Node2 terhubung (link P2P aktif)");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    connected = false;
    Serial.println("Node2 terputus, mulai advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Node1 (BLE Peripheral) starting...");

  NimBLEDevice::init("NODE1_H2");

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Service tanpa characteristic: modul ini hanya menguji pembentukan tautan
  NimBLEService *pService = pServer->createService(SERVICE_UUID);

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("NODE1_H2");
  pAdvertising->start();

  Serial.println("Advertise sebagai NODE1_H2, menunggu Node2...");
}

void loop() {
  static unsigned long lastPrint = 0;
  if (connected && millis() - lastPrint > 5000) {
    lastPrint = millis();
    Serial.println("Status: H2 <-> H2 terhubung");
  }
}
