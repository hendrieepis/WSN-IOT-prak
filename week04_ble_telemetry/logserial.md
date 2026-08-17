# Log Serial — Week 04 (BLE Telemetry)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial (UART) |
|---|---|---|---|
| Sensor | BLE Server, notify telemetry | `TELEM_SENSOR` | `/dev/ttyACM0` |
| Monitor | BLE Client, subscribe | `TELEM_MONITOR` | `/dev/ttyACM2` |

## Sensor — `/dev/ttyACM0`

```
ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Sensor Node (BLE Telemetry) starting...
Menunggu monitor...
Monitor terhubung
Notify: suhu = 24.7 C
Notify: suhu = 25.1 C
Notify: suhu = 24.6 C
Notify: suhu = 25.0 C
Notify: suhu = 24.4 C
Notify: suhu = 25.0 C
Notify: suhu = 24.3 C
Notify: suhu = 25.1 C
Notify: suhu = 24.4 C
Notify: suhu = 23.6 C
Notify: suhu = 23.2 C
Notify: suhu = 23.6 C
Notify: suhu = 22.7 C
Notify: suhu = 22.5 C
Notify: suhu = 21.6 C
```

## Monitor — `/dev/ttyACM2`

```
ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Monitor Node starting...
Scanning sensor...
Sensor ditemukan
Terhubung ke sensor
Koneksi berhasil, menunggu telemetry...
Telemetry diterima: suhu = 24.7 C
Telemetry diterima: suhu = 25.1 C
Telemetry diterima: suhu = 24.6 C
Telemetry diterima: suhu = 25.0 C
Telemetry diterima: suhu = 24.4 C
Telemetry diterima: suhu = 25.0 C
Telemetry diterima: suhu = 24.3 C
Telemetry diterima: suhu = 25.1 C
Telemetry diterima: suhu = 24.4 C
Telemetry diterima: suhu = 23.6 C
Telemetry diterima: suhu = 23.2 C
Telemetry diterima: suhu = 23.6 C
Telemetry diterima: suhu = 22.7 C
Telemetry diterima: suhu = 22.5 C
Telemetry diterima: suhu = 21.6 C
```

## Catatan

- Sensor mengirim nilai suhu (simulasi, mulai ~25.0 °C dengan fluktuasi ±1.0)
  tiap 1 detik via notify ke characteristic telemetry.
- Monitor berlangganan notify dan mencetak tiap telemetry yang diterima.
- Nilai suhu berubah acak; tiap baris `Notify` di Sensor sama persis dengan baris
  `Telemetry diterima` di Monitor (data dikirim tanpa polling).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
