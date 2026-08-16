// Minggu 8 — Zigbee P2P: End Device (lampu) dikendalikan Coordinator
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ED
#error "Mode Zigbee ED belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

uint8_t led = RGB_BUILTIN;

ZigbeeLight zbLight = ZigbeeLight(10);  // endpoint 10

void setLED(bool state) {
  digitalWrite(led, state);
  Serial.printf("Lampu %s\n", state ? "ON" : "OFF");
}

void setup() {
  Serial.begin(115200);

  pinMode(led, OUTPUT);
  digitalWrite(led, LOW);

  zbLight.setManufacturerAndModel("Espressif", "ZBLightBulb");
  zbLight.onLightChange(setLED);

  Zigbee.addEndpoint(&zbLight);

  if (!Zigbee.begin()) {  // default = ZIGBEE_END_DEVICE
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("Menunggu bergabung ke network koordinator...");
  while (!Zigbee.connected()) {
    delay(100);
  }
  Serial.println("Berhasil bergabung ke network!");
}

void loop() {
  delay(100);
}
