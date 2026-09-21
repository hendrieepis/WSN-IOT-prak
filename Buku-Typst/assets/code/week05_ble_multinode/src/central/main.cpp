#include <Arduino.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_NOTIFY_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"

// Alamat disalin (bukan pointer hasil scan) agar tetap valid setelah scan berhenti
static NimBLEAddress addrA;
static NimBLEAddress addrB;
static bool foundA = false;
static bool foundB = false;
static NimBLEClient *clientA = nullptr;
static NimBLEClient *clientB = nullptr;

class ClientCallbacks : public NimBLEClientCallbacks {
public:
  ClientCallbacks(const char *name) : _name(name) {}
  void onConnect(NimBLEClient *pClient) override { Serial.printf("%s terhubung\n", _name); }
  void onDisconnect(NimBLEClient *pClient, int reason) override { Serial.printf("%s terputus\n", _name); }
private:
  const char *_name;
};

// Kumpulkan hasil scan untuk A dan B (tanpa menghentikan scan)
class ScanCallbacks : public NimBLEScanCallbacks {
public:
  void onResult(const NimBLEAdvertisedDevice *d) override {
    if (d->getName() == "MULTI_NODE_A" && !foundA) {
      addrA = d->getAddress();
      foundA = true;
      Serial.println("Node A ditemukan");
    }
    if (d->getName() == "MULTI_NODE_B" && !foundB) {
      addrB = d->getAddress();
      foundB = true;
      Serial.println("Node B ditemukan");
    }
  }
};

static bool connectAndSubscribe(const NimBLEAddress &addr, const char *name,
                                NimBLEClient *&client) {
  client = NimBLEDevice::createClient();
  client->setClientCallbacks(new ClientCallbacks(name));

  if (!client->connect(addr)) {
    Serial.printf("Gagal terhubung ke %s\n", name);
    NimBLEDevice::deleteClient(client);
    client = nullptr;
    return false;
  }

  NimBLERemoteService *pService = client->getService(SERVICE_UUID);
  if (pService == nullptr) {
    Serial.printf("Service %s tidak ditemukan\n", name);
    client->disconnect();
    return false;
  }

  NimBLERemoteCharacteristic *pChar = pService->getCharacteristic(CHAR_NOTIFY_UUID);
  if (pChar == nullptr) {
    Serial.printf("Characteristic %s tidak ditemukan\n", name);
    client->disconnect();
    return false;
  }

  if (pChar->canNotify()) {
    // notify_callback NimBLE 2.x adalah std::function -> lambda boleh menangkap nama node
    pChar->subscribe(true, [name](NimBLERemoteCharacteristic *c, uint8_t *data,
                                  size_t length, bool isNotify) {
      Serial.printf("[%s] RX: %.*s\n", name, (int)length, (const char *)data);
    });
  }
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Central (multi-node) starting...");

  NimBLEDevice::init("MULTI_CENTRAL");

  NimBLEScan *pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->start(5000, false);  // scan 5 detik (ms di NimBLE 2.x), kumpulkan A dan B

  Serial.println("Scanning node A dan B...");
}

void loop() {
  // Setelah scan selesai, konek ke node yang ditemukan
  static bool connecting = true;
  if (connecting) {
    if (foundA && foundB) {
      NimBLEDevice::getScan()->stop();
      connectAndSubscribe(addrA, "NodeA", clientA);
      connectAndSubscribe(addrB, "NodeB", clientB);
      connecting = false;
      Serial.println("Koneksi ke kedua node selesai");
    }
  }
  delay(100);
}
