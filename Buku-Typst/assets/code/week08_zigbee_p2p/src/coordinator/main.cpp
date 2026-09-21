// Minggu 8 — Zigbee P2P: Coordinator (switch) mengendalikan End Device (lampu)
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ZCZR
#error "Mode Zigbee ZCZR belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

ZigbeeSwitch zbSwitch = ZigbeeSwitch(5);  // endpoint 5

void onLightStateChange(bool state) {
  Serial.printf("Lampu sekarang: %s\n", state ? "ON" : "OFF");
}

void setup() {
  Serial.begin(115200);

  zbSwitch.setManufacturerAndModel("Espressif", "ZigbeeSwitch");
  zbSwitch.allowMultipleBinding(false);   // P2P: hanya satu light
  zbSwitch.onLightStateChange(onLightStateChange);

  Zigbee.addEndpoint(&zbSwitch);

  // Buka network 180 detik agar end device bisa join
  Zigbee.setRebootOpenNetwork(180);

  if (!Zigbee.begin(ZIGBEE_COORDINATOR)) {
    Serial.println("Zigbee gagal start!");
    ESP.restart();
  }

  Serial.println("Menunggu end device ter-binding...");
  while (!zbSwitch.bound()) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nEnd device ter-binding!");
}

void loop() {
  static unsigned long last = 0;
  static bool on = false;
  if (millis() - last > 5000) {
    last = millis();
    on = !on;
    if (on) {
      zbSwitch.lightOn();
      Serial.println("Perintah: Lampu ON");
    } else {
      zbSwitch.lightOff();
      Serial.println("Perintah: Lampu OFF");
    }
  }
}
