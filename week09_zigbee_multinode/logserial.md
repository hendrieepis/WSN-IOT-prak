# Log Serial — Week 09 (Zigbee Multi-Node)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2.
Flash di-`erase` penuh sebelum upload agar state network Zigbee bersih.

## Board & Port

| Node | Peran | Endpoint | Port serial (UART) |
|---|---|---|---|
| Coordinator | Zigbee Coordinator (ZCZR) — switch | 5 | `/dev/ttyACM0` |
| Light1 | Zigbee End Device — light | 10 | `/dev/ttyACM2` |
| Light2 | Zigbee End Device — light | 11 | `/dev/ttyACM4` |

## Coordinator — `/dev/ttyACM0`

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
Menunggu light ter-binding (join dalam 180 detik)...
Daftar device ter-bind:
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0x3591
Total 2 device.
-> Light 0xFFFF ON
-> Light 0x3591 ON
-> Light 0xFFFF OFF
-> Light 0x3591 OFF
-> Light 0xFFFF ON
-> Light 0x3591 ON
-> Light 0xFFFF OFF
-> Light 0x3591 OFF
-> Light 0xFFFF ON
-> Light 0x3591 ON
-> Light 0xFFFF OFF
-> Light 0x3591 OFF
-> Light 0xFFFF ON
-> Light 0x3591 ON
-> Light 0xFFFF OFF
-> Light 0x3591 OFF
-> Light 0xFFFF ON
-> Light 0x3591 ON
-> Light 0xFFFF OFF
-> Light 0x3591 OFF
```

## Light1 — `/dev/ttyACM2`

```
ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xd (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Light1 menunggu join ke network...
Light1 tergabung ke network!
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
```

## Light2 — `/dev/ttyACM4`

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
Light2 menunggu join ke network...
Light2 tergabung ke network!
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
```

## Catatan

- Coordinator membentuk network dan membuka join 180 detik; kedua light join lalu
  auto-bind (`allowMultipleBinding(true)`).
- `getBoundDevices()` melaporkan 2 device: endpoint 10 dan endpoint 11.
- Short addr endpoint 10 tercetak `0xFFFF` (nilai placeholder saat binding table
  belum mencatat short address; perintah tetap terkirim — Light1 tetap merespons).
- Coordinator men-toggle kedua lampu serentak tiap 5 detik; tiap light mencetak
  status `Light1/Light2 ON|OFF` sesuai perintah yang diterima.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
