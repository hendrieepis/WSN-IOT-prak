# Log Serial — Week 15 (End-to-End IoT: H2 → Thread → C6 → MQTT)

Hasil aktual dari board nyata ESP32-C6. Baud 115200.
Sensor H2 **disimulasikan** di dalam firmware gateway (tidak ada board H2 fisik).

## Board & Port

| Node | Board | Peran | Port serial (UART) |
|---|---|---|---|
| Gateway | ESP32-C6 DevKitC-1 | Thread Leader + Wi-Fi STA + MQTT publisher | `/dev/ttyACM6` |

Konfigurasi: Wi-Fi `SprH-3`, broker MQTT lokal `192.168.1.5:1884` (Mosquitto),
topic `praktikum/h2/telemetri`, client ID `esp32c6-gateway`, Thread `ESP_OT_E2E`.

## Gateway (C6) — `/dev/ttyACM6`

```
ESP-ROM:esp32c6-20220919
Build:Sep 19 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:2
load:0x40875730,len:0x1278
load:0x4086b910,len:0xc58
load:0x4086e610,len:0x31c0
entry 0x4086b910
Konek Wi-Fi SprH-3......
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -67 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Leader
Default netif dikembalikan ke Wi-Fi STA (err=0)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
MQTT belum terhubung. Lanjut; dicoba ulang di loop().
Gateway siap (H2 -> Thread -> C6 -> MQTT).
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:25.8
Publish MQTT GAGAL (mqtt=-2): suhu:25.8
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:26.6
Publish MQTT GAGAL (mqtt=-2): suhu:26.6
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:27.0
Publish MQTT GAGAL (mqtt=-2): suhu:27.0
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:27.3
Publish MQTT GAGAL (mqtt=-2): suhu:27.3
MQTT gagal (rc=-4), coba lagi 4 detik
SIM sensor (Thread): suhu:26.3
Publish MQTT GAGAL (mqtt=-4): suhu:26.3
```

## Verifikasi dari sisi broker (PC)

`mosquitto_sub -h 192.168.1.5 -p 1884 -t "praktikum/h2/telemetri" -v`:

```
(0 pesan diterima selama pengamatan)
```

## Catatan

- Gateway menjalankan **tiga stack** di satu chip: Thread, Wi-Fi, dan MQTT.
- Thread dan Wi-Fi masing-masing sehat: attach sebagai **Leader** dan Wi-Fi
  memperoleh IP `192.168.1.39` (RSSI −67 dBm).
- **Hop Wi-Fi/MQTT gagal total** di jaringan `SprH-3`: `mqtt.connect()` terus
  gagal `rc=-2` (koneksi TCP keluar tidak terbentuk) meskipun prioritas radio
  sudah diberikan ke Wi-Fi (`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`).
  Ini persis kasus "AP-1" pada log referensi README (0 % end-to-end), bukan
  kegagalan konfigurasi.
- Sensor **disimulasikan** (`SIM sensor (Thread): suhu:XX.X`); karena MQTT tidak
  pernah terhubung, tiap publish dicetak `Publish MQTT GAGAL (mqtt=-2)`.
- Pembanding penting (modul 16): pipeline **BLE** + Wi-Fi + MQTT pada gateway
  satu-chip yang sama nyaris tanpa ongkos koeksistensi, sedangkan **Thread** +
  Wi-Fi sangat mahal — lihat log week16.
- Baris `ESP-ROM:esp32c6-…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
