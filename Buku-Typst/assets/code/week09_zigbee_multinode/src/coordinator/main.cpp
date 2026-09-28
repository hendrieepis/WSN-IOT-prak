// Minggu 9 — Zigbee Multi-Node: 1 Coordinator mengendalikan beberapa End Device
#include <Arduino.h>
#ifndef ZIGBEE_MODE_ZCZR
#error "Mode Zigbee ZCZR belum dipilih (periksa build_flags)"
#endif
#include "Zigbee.h"

ZigbeeSwitch zbSwitch = ZigbeeSwitch(5);

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
  zbSwitch.allowMultipleBinding(true);   // izinkan banyak light ter-bind

  Zigbee.addEndpoint(&zbSwitch);
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

  Serial.println("Menunggu light ter-binding (join dalam 180 detik)...");
  // Tunggu minimal 1 light ter-bind
  while (!zbSwitch.bound()) {
    delay(500);
  }
  delay(5000);  // beri waktu light lain join & bind

  Serial.println("Daftar device ter-bind:");
  std::list<zb_device_params_t *> bound = zbSwitch.getBoundDevices();
  for (auto d : bound) {
    Serial.printf(" - endpoint %d, short addr 0x%04X\n", d->endpoint, d->short_addr);
  }
  Serial.printf("Total %d device.\n", (int)bound.size());
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
        Serial.printf("-> Light 0x%04X ON\n", d->short_addr);
      } else {
        zbSwitch.lightOff(d->endpoint, d->short_addr);
        Serial.printf("-> Light 0x%04X OFF\n", d->short_addr);
      }
    }
  }
}
