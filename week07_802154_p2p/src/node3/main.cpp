// Minggu 7 — IEEE 802.15.4 P2P (raw frame), Node3 = penerima tambahan (short addr 0x0003)
// Dipakai untuk uji broadcast (EXP-04-e): menerima frame yang dikirim ke 0xFFFF
#include <Arduino.h>
#include "esp_ieee802154.h"

#define CHANNEL   15
#define PAN_ID    0xCAFE
#define MY_ADDR   0x0003
#define PEER_ADDR 0x0001
#define MHR_LEN   11   // FC(2)+Seq(1)+DestPAN(2)+DestAddr(2)+SrcPAN(2)+SrcAddr(2)
#define FCS_LEN   2    // ikut dihitung pada byte Len; saat RX diganti RSSI+LQI

static volatile bool hasRx = false;
static char rxPayload[64] = {0};

static uint8_t buildFrame(uint8_t *frame, uint16_t dst, const char *payload) {
  uint8_t plen = strlen(payload);
  uint8_t mhr = MHR_LEN;
  uint8_t len = mhr + plen + FCS_LEN;
  frame[0] = len;   // byte Len termasuk FCS
  frame[1] = 0x01; frame[2] = 0x88;
  frame[3] = 0x00;
  frame[4] = PAN_ID & 0xFF; frame[5] = (PAN_ID >> 8) & 0xFF;
  frame[6] = dst & 0xFF;    frame[7] = (dst >> 8) & 0xFF;
  frame[8] = PAN_ID & 0xFF; frame[9] = (PAN_ID >> 8) & 0xFF;
  frame[10] = MY_ADDR & 0xFF; frame[11] = (MY_ADDR >> 8) & 0xFF;
  memcpy(&frame[12], payload, plen);
  return 1 + len;
}

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
  Serial.println("Node3 (802.15.4 receiver) starting...");

  uint8_t ext[] = {0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28};
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

    // Balas ke pengirim (Node1)
    char msg[32];
    snprintf(msg, sizeof(msg), "PONG %s", rxPayload + 5);  // hilangkan "PING "
    static uint8_t frame[128];
    uint8_t total = buildFrame(frame, PEER_ADDR, msg);
    esp_ieee802154_transmit(frame, true);
    Serial.printf("TX balasan ke 0x%04X: %s\n", PEER_ADDR, msg);
  }
}
