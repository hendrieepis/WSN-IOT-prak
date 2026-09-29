// Minggu 13 — Thread -> Wi-Fi Gateway: Node sensor (H2) kirim telemetry via Thread
#include <Arduino.h>
#include "OThread.h"
#include "OThreadUDP.h"
#include "esp_openthread.h"
#include "esp_openthread_lock.h"
#include <openthread/thread.h>

const char OT_NETWORK_NAME[] = "ESP_OT_GW";
const uint8_t  OT_CHANNEL = 15;
const uint16_t OT_PAN_ID  = 0xABCD;
const uint8_t  OT_EXTPANID[OT_EXT_PAN_ID_SIZE] = {0xDE, 0xAD, 0x00, 0xBE, 0xEF, 0x00, 0xCA, 0xFE};
const uint8_t  OT_NETKEY[OT_NETWORK_KEY_SIZE] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff};

const uint16_t PORT = 5050;
const uint8_t  GROUP_BYTES[16] = {0xff, 0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xab, 0xcd};
const IPAddress GROUP(IPv6, GROUP_BYTES);

// Prefix mesh-local dipaksa sama di H2 dan C6. DataSet::initNew() mengacak
// prefix ini per board; node dengan prefix berbeda tetap bisa attach, tetapi
// trafik multicast mesh (ff03::/16) tidak akan sampai ke gateway.
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] = {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};

// Harus dipanggil sebelum OThread.start() (stack masih berhenti).
static void applyMeshLocalPrefix() {
  otMeshLocalPrefix prefix;
  memcpy(prefix.m8, OT_ML_PREFIX, OT_MESH_LOCAL_PREFIX_SIZE);
  esp_openthread_lock_acquire(portMAX_DELAY);
  otThreadSetMeshLocalPrefix(esp_openthread_get_instance(), &prefix);
  esp_openthread_lock_release();
}

OThreadUDP OtUdp;

// Cetak 8 byte sebagai XX:XX:...:XX (Extended PAN ID, alamat 64-bit).
static void printHex8(const char *label, const uint8_t *b) {
  Serial.print(label);
  if (b == nullptr) {
    Serial.println("?");
    return;
  }
  for (int i = 0; i < 8; i++) {
    Serial.printf(i ? ":%02X" : "%02X", b[i]);
  }
  Serial.println();
}

// Cetak parameter jaringan Thread yang sedang dipakai node ini. Getter
// OThread sudah mengunci stack OpenThread sendiri.
static void printThreadInfo() {
  uint8_t eui64[8];
  bool hasEui = OThread.getEui64(eui64);

  Serial.println("Info network Thread:");
  Serial.printf("  Peran          : %s\n", OThread.otGetStringDeviceRole());
  Serial.printf("  Network name   : %s\n", OThread.getNetworkName().c_str());
  Serial.printf("  Channel        : %u\n", OThread.getChannel());
  Serial.printf("  PAN ID         : 0x%04X\n", OThread.getPanId());
  printHex8("  Extended PAN ID: ", OThread.getExtendedPanId());
  Serial.printf("  RLOC16         : 0x%04X\n", OThread.getRloc16());
  printHex8("  Extended addr  : ", OThread.getExtendedAddress());
  printHex8("  EUI-64         : ", hasEui ? eui64 : nullptr);
  Serial.printf("  Mesh-Local EID : %s\n", OThread.getMeshLocalEid().toString().c_str());
}

static float readSensor() {
  static float suhu = 25.0;
  suhu += (random(0, 20) - 10) / 10.0;
  if (suhu > 40.0) suhu = 25.0;
  if (suhu < 20.0) suhu = 25.0;
  return suhu;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Sensor H2 (Thread node) starting...");

  OThread.begin(false);
  // Dataset selalu ditulis ulang agar H2 dan C6 memakai parameter identik,
  // termasuk saat board masih menyimpan dataset dari modul sebelumnya.
  DataSet ds;
  ds.initNew();
  ds.setNetworkName(OT_NETWORK_NAME);
  ds.setChannel(OT_CHANNEL);
  ds.setPanId(OT_PAN_ID);
  ds.setExtendedPanId(OT_EXTPANID);
  ds.setNetworkKey(OT_NETKEY);
  OThread.commitDataSet(ds);
  applyMeshLocalPrefix();

  OThread.networkInterfaceUp();
  OThread.start();

  Serial.println("Menunggu join ke gateway (C6)...");
  while (OThread.otGetDeviceRole() < OT_ROLE_CHILD) {
    delay(250);
  }
  Serial.printf("Attached as: %s\n", OThread.otGetStringDeviceRole());
  printThreadInfo();

  OtUdp.begin(PORT);
}

void loop() {
  static unsigned long last = 0;
  if (millis() - last > 3000) {
    last = millis();
    char msg[32];
    snprintf(msg, sizeof(msg), "suhu:%.1f", readSensor());
    OtUdp.beginPacket(GROUP, PORT);
    OtUdp.write((const uint8_t *)msg, strlen(msg));
    OtUdp.endPacket();
    Serial.printf("TX via Thread: %s\n", msg);
  }
  delay(10);
}
