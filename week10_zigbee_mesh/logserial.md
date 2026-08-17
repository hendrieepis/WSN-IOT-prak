# Log Serial — Week 10 (Zigbee Mesh)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2.
Flash di-`erase` penuh sebelum upload agar state network Zigbee bersih.

## Board & Port

| Node | Peran | Endpoint | Port serial (UART) |
|---|---|---|---|
| Coordinator | Zigbee Coordinator (ZCZR) — switch | 5 | `/dev/ttyACM0` |
| Router | Zigbee Router (ZCZR) — light + relay | 10 | `/dev/ttyACM2` |
| End Device | Zigbee End Device (ED) — light | 11 | `/dev/ttyACM4` |

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
Menunggu router & end device ter-binding...
Total device ter-bind: 2
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xE04F
-> 0xFFFF ON
-> 0xE04F ON
-> 0xFFFF OFF
-> 0xE04F OFF
-> 0xFFFF ON
-> 0xE04F ON
-> 0xFFFF OFF
-> 0xE04F OFF
-> 0xFFFF ON
-> 0xE04F ON
-> 0xFFFF OFF
-> 0xE04F OFF
-> 0xFFFF ON
-> 0xE04F ON
-> 0xFFFF OFF
-> 0xE04F OFF
-> 0xFFFF ON
-> 0xE04F ON
-> 0xFFFF OFF
-> 0xE04F OFF
-> 0xFFFF ON
-> 0xE04F ON
```

## Router — `/dev/ttyACM2`

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
Router menunggu join ke network...
Router tergabung (role=ROUTER).
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
```

## End Device — `/dev/ttyACM4`

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
End device menunggu join (bisa lewat router)...
End device tergabung (role=END_DEVICE).
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
```

## Catatan

- Tiga peran berbeda dalam satu network: Coordinator (pembentuk network),
  Router (menyimpan + meneruskan trafik), End Device (child yang bisa join lewat router).
- `getBoundDevices()` melaporkan 2 device: endpoint 10 (Router, tercetak `0xFFFF`
  karena binding table belum mencatat short address) dan endpoint 11 (End Device, `0xE04F`).
- Coordinator men-toggle kedua lampu serentak tiap 5 detik; Router mencetak
  `RouterLight ON/OFF`, End Device mencetak `EndLight ON/OFF`.
- Kedua perangkat join ke network yang sama dan merespons perintah, menandakan
  jalur mesh (lewat router) berfungsi.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
