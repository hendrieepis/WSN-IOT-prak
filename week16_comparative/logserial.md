# Log Serial — Week 16 (Komparatif: BLE → C6 → MQTT)

Hasil aktual dari board nyata ESP32-C6. Baud 115200.
Sensor H2 **disimulasikan** di dalam firmware gateway (tidak ada board H2 fisik).

## Board & Port

| Node | Board | Peran | Port serial (UART) |
|---|---|---|---|
| Gateway | ESP32-C6 DevKitC-1 | BLE client + Wi-Fi STA + MQTT publisher | `/dev/ttyACM6` |

Konfigurasi: Wi-Fi `SprH-3`, broker MQTT lokal `192.168.1.5:1884` (Mosquitto),
topic `praktikum/h2/telemetri`, client ID `esp32c6-gateway`.

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
Gateway (BLE -> MQTT) starting...
Konek Wi-Fi SprH-3......
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -67 dBm
Scanning sensor BLE...
SIM sensor BLE: suhu:24.2
Publish MQTT GAGAL (mqtt=-1): suhu:24.2
MQTT terhubung
SIM sensor BLE: suhu:24.0
Publish MQTT [praktikum/h2/telemetri]: suhu:24.0
SIM sensor BLE: suhu:24.8
Publish MQTT [praktikum/h2/telemetri]: suhu:24.8
SIM sensor BLE: suhu:24.2
Publish MQTT [praktikum/h2/telemetri]: suhu:24.2
SIM sensor BLE: suhu:24.2
Publish MQTT [praktikum/h2/telemetri]: suhu:24.2
SIM sensor BLE: suhu:23.2
Publish MQTT [praktikum/h2/telemetri]: suhu:23.2
SIM sensor BLE: suhu:23.9
Publish MQTT [praktikum/h2/telemetri]: suhu:23.9
SIM sensor BLE: suhu:23.7
Publish MQTT [praktikum/h2/telemetri]: suhu:23.7
SIM sensor BLE: suhu:22.8
Publish MQTT [praktikum/h2/telemetri]: suhu:22.8
SIM sensor BLE: suhu:23.0
Publish MQTT [praktikum/h2/telemetri]: suhu:23.0
SIM sensor BLE: suhu:23.3
Publish MQTT [praktikum/h2/telemetri]: suhu:23.3
SIM sensor BLE: suhu:23.5
Publish MQTT [praktikum/h2/telemetri]: suhu:23.5
SIM sensor BLE: suhu:23.6
Publish MQTT [praktikum/h2/telemetri]: suhu:23.6
SIM sensor BLE: suhu:23.5
Publish MQTT [praktikum/h2/telemetri]: suhu:23.5
SIM sensor BLE: suhu:23.9
Publish MQTT [praktikum/h2/telemetri]: suhu:23.9
SIM sensor BLE: suhu:24.7
Publish MQTT [praktikum/h2/telemetri]: suhu:24.7
SIM sensor BLE: suhu:24.5
Publish MQTT [praktikum/h2/telemetri]: suhu:24.5
SIM sensor BLE: suhu:24.0
Publish MQTT [praktikum/h2/telemetri]: suhu:24.0
SIM sensor BLE: suhu:23.2
Publish MQTT [praktikum/h2/telemetri]: suhu:23.2
```

## Verifikasi dari sisi broker (PC)

`mosquitto_sub -h 192.168.1.5 -p 1884 -t "praktikum/h2/telemetri" -v`:

```
praktikum/h2/telemetri suhu:24.0
praktikum/h2/telemetri suhu:24.8
praktikum/h2/telemetri suhu:24.2
praktikum/h2/telemetri suhu:24.2
praktikum/h2/telemetri suhu:23.2
praktikum/h2/telemetri suhu:23.9
praktikum/h2/telemetri suhu:23.7
praktikum/h2/telemetri suhu:22.8
praktikum/h2/telemetri suhu:23.0
praktikum/h2/telemetri suhu:23.3
praktikum/h2/telemetri suhu:23.5
praktikum/h2/telemetri suhu:23.6
praktikum/h2/telemetri suhu:23.5
praktikum/h2/telemetri suhu:23.9
praktikum/h2/telemetri suhu:24.7
praktikum/h2/telemetri suhu:24.5
praktikum/h2/telemetri suhu:24.0
praktikum/h2/telemetri suhu:23.2
```

## Catatan

- Gateway menjalankan **BLE + Wi-Fi + MQTT** di satu chip. BLE scan dinyalakan
  (`Scanning sensor BLE...`) tapi sensor disimulasikan, sehingga data berasal dari
  `SIM sensor BLE: suhu:XX.X`.
- Setelah MQTT terhubung, **semua** publish berhasil (`Publish MQTT [...]`) dan
  tiap pesan terbaca di subscriber (18/18 pesan, 100 %).
- Hanya publish pertama gagal (`mqtt=-1`) karena MQTT belum sempat connect saat
  pesan simulasi pertama dikirim; `maintainNetwork()` langsung menyambungkan.
- **Perbandingan dengan Week 15** (Thread → C6 → MQTT, jaringan `SprH-3` yang
  sama): pipeline Thread+Wi-Fi gagal total (`rc=-2`, 0 %), sedangkan pipeline
  **BLE+Wi-Fi+MQTT 100 %** — mendukung kesimpulan README bahwa pada gateway
  satu-chip satu-antena, koeksistensi BLE+Wi-Fi nyaris tanpa ongkos, sementara
  Thread+Wi-Fi sangat mahal.
- Baris `ESP-ROM:esp32c6-…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
