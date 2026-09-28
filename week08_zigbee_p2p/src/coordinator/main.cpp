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

// Cetak parameter jaringan yang sedang dipakai. Library Arduino hanya
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

  Serial.println("Network Zigbee terbentuk:");
  Serial.println("  Peran          : Coordinator (ZC)");
  Serial.printf("  Channel        : %u\n", channel);
  Serial.printf("  PAN ID         : 0x%04X\n", panId);
  Serial.printf("  Extended PAN ID: %s\n", ZigbeeCore::formatIEEEAddress(extPanId));
  Serial.printf("  Short address  : 0x%04X\n", shortAddr);
  Serial.printf("  IEEE address   : %s\n", ZigbeeCore::formatIEEEAddress(ieee));
  Serial.println("  Endpoint       : 5 (switch)");
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

  // Bagi coordinator, begin() baru kembali setelah network terbentuk (boot
  // pertama) atau dipulihkan dari NVS (reboot). JANGAN menunggu
  // Zigbee.connected() di sini: pada reboot dengan setRebootOpenNetwork(),
  // library Arduino core 3.3.x tidak pernah men-set flag itu untuk coordinator.
  printNetworkInfo();

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
