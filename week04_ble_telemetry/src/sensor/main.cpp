#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TELEM_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26b2"

static bool deviceConnected = false;
static NimBLECharacteristic *pTelemetry = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    deviceConnected = true;
    Serial.println("Monitor terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    deviceConnected = false;
    Serial.println("Monitor terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

// Simulasi pembacaan sensor (mis. suhu)
static float readSensor() {
  static float temp = 25.0;
  temp += (random(0, 20) - 10) / 10.0;  // fluktuasi +-1.0 C
  if (temp > 40.0) temp = 25.0;
  if (temp < 20.0) temp = 25.0;
  return temp;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Sensor Node (BLE Telemetry) starting...");

  NimBLEDevice::init("TELEM_SENSOR");

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  pTelemetry = pService->createCharacteristic(CHAR_TELEM_UUID, NIMBLE_PROPERTY::NOTIFY);
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("TELEM_SENSOR");
  pAdvertising->start();

  Serial.println("Menunggu monitor...");
}

void loop() {
  static unsigned long lastSend = 0;
  if (deviceConnected && millis() - lastSend > 1000) {
    lastSend = millis();
    float suhu = readSensor();
    String payload = String(suhu, 1);  // contoh: "26.3"
    pTelemetry->setValue((const uint8_t *)payload.c_str(), payload.length());
    pTelemetry->notify();
    Serial.println("Notify: suhu = " + payload + " C");
  }
}
