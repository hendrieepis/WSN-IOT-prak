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
}

void loop() {
  delay(100);
}
