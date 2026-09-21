// Minggu 10 — Zigbee Mesh: Coordinator mengendalikan lampu lewat Router & ED
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ZCZR
#error "Mode Zigbee ZCZR belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

ZigbeeSwitch zbSwitch = ZigbeeSwitch(5);

void setup() {
  Serial.begin(115200);

  zbSwitch.setManufacturerAndModel("Espressif", "ZigbeeSwitch");
  zbSwitch.allowMultipleBinding(true);

  Zigbee.addEndpoint(&zbSwitch);
  Zigbee.setRebootOpenNetwork(180);

  if (!Zigbee.begin(ZIGBEE_COORDINATOR)) {
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("Menunggu router & end device ter-binding...");
  while (!zbSwitch.bound()) {
    delay(500);
  }
  delay(8000);  // beri waktu router dan ED join & bind

  std::list<zb_device_params_t *> bound = zbSwitch.getBoundDevices();
  Serial.printf("Total device ter-bind: %d\n", (int)bound.size());
  for (auto d : bound) {
    Serial.printf(" - endpoint %d, short addr 0x%04X\n", d->endpoint, d->short_addr);
  }
}

void loop() {
  static unsigned long last = 0;
  static bool on = false;
  if (millis() - last > 5000) {
    last = millis();
    on = !on;
    std::list<zb_device_params_t *> bound = zbSwitch.getBoundDevices();
    for (auto d : bound) {
      if (on) {
        zbSwitch.lightOn(d->endpoint, d->short_addr);
        Serial.printf("-> 0x%04X ON\n", d->short_addr);
      } else {
        zbSwitch.lightOff(d->endpoint, d->short_addr);
        Serial.printf("-> 0x%04X OFF\n", d->short_addr);
      }
    }
  }
}
