// Minggu 7 — IEEE 802.15.4 P2P (raw frame), Node1 = pengirim (short addr 0x0001)
#include <Arduino.h>
#include "esp_ieee802154.h"

#define CHANNEL   15
#define PAN_ID    0xCAFE
#define MY_ADDR   0x0001
#define PEER_ADDR 0x0002
#define MHR_LEN   11   // FC(2)+Seq(1)+DestPAN(2)+DestAddr(2)+SrcPAN(2)+SrcAddr(2)
#define FCS_LEN   2    // ikut dihitung pada byte Len; saat RX diganti RSSI+LQI

// Buffer hasil terima (diisi ISR, dibaca loop)
static volatile bool hasRx = false;
static char rxPayload[64] = {0};

// Susun frame: [Len][FC(2)][Seq(1)][DestPAN(2)][DestAddr(2)][SrcPAN(2)][SrcAddr(2)][payload]
// FCS dihitung hardware otomatis, tetapi 2 byte-nya tetap ikut dihitung pada "Len".
static uint8_t buildFrame(uint8_t *frame, uint16_t dst, const char *payload) {
  uint8_t plen = strlen(payload);
  uint8_t mhr = 11;                       // 2+1+2+2+2+2
  uint8_t len = mhr + plen + FCS_LEN;
  frame[0] = len;                         // byte "Len" (PHR), termasuk FCS
  frame[1] = 0x01; frame[2] = 0x88;       // Frame Control (data, addr 16-bit)
  frame[3] = 0x00;                        // sequence number
  frame[4] = PAN_ID & 0xFF; frame[5] = (PAN_ID >> 8) & 0xFF;       // dest PAN
  frame[6] = dst & 0xFF;    frame[7] = (dst >> 8) & 0xFF;          // dest addr
  frame[8] = PAN_ID & 0xFF; frame[9] = (PAN_ID >> 8) & 0xFF;       // src PAN
  frame[10] = MY_ADDR & 0xFF; frame[11] = (MY_ADDR >> 8) & 0xFF;   // src addr
  memcpy(&frame[12], payload, plen);
  return 1 + len;  // total byte dalam buffer
}

// ISR: frame diterima. [Len]...[MHR]...[payload][RSSI][LQI]
void esp_ieee802154_receive_done(uint8_t *frame, esp_ieee802154_frame_info_t *frame_info) {
  uint8_t len = frame[0];
  uint8_t plen = len - MHR_LEN - FCS_LEN;
  if (plen > 0 && plen < sizeof(rxPayload)) {
    memcpy((void *)rxPayload, &frame[12], plen);
    rxPayload[plen] = '\0';
    hasRx = true;
  }
  esp_ieee802154_receive_handle_done(frame);
}

void setup() {
  Serial.begin(115200);
  Serial.println("Node1 (802.15.4 sender) starting...");

  uint8_t ext[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
  esp_ieee802154_enable();
  esp_ieee802154_set_channel(CHANNEL);
  esp_ieee802154_set_panid(PAN_ID);
  esp_ieee802154_set_short_address(MY_ADDR);
  esp_ieee802154_set_extended_address(ext);
  esp_ieee802154_set_rx_when_idle(true);
  esp_ieee802154_receive();  // masuk state RX; tanpa ini radio diam di idle

  Serial.printf("Channel %d, PAN 0x%04X, short addr 0x%04X\n", CHANNEL, PAN_ID, MY_ADDR);
}

void loop() {
  if (hasRx) {
    hasRx = false;
    Serial.printf("RX dari 0x%04X: %s\n", PEER_ADDR, rxPayload);
  }

  static unsigned long last = 0;
  static uint32_t count = 0;
  if (millis() - last > 2000) {
    last = millis();
    char msg[32];
    snprintf(msg, sizeof(msg), "PING %lu", (unsigned long)++count);
    // static: driver 802.15.4 mengirim secara asinkron, buffer harus tetap
    // hidup sampai transmisi selesai (buffer di stack akan tertimpa)
    static uint8_t frame[128];
    uint8_t total = buildFrame(frame, PEER_ADDR, msg);
    esp_ieee802154_transmit(frame, true);
    Serial.printf("TX ke 0x%04X: %s\n", PEER_ADDR, msg);
  }
}
