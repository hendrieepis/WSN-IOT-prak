// Minggu 14 — MQTT: C6 publish & subscribe ke broker (Wi-Fi)
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>

const char *WIFI_SSID = "NAMA_WIFI";
const char *WIFI_PASS = "PASSWORD_WIFI";

// Batas waktu menunggu Wi-Fi/MQTT saat boot; melewati batas ini setup() tetap
// dilanjutkan agar kegagalan sisi IP tidak menyembunyikan sisi radio lain.
const unsigned long WIFI_TIMEOUT_MS = 30000;
// Jeda antar percobaan sambung ulang. Harus lebih panjang dari durasi
// asosiasi pada sinyal lemah, kalau tidak percobaan berikutnya justru
// membatalkan yang sedang berjalan.
const unsigned long WIFI_RETRY_MS = 20000;
const unsigned long MQTT_TIMEOUT_MS = 15000;

// Broker publik (bisa diganti broker lokal, mis. Mosquitto)
// Broker MQTT. Banyak jaringan kampus memblokir port 1883 keluar sehingga
// test.mosquitto.org tidak terjangkau (gejala: rc=-2 dan "Host is unreachable").
// Bila itu terjadi, jalankan `python3 tools/mqtt_broker.py` di laptop lalu ganti
// baris di bawah dengan alamat IP laptop tersebut, mis. "192.168.110.74".
const char *MQTT_BROKER = "test.mosquitto.org";
const uint16_t MQTT_PORT = 1883;
const char *TOPIC_TELEM = "praktikum/h2/telemetri";
const char *TOPIC_CMD   = "praktikum/h2/perintah";

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

void reconnectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);   // modem sleep memperburuk asosiasi saat sinyal lemah
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.printf("Konek Wi-Fi %s", WIFI_SSID);
  // Batasi penantian: kalau SSID/password salah atau AP tidak ada, setup()
  // tetap lanjut supaya sisi radio lain (Thread/BLE) tetap bisa diamati.
  // Wi-Fi dicoba ulang di loop().
  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < WIFI_TIMEOUT_MS) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nWi-Fi OK, IP: %s | RSSI: %d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    Serial.printf("\nWi-Fi GAGAL setelah %lu s (status=%d). Lanjut tanpa Wi-Fi;\n"
                  "periksa WIFI_SSID/WIFI_PASS dan pastikan AP memancar di 2,4 GHz.\n",
                  WIFI_TIMEOUT_MS / 1000UL, (int)WiFi.status());
  }
}

void reconnectMQTT() {
  // Berbatas waktu: kalau broker tidak terjangkau, loop() tetap jalan sehingga
  // status Wi-Fi/MQTT tetap terlihat dan tidak tampak seperti board hang.
  unsigned long start = millis();
  while (!mqtt.connected() && millis() - start < MQTT_TIMEOUT_MS) {
    if (WiFi.status() != WL_CONNECTED) return;   // percuma tanpa Wi-Fi
    Serial.printf("Konek MQTT %s:%d ...\n", MQTT_BROKER, MQTT_PORT);
    if (mqtt.connect("esp32c6-praktikum")) {
      Serial.println("MQTT terhubung");
      mqtt.subscribe(TOPIC_CMD);
      Serial.printf("Subscribe: %s\n", TOPIC_CMD);
      return;
    }
    Serial.printf("Gagal (rc=%d), coba lagi 2 detik\n", mqtt.state());
    delay(2000);
  }
}

// Callback saat ada pesan masuk di topic yang di-subscribe
void onMessage(char *topic, byte *payload, unsigned int length) {
  char buf[64];
  unsigned int n = length < sizeof(buf) - 1 ? length : sizeof(buf) - 1;
  memcpy(buf, payload, n);
  buf[n] = '\0';
  Serial.printf("RX MQTT [%s]: %s\n", topic, buf);
}

static float readSensor() {
  static float suhu = 25.0;
  suhu += (random(0, 20) - 10) / 10.0;
  if (suhu > 40.0) suhu = 25.0;
  if (suhu < 20.0) suhu = 25.0;
  return suhu;
}

void setup() {
  Serial.begin(115200);
  Serial.println("MQTT Node (C6) starting...");

  reconnectWiFi();
  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setCallback(onMessage);
  reconnectMQTT();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) reconnectWiFi();
  if (!mqtt.connected()) reconnectMQTT();
  mqtt.loop();

  static unsigned long last = 0;
  if (millis() - last > 5000) {
    last = millis();
    char payload[32];
    snprintf(payload, sizeof(payload), "%.1f", readSensor());
    mqtt.publish(TOPIC_TELEM, payload);
    Serial.printf("TX MQTT [%s]: %s\n", TOPIC_TELEM, payload);
  }
}
