// Minggu 11 — Thread P2P/IP: Node1 (Leader) menjawab PING dengan PONG
#include <Arduino.h>
#include "OThread.h"
#include "OThreadUDP.h"
#include "esp_openthread.h"
#include "esp_openthread_lock.h"
#include <openthread/thread.h>

const char OT_NETWORK_NAME[] = "ESP_OT_P2P";
const uint8_t  OT_CHANNEL = 15;
const uint16_t OT_PAN_ID  = 0xABCD;
const uint8_t  OT_EXTPANID[OT_EXT_PAN_ID_SIZE] = {0xDE, 0xAD, 0x00, 0xBE, 0xEF, 0x00, 0xCA, 0xFE};
const uint8_t  OT_NETKEY[OT_NETWORK_KEY_SIZE] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff};

const uint16_t PORT = 5050;
const uint8_t  GROUP_BYTES[16] = {0xff, 0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xab, 0xcd};
const IPAddress GROUP(IPv6, GROUP_BYTES);

// Prefix mesh-local dipaksa sama untuk semua node. DataSet::initNew() mengacak
// prefix ini per board; node dengan prefix berbeda tetap bisa attach, tetapi
// trafik multicast mesh (ff03::/16) tidak akan sampai.
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

void setup() {
  Serial.begin(115200);
  Serial.println("Node1 (Thread Leader) starting...");

  OThread.begin(false);  // init tanpa autostart agar dataset bisa di-set dulu

  // Dataset selalu ditulis ulang agar seluruh node memakai parameter identik,
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

  Serial.println("Menunggu attach...");
  while (OThread.otGetDeviceRole() < OT_ROLE_CHILD) {
    delay(250);
  }
  Serial.printf("Attached as: %s\n", OThread.otGetStringDeviceRole());
  Serial.printf("Mesh-Local EID: %s\n", OThread.getMeshLocalEid().toString().c_str());

  OtUdp.beginMulticast(GROUP, PORT);
  Serial.printf("Mendengarkan [%s]:%d (dan unicast)\n", GROUP.toString().c_str(), PORT);
}

void loop() {
  while (int n = OtUdp.parsePacket()) {
    char buf[32];
    int got = OtUdp.read((uint8_t *)buf, (n < (int)sizeof(buf) - 1) ? n : (int)sizeof(buf) - 1);
    buf[got] = '\0';
    IPAddress src = OtUdp.remoteIP();
    uint16_t sp = OtUdp.remotePort();
    Serial.printf("RX [%s]:%u -> '%s'\n", src.toString().c_str(), sp, buf);

    const char *resp = "PONG";
    OtUdp.beginPacket(src, sp);
    OtUdp.write((const uint8_t *)resp, strlen(resp));
    OtUdp.endPacket();
    Serial.println("TX PONG (unicast ke pengirim)");
  }
  delay(10);
}
