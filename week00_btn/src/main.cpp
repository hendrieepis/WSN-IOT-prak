#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

// LED RGB onboard Waveshare ESP32-H2-DEV-KIT-N4: WS2812 pada GPIO8,
// order byte RGB (bukan GRB standar WS2812) sesuai pengamatan empiris
#define LED_PIN 8
#define NUM_LEDS 1

// Tombol BOOT (Key2 pada skematik) terhubung ke GPIO9 dengan pull-up 10K di
// board: tidak ditekan = HIGH, ditekan = LOW (active low)
#define BTN_PIN 9

Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_RGB + NEO_KHZ800);

void setup() {
  strip.begin();
  strip.setBrightness(50);
  strip.show();

  // INPUT_PULLUP: pull-up internal menyusul pull-up eksternal agar pin tidak
  // mengambang bila resistor board tidak terpasang
  pinMode(BTN_PIN, INPUT_PULLUP);

  Serial.begin(115200);
  Serial.println("Tombol BOOT (GPIO9) -> LED RGB WS2812 (GPIO8) dimulai");
}

void loop() {
  bool pressed = (digitalRead(BTN_PIN) == LOW);

  strip.setPixelColor(0, pressed ? strip.Color(0, 255, 0) : strip.Color(0, 0, 0));
  strip.show();

  // Cetak hanya saat status berubah, supaya Serial Monitor tidak banjir
  static bool last = false;
  if (pressed != last) {
    last = pressed;
    Serial.println(pressed ? "Tombol DITEKAN  -> LED nyala" : "Tombol DILEPAS  -> LED mati");
  }

  delay(20);  // sekaligus meredam pantulan kontak (bounce) tombol
}
