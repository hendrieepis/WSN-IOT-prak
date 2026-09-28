// Minggu 9 — Zigbee Multi-Node: Light #1 (end device)
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ED
#error "Mode Zigbee ED belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

uint8_t led = RGB_BUILTIN;

ZigbeeLight zbLight = ZigbeeLight(10);

void setLED(bool state) {
  digitalWrite(led, state);
  Serial.printf("Light1 %s\n", state ? "ON" : "OFF");
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
  Serial.println("  Peran          : End Device (ED)");
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

  zbLight.setManufacturerAndModel("Espressif", "ZBLight1");
  zbLight.onLightChange(setLED);

  Zigbee.addEndpoint(&zbLight);

  if (!Zigbee.begin()) {
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("Light1 menunggu join ke network...");
  while (!Zigbee.connected()) {
    delay(100);
  }
  Serial.println("Light1 tergabung ke network!");
  printNetworkInfo();
}

void loop() {
  delay(100);
}
