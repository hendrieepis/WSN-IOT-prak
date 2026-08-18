#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

// LED RGB onboard Waveshare ESP32-H2-DEV-KIT-N4: WS2812 pada GPIO8,
// order byte RGB (bukan GRB standar WS2812) sesuai pengamatan empiris
#define LED_PIN 8
#define NUM_LEDS 1

Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_RGB + NEO_KHZ800);

void setup() {
  strip.begin();
  strip.setBrightness(50);
  strip.show();
  Serial.begin(115200);
  Serial.println("Blinky RGB WS2812 ESP32-H2-DEV-KIT-N4 dimulai");
}

void loop() {
  strip.setPixelColor(0, strip.Color(255, 0, 0));
  strip.show();
  delay(500);
  strip.setPixelColor(0, strip.Color(0, 0, 0));
  strip.show();
  delay(500);
}
