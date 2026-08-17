# Log Serial — Week 14 (Wi-Fi / MQTT)

Hasil aktual dari board nyata ESP32-C6. Baud 115200.

## Board & Port

| Node | Board | Peran | Port serial (UART) |
|---|---|---|---|
| node | ESP32-C6 DevKitC-1 | Klien MQTT (publish + subscribe) | `/dev/ttyACM6` |

Konfigurasi: Wi-Fi `SprH-3`, broker MQTT lokal `192.168.1.5:1884` (Mosquitto),
client ID `esp32c6-praktikum`.

## Node (C6) — `/dev/ttyACM6`

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
MQTT Node (C6) starting...
Konek Wi-Fi SprH-3...
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -70 dBm
Konek MQTT 192.168.1.5:1884 ...
MQTT terhubung
Subscribe: praktikum/h2/perintah
TX MQTT [praktikum/h2/telemetri]: 25.3
TX MQTT [praktikum/h2/telemetri]: 25.5
TX MQTT [praktikum/h2/telemetri]: 25.1
TX MQTT [praktikum/h2/telemetri]: 26.0
TX MQTT [praktikum/h2/telemetri]: 25.4
TX MQTT [praktikum/h2/telemetri]: 25.8
```

## Verifikasi dari sisi broker (PC)

Subscriber di PC (`mosquitto_sub -h 192.168.1.5 -p 1884 -t "praktikum/#" -v`):

```
praktikum/h2/telemetri 25.9
praktikum/h2/telemetri 25.3
```

Perintah dari PC ke node (`mosquitto_pub -h 192.168.1.5 -p 1884 -t "praktikum/h2/perintah" -m "LED_ON"`),
diterima node:

```
RX MQTT [praktikum/h2/perintah]: LED_ON
```

## Catatan

- Node terhubung ke Wi-Fi `SprH-3` (2,4 GHz) dan mendapat IP `192.168.1.39`.
- Node connect ke broker lokal `192.168.1.5:1884` (Mosquitto, port 1884 karena
  instance sistem terikat loopback; dipakai instance terpisah yang listen 0.0.0.0).
- Publish `praktikum/h2/telemetri` tiap 5 detik; subscribe `praktikum/h2/perintah`.
- Komunikasi dua arah terbukti: publish terbaca `mosquitto_sub`, dan perintah
  `LED_ON` dari `mosquitto_pub` diterima node (`RX MQTT`).
- Baris `ESP-ROM:esp32c6-…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
