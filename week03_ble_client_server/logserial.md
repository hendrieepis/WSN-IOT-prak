# Log Serial — Week 03 (BLE Client-Server / GATT read-write)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial (UART) |
|---|---|---|---|
| Server | GATT Server (READ counter + WRITE cmd) | `GATT_SERVER` | `/dev/ttyACM0` |
| Client | GATT Client (read + write) | `GATT_CLIENT` | `/dev/ttyACM2` |

## Server — `/dev/ttyACM0`

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
GATT Server starting...
Menunggu client...
Client terhubung
Perintah dari client: ON
Perintah dari client: ON
Perintah dari client: ON
```

## Client — `/dev/ttyACM2`

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
GATT Client starting...
Scanning server...
Server ditemukan
Terhubung ke server
Koneksi berhasil
READ counter = 2
READ counter = 4
WRITE perintah: ON
READ counter = 6
READ counter = 8
WRITE perintah: ON
READ counter = 10
READ counter = 12
READ counter = 14
WRITE perintah: ON
```

## Catatan

- Server menaikkan `counter` tiap 1 detik selama ada client terhubung, lalu
  mempublikasikan nilainya ke characteristic READ.
- Client membaca `counter` tiap 2 detik (`READ counter = …`) dan menulis
  perintah `ON` tiap 5 detik (`WRITE perintah: ON`).
- Nilai yang terbaca naik 2 per baris karena interval read 2 detik dan counter
  naik 1 per detik.
- `Perintah dari client: ON` muncul di Server setiap kali client menulis ke CHAR_CMD.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
