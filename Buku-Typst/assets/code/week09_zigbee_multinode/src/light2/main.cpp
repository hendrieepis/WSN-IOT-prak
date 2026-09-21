// Minggu 9 — Zigbee Multi-Node: Light #2 (end device)
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ED
#error "Mode Zigbee ED belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

uint8_t led = RGB_BUILTIN;

ZigbeeLight zbLight = ZigbeeLight(11);

void setLED(bool state) {
  digitalWrite(led, state);
  Serial.printf("Light2 %s\n", state ? "ON" : "OFF");
}

void setup() {
  Serial.begin(115200);
  pinMode(led, OUTPUT);
  digitalWrite(led, LOW);

  zbLight.setManufacturerAndModel("Espressif", "ZBLight2");
  zbLight.onLightChange(setLED);

  Zigbee.addEndpoint(&zbLight);

  if (!Zigbee.begin()) {
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("Light2 menunggu join ke network...");
  while (!Zigbee.connected()) {
    delay(100);
  }
  Serial.println("Light2 tergabung ke network!");
}

void loop() {
  delay(100);
}
