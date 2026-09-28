# Log Serial — Week 09 (Zigbee Multi-Node)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1,
firmware versi terbaru: setelah network terbentuk (coordinator) atau setelah
join, tiap board mencetak info network — channel, PAN ID, Extended PAN ID,
short address, IEEE address, dan endpoint. Log direkam 60 detik dengan
`monitor_serial.py` (ketiga port dalam satu komputer, satu sumbu waktu) lewat
port UART CH343 di Windows.

Ketiga board di-`erase` lalu di-flash; network terbentuk pada boot pertama
coordinator. Log di bawah direkam setelah monitor me-reset ketiga board saat
port dibuka, jadi coordinator **memulihkan** network dari NVS (bukan membentuk
baru) dan node lain bergabung kembali ke network yang sama.

## Board & Port

| Node | Peran | Endpoint | Short address (MY) | IEEE address (SH+SL) | Port serial (UART) |
|---|---|---|---|---|---|
| Coordinator | Zigbee Coordinator (ZCZR) — switch | 5 | `0x0000` | `74:4D:BD:FF:FE:61:E6:2C` | `COM5` |
| Light1 | Zigbee End Device (ED) — light | 10 | `0x82C3` | `74:4D:BD:FF:FE:61:E8:C1` | `COM11` |
| Light2 | Zigbee End Device (ED) — light | 11 | `0x127F` | `74:4D:BD:FF:FE:61:F3:97` | `COM13` |

Network: channel **26**, PAN ID **`0x1890`**, Extended PAN ID
**`74:4D:BD:FF:FE:61:E6:2C`** — sama di ketiga board.

## Coordinator — COM5

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
Network Zigbee terbentuk:
  Peran          : Coordinator (ZC)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu light ter-binding (join dalam 180 detik)...
Daftar device ter-bind:
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xFFFF
Total 2 device.
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
```

## Light1 — COM11

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
Light1 menunggu join ke network...
Light1 tergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x82C3 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
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
Light1 ON
```

## Light2 — COM13

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
Info network:
  Peran          : End Device (ED)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x127F (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 11 (light)
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
```

## Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)

```
[   0.450] Coordinator | Network Zigbee terbentuk:
[   0.450] Coordinator |   Peran          : Coordinator (ZC)
[   0.450] Coordinator |   Channel        : 26
[   0.450] Coordinator |   PAN ID         : 0x1890
[   0.450] Coordinator |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.450] Coordinator |   Short address  : 0x0000
[   0.450] Coordinator |   IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
[   0.450] Coordinator |   Endpoint       : 5 (switch)
[   0.658] Coordinator | Menunggu light ter-binding (join dalam 180 detik)...
[   0.686] Light1      | Light1 menunggu join ke network...
[   0.686] Light1      | Light1 tergabung ke network!
[   0.686] Light1      | Info network:
[   0.686] Light1      |   Peran          : End Device (ED)
[   0.686] Light1      |   Channel        : 26
[   0.686] Light1      |   PAN ID         : 0x1890
[   0.686] Light1      |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.895] Light1      |   Short address  : 0x82C3 (diberikan coordinator)
[   0.895] Light1      |   IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
[   0.896] Light1      |   Endpoint       : 10 (light)
[   5.668] Coordinator | Daftar device ter-bind:
[   5.669] Coordinator |  - endpoint 10, short addr 0xFFFF
[   5.669] Coordinator |  - endpoint 11, short addr 0xFFFF
[   5.669] Coordinator | Total 2 device.
[   5.669] Coordinator | -> Light 0xFFFF ON
[   5.669] Coordinator | -> Light 0xFFFF ON
[   5.700] Light1      | Light1 ON
[   6.443] Light2      | Light2 menunggu join ke network...
[   6.443] Light2      | Light2 tergabung ke network!
[   6.443] Light2      | Info network:
[   6.443] Light2      |   Peran          : End Device (ED)
[   6.443] Light2      |   Channel        : 26
[   6.443] Light2      |   PAN ID         : 0x1890
[   6.443] Light2      |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   6.650] Light2      |   Short address  : 0x127F (diberikan coordinator)
[   6.650] Light2      |   IEEE address   : 74:4D:BD:FF:FE:61:F3:97
[   6.650] Light2      |   Endpoint       : 11 (light)
[  10.656] Coordinator | -> Light 0xFFFF OFF
[  10.656] Coordinator | -> Light 0xFFFF OFF
[  10.700] Light1      | Light1 OFF
[  15.658] Coordinator | -> Light 0xFFFF ON
[  15.658] Coordinator | -> Light 0xFFFF ON
[  15.690] Light1      | Light1 ON
[  15.690] Light2      | Light2 ON
[  20.668] Coordinator | -> Light 0xFFFF OFF
[  20.668] Coordinator | -> Light 0xFFFF OFF
[  20.703] Light1      | Light1 OFF
[  20.703] Light2      | Light2 OFF
[  25.672] Coordinator | -> Light 0xFFFF ON
[  25.672] Coordinator | -> Light 0xFFFF ON
[  25.709] Light1      | Light1 ON
[  25.710] Light2      | Light2 ON
[  30.668] Coordinator | -> Light 0xFFFF OFF
[  30.669] Coordinator | -> Light 0xFFFF OFF
[  30.709] Light1      | Light1 OFF
[  30.709] Light2      | Light2 OFF
[  35.679] Coordinator | -> Light 0xFFFF ON
[  35.679] Coordinator | -> Light 0xFFFF ON
[  35.711] Light1      | Light1 ON
[  35.711] Light2      | Light2 ON
[  40.677] Coordinator | -> Light 0xFFFF OFF
[  40.677] Coordinator | -> Light 0xFFFF OFF
[  40.718] Light2      | Light2 OFF
[  40.718] Light1      | Light1 OFF
[  45.684] Coordinator | -> Light 0xFFFF ON
[  45.685] Coordinator | -> Light 0xFFFF ON
[  45.716] Light1      | Light1 ON
[  45.732] Light2      | Light2 ON
[  50.688] Coordinator | -> Light 0xFFFF OFF
[  50.689] Coordinator | -> Light 0xFFFF OFF
[  50.720] Light1      | Light1 OFF
[  50.720] Light2      | Light2 OFF
[  55.689] Coordinator | -> Light 0xFFFF ON
[  55.690] Coordinator | -> Light 0xFFFF ON
[  55.721] Light1      | Light1 ON
[  55.721] Light2      | Light2 ON
```

## Ringkasan `monitor_serial.py`

```
Durasi: 60.3 s
  Coordinator COM5             44 baris, boot 1x, daftar bound  5.30 s sejak boot
              channel 26, PAN 0x1890, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x0000
  Light1      COM11            30 baris, boot 1x, tergabung  0.31 s sejak boot
              channel 26, PAN 0x1890, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x82C3
  Light2      COM13            28 baris, boot 1x, tergabung  6.07 s sejak boot
              channel 26, PAN 0x1890, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x127F
  Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Device ter-bind di coordinator (2):
  endpoint 10  short addr 0xFFFF  -> Light1
  endpoint 11  short addr 0xFFFF  -> Light2

