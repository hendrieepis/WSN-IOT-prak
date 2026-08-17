#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_COUNTER_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b0"
#define CHAR_CMD_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26b1"

static uint32_t counter = 0;
static bool deviceConnected = false;
static NimBLECharacteristic *pCounter = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    deviceConnected = true;
    Serial.println("Client terhubung");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override {
    deviceConnected = false;
    Serial.println("Client terputus, advertise ulang");
    NimBLEDevice::startAdvertising();
  }
};

// Tulis nilai counter terkini ke characteristic (sebagai teks)
static void publishCounter() {
  char buf[12];
  snprintf(buf, sizeof(buf), "%lu", (unsigned long)counter);
  pCounter->setValue((const uint8_t *)buf, strlen(buf));
}

// Dipanggil saat client menulis ke CHAR_CMD (perintah ON/OFF)
class CmdCallbacks : public NimBLECharacteristicCallbacks {
public:
  void onWrite(NimBLECharacteristic *pCharacteristic, NimBLEConnInfo &connInfo) override {
    NimBLEAttValue value = pCharacteristic->getValue();
    Serial.print("Perintah dari client: ");
    Serial.println(value.c_str());
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("GATT Server starting...");

  NimBLEDevice::init("GATT_SERVER");

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *pService = pServer->createService(SERVICE_UUID);

  // Characteristic READ: client membaca nilai ini (counter)
  // Nilai disimpan sebagai teks agar client dapat mencetaknya langsung.
  pCounter = pService->createCharacteristic(
    CHAR_COUNTER_UUID, NIMBLE_PROPERTY::READ);
  publishCounter();

  // Characteristic WRITE: client menulis perintah ke sini
  NimBLECharacteristic *pCmd = pService->createCharacteristic(
    CHAR_CMD_UUID, NIMBLE_PROPERTY::WRITE);
  pCmd->setCallbacks(new CmdCallbacks());
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  // NimBLE 2.x tidak lagi menyisipkan nama device secara otomatis, dan scan
  // response default-nya mati. Nama ditaruh di scan response agar muat
  // berdampingan dengan Service UUID 128-bit dan terbaca oleh active scan.
  pAdvertising->enableScanResponse(true);
  pAdvertising->setName("GATT_SERVER");
  pAdvertising->start();

  Serial.println("Menunggu client...");
}

void loop() {
  // Update counter tiap 1 detik agar terbaca berubah oleh client
  static unsigned long last = 0;
  if (deviceConnected && millis() - last > 1000) {
    last = millis();
    counter++;
    publishCounter();  // tanpa ini, client selalu membaca nilai lama
  }
}
