# Log Serial — Week 08 (Zigbee P2P)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.
Flash di-`erase` penuh sebelum upload agar state network Zigbee bersih.

## Board & Port

| Node | Peran | Endpoint | Port serial (UART) |
|---|---|---|---|
| Coordinator | Zigbee Coordinator (ZCZR) — switch | 5 | `/dev/ttyACM0` |
| End Device | Zigbee End Device (ED) — light | 10 | `/dev/ttyACM2` |

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
Menunggu end device ter-binding...
End device ter-binding!
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
```

## End Device — `/dev/ttyACM2`

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
Menunggu bergabung ke network koordinator...
Berhasil bergabung ke network!
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
```

## Catatan

- Coordinator membentuk network Zigbee (ZCZR) dan membuka network 180 detik
  (`setRebootOpenNetwork`) agar end device bisa join.
- End device melakukan join, lalu auto-bind (find-and-bind) ke switch.
- Setelah binding, coordinator men-toggle lampu tiap 5 detik (`Perintah: Lampu
  ON/OFF`); end device menerima perintah dan mencetak `Lampu ON/OFF` sesuai status.
- Binding selesai sangat cepat (baris titik `Menunggu…` tidak sempat tercetak
  banyak) karena end device sudah join + bind dalam satu window.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
