// Minggu 10 — Zigbee Mesh: End Device (child, dapat join lewat router)
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ED
#error "Mode Zigbee ED belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

uint8_t led = RGB_BUILTIN;

ZigbeeLight zbLight = ZigbeeLight(11);

void setLED(bool state) {
  digitalWrite(led, state);
  Serial.printf("EndLight %s\n", state ? "ON" : "OFF");
}

void setup() {
  Serial.begin(115200);
  pinMode(led, OUTPUT);
  digitalWrite(led, LOW);

  zbLight.setManufacturerAndModel("Espressif", "ZBLightED");
  zbLight.onLightChange(setLED);

  Zigbee.addEndpoint(&zbLight);

  if (!Zigbee.begin()) {  // default = ZIGBEE_END_DEVICE
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("End device menunggu join (bisa lewat router)...");
  while (!Zigbee.connected()) {
    delay(100);
  }
  Serial.println("End device tergabung (role=END_DEVICE).");
}

void loop() {
  delay(100);
}