Light     perintah  aksi   loss   perintah->aksi ms rata2 (min..max)  status akhir ZC/light
--------------------------------------------------------------------------------------------
Light1          11    11    0.0%       35 (32..44)                     ON/ON
Light2          11     9   18.2%       37 (31..47)                     ON/ON
          tanpa aksi: ON @ 5.7 s, OFF @ 10.7 s

Putaran perintah per menit: 12.0 (harapan 12: satu putaran tiap 5 s)
Aksi dipasangkan bila status sama dan jatuh -0.5..+2.0 s dari perintah; selisih memakai timestamp PC (kasar).
```

## Catatan

- **Info network cocok di ketiga board**: channel 26, PAN ID `0x1890`, dan
  Extended PAN ID sama. Short address tiap light (`0x82C3`, `0x127F`)
  dibagikan coordinator saat join.
- Padanan XBee: `Short address` = MY, `IEEE address` = SH+SL, `Channel` = CH,
  `PAN ID` = OI, `Extended PAN ID` = OP — lihat tabel padanan XBee di Modul 08.
- **Extended PAN ID = IEEE address coordinator** (`74:4D:BD:FF:FE:61:E6:2C`),
  karena Extended PAN ID tidak diatur di kode.
- **Daftar bound mencetak `0xFFFF` untuk kedua light**, padahal short address
  aslinya `0x82C3` dan `0x127F` (lihat blok info network). Perintah tetap sampai
  ke keduanya, jadi `0xFFFF` di sini bukan tanda binding gagal.
- `allowMultipleBinding(true)`: kedua light ada di binding table dan menerima
  perintah yang sama tiap 5 s.
- **Light1** bergabung 0,31 s setelah boot → **11/11 perintah sampai** (0 % loss).
  **Light2** baru bergabung 6,07 s setelah boot, sehingga dua perintah pertama
  (5,7 s dan 10,7 s) tidak sampai; sejak 15,7 s semua perintah sampai
  (9/11). Selisih perintah → aksi sekitar 31–47 ms.
- Firmware coordinator tidak menunggu `Zigbee.connected()`: pada reboot dengan
  `setRebootOpenNetwork()` aktif (seperti pada log ini), library Arduino core
  3.3.x tidak pernah men-set flag itu untuk coordinator.
- Selisih perintah → aksi memakai timestamp PC, jadi kasar (resolusi USB-serial).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
