// Minggu 10 — Zigbee Mesh: Router (lampu yang juga meneruskan trafik)
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ZCZR
#error "Mode Zigbee ZCZR belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

uint8_t led = RGB_BUILTIN;

ZigbeeLight zbLight = ZigbeeLight(10);

void setLED(bool state) {
  digitalWrite(led, state);
  Serial.printf("RouterLight %s\n", state ? "ON" : "OFF");
}

// Cetak parameter jaringan yang didapat saat join. Library Arduino hanya
// menulisnya ke log debug, jadi dibaca langsung dari stack ESP-Zigbee
// (wajib di dalam lock karena stack berjalan di task lain).
void printNetworkInfo() {
  esp_zb_ieee_addr_t extPanId, ieee;
  esp_zb_lock_acquire(portMAX_DELAY);
  uint8_t channel = esp_zb_get_current_channel();
  uint16_t panId = esp_zb_get_pan_id();
  uint16_t shortAddr = esp_zb_get_short_address();
  esp_zb_get_extended_pan_id(extPanId);
  esp_zb_get_long_address(ieee);
  esp_zb_lock_release();

  Serial.println("Info network:");
  Serial.println("  Peran          : Router (ZR)");
  Serial.printf("  Channel        : %u\n", channel);
  Serial.printf("  PAN ID         : 0x%04X\n", panId);
  Serial.printf("  Extended PAN ID: %s\n", ZigbeeCore::formatIEEEAddress(extPanId));
  Serial.printf("  Short address  : 0x%04X (diberikan coordinator)\n", shortAddr);
  Serial.printf("  IEEE address   : %s\n", ZigbeeCore::formatIEEEAddress(ieee));
  Serial.println("  Endpoint       : 10 (light)");
}

void setup() {
  Serial.begin(115200);
  pinMode(led, OUTPUT);
  digitalWrite(led, LOW);

  zbLight.setManufacturerAndModel("Espressif", "ZBLightRouter");
  zbLight.onLightChange(setLED);

  Zigbee.addEndpoint(&zbLight);

  // Peran ROUTER: bisa meneruskan trafik ke node lain (mesh)
  if (!Zigbee.begin(ZIGBEE_ROUTER)) {
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("Router menunggu join ke network...");
  while (!Zigbee.connected()) {
    delay(100);
  }
  Serial.println("Router tergabung (role=ROUTER).");
  printNetworkInfo();
}

void loop() {
  delay(100);
}
