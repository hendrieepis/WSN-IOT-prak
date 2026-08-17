// Minggu 16 — Proyek Komparatif: sensor H2 kirim telemetri via BLE (Notify)
#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID    "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TELEM_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b2"

static bool deviceConnected = false;
static NimBLECharacteristic *pTelemetry = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    deviceConnected = true;
    Serial.println("Gateway terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    deviceConnected = false;
    Serial.println("Gateway terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

static float readSensor() {
  static float suhu = 25.0;
  suhu += (random(0, 20) - 10) / 10.0;
  if (suhu > 40.0) suhu = 25.0;
  if (suhu < 20.0) suhu = 25.0;
  return suhu;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Sensor (BLE telemetry) starting...");

  NimBLEDevice::init("CMP_SENSOR");

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
  pAdvertising->setName("CMP_SENSOR");
  pAdvertising->start();

  Serial.println("Menunggu gateway...");
}

void loop() {
  static unsigned long last = 0;
  if (deviceConnected && millis() - last > 2000) {
    last = millis();
    char payload[32];
    snprintf(payload, sizeof(payload), "suhu:%.1f", readSensor());
    pTelemetry->setValue((const uint8_t *)payload, strlen(payload));
    pTelemetry->notify();
    Serial.printf("Notify: %s\n", payload);
  }
}
