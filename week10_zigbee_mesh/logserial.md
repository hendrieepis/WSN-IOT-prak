# Log Serial — Week 10 (Zigbee Mesh)

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
| Router | Zigbee Router (ZCZR) — light + relay | 10 | `0x33F4` | `74:4D:BD:FF:FE:61:E8:C1` | `COM11` |
| End Device | Zigbee End Device (ED) — light | 11 | `0xBB28` | `74:4D:BD:FF:FE:61:F3:97` | `COM13` |

Network: channel **21**, PAN ID **`0x4D92`**, Extended PAN ID
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
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu router & end device ter-binding...
Total device ter-bind: 2
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xBB28
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
```

## Router — COM11

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
Info network:
  Peran          : Router (ZR)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x33F4 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
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

## End Device — COM13

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
Info network:
  Peran          : End Device (ED)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0xBB28 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 11 (light)
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

## Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)

```
[   0.441] Coordinator | Network Zigbee terbentuk:
[   0.441] Coordinator |   Peran          : Coordinator (ZC)
[   0.441] Coordinator |   Channel        : 21
[   0.441] Coordinator |   PAN ID         : 0x4D92
[   0.441] Coordinator |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.441] Coordinator |   Short address  : 0x0000
[   0.441] Coordinator |   IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
[   0.441] Coordinator |   Endpoint       : 5 (switch)
[   0.454] Router      | Router menunggu join ke network...
[   0.454] Router      | Router tergabung (role=ROUTER).
[   0.454] Router      | Info network:
[   0.454] Router      |   Peran          : Router (ZR)
[   0.454] Router      |   Channel        : 21
[   0.454] Router      |   PAN ID         : 0x4D92
[   0.454] Router      |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.595] EndDevice   | End device menunggu join (bisa lewat router)...
[   0.643] Coordinator | Menunggu router & end device ter-binding...
[   0.658] Router      |   Short address  : 0x33F4 (diberikan coordinator)
[   0.658] Router      |   IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
[   0.658] Router      |   Endpoint       : 10 (light)
[   3.311] EndDevice   | End device tergabung (role=END_DEVICE).
[   3.311] EndDevice   | Info network:
[   3.311] EndDevice   |   Peran          : End Device (ED)
[   3.311] EndDevice   |   Channel        : 21
[   3.311] EndDevice   |   PAN ID         : 0x4D92
[   3.311] EndDevice   |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   3.311] EndDevice   |   Short address  : 0xBB28 (diberikan coordinator)
[   3.516] EndDevice   |   IEEE address   : 74:4D:BD:FF:FE:61:F3:97
[   3.517] EndDevice   |   Endpoint       : 11 (light)
[   8.653] Coordinator | Total device ter-bind: 2
[   8.653] Coordinator |  - endpoint 10, short addr 0xFFFF
[   8.653] Coordinator |  - endpoint 11, short addr 0xBB28
[   8.653] Coordinator | -> 0xFFFF ON
[   8.653] Coordinator | -> 0xBB28 ON
[   8.653] EndDevice   | EndLight ON
[   8.677] Router      | RouterLight ON
[  13.630] Coordinator | -> 0xFFFF OFF
[  13.630] Coordinator | -> 0xBB28 OFF
[  13.662] EndDevice   | EndLight OFF
[  13.693] Router      | RouterLight OFF
[  18.648] Coordinator | -> 0xFFFF ON
[  18.649] Coordinator | -> 0xBB28 ON
[  18.665] EndDevice   | EndLight ON
[  18.698] Router      | RouterLight ON
[  23.644] Coordinator | -> 0xFFFF OFF
[  23.644] Coordinator | -> 0xBB28 OFF
[  23.669] EndDevice   | EndLight OFF
[  23.685] Router      | RouterLight OFF
[  28.664] Coordinator | -> 0xFFFF ON
[  28.664] Coordinator | -> 0xBB28 ON
[  28.664] EndDevice   | EndLight ON
[  28.696] Router      | RouterLight ON
[  33.656] Coordinator | -> 0xFFFF OFF
[  33.656] Coordinator | -> 0xBB28 OFF
[  33.672] EndDevice   | EndLight OFF
[  33.688] Router      | RouterLight OFF
[  38.669] Coordinator | -> 0xFFFF ON
[  38.669] Coordinator | -> 0xBB28 ON
[  38.669] EndDevice   | EndLight ON
[  38.709] Router      | RouterLight ON
[  43.661] Coordinator | -> 0xFFFF OFF
[  43.662] Coordinator | -> 0xBB28 OFF
[  43.676] EndDevice   | EndLight OFF
[  43.699] Router      | RouterLight OFF
[  48.670] Coordinator | -> 0xFFFF ON
[  48.671] Coordinator | -> 0xBB28 ON
[  48.697] EndDevice   | EndLight ON
[  48.705] Router      | RouterLight ON
[  53.666] Coordinator | -> 0xFFFF OFF
[  53.666] Coordinator | -> 0xBB28 OFF
[  53.682] EndDevice   | EndLight OFF
[  53.711] Router      | RouterLight OFF
[  58.675] Coordinator | -> 0xFFFF ON
[  58.675] Coordinator | -> 0xBB28 ON
[  58.692] EndDevice   | EndLight ON
[  58.708] Router      | RouterLight ON
```

## Ringkasan `monitor_serial.py`

```
Durasi: 60.4 s
  Coordinator COM5             43 baris, boot 1x, daftar bound  8.30 s sejak boot
              channel 21, PAN 0x4D92, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x0000
  Router      COM11            30 baris, boot 1x, tergabung  0.10 s sejak boot, role=ROUTER
              channel 21, PAN 0x4D92, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x33F4
  EndDevice   COM13            30 baris, boot 1x, tergabung  2.95 s sejak boot, role=END_DEVICE
              channel 21, PAN 0x4D92, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0xBB28
  Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Device ter-bind di coordinator (2):
  endpoint 10  short addr 0xFFFF  -> Router
  endpoint 11  short addr 0xBB28  -> EndDevice

Lampu     perintah  aksi   loss   perintah->aksi ms rata2 (min..max)  status akhir ZC/lampu
--------------------------------------------------------------------------------------------
Router          11    11    0.0%       39 (24..63)                     ON/ON
EndDevice       11    11    0.0%       15 (-0..31)                     ON/ON

Putaran perintah per menit: 12.0 (harapan 12: satu putaran tiap 5 s)
Aksi dipasangkan bila status sama dan jatuh -0.5..+2.0 s dari perintah; selisih memakai timestamp PC (kasar).
```

## Catatan

- **Info network cocok di ketiga board**: channel 21, PAN ID `0x4D92`, dan
  Extended PAN ID sama. Router melaporkan peran `Router (ZR)` dan, seperti end
  device, mendapat short address dari coordinator (`0x33F4`).
- Padanan XBee: `Short address` = MY, `IEEE address` = SH+SL, `Channel` = CH,
  `PAN ID` = OI, `Extended PAN ID` = OP — lihat tabel padanan XBee di Modul 08.
- **Extended PAN ID = IEEE address coordinator** (`74:4D:BD:FF:FE:61:E6:2C`),
  karena Extended PAN ID tidak diatur di kode.
- Daftar bound coordinator mencetak `0xFFFF` untuk router (short address
  aslinya `0x33F4`) dan `0xBB28` untuk end device — sama dengan short address
  yang dicetak end device sendiri.
- Kedua lampu menerima **11/11 perintah (0 % loss)**; selisih perintah → aksi
  sekitar 24–63 ms di router dan 0–31 ms di end device.
- Board berdekatan di meja, jadi end device kemungkinan besar terhubung
  langsung ke coordinator; log ini **belum** membuktikan penerusan lewat router
  (itu tugas formasi garis).
- Firmware coordinator tidak menunggu `Zigbee.connected()`: pada reboot dengan
  `setRebootOpenNetwork()` aktif (seperti pada log ini), library Arduino core
  3.3.x tidak pernah men-set flag itu untuk coordinator.
- Selisih perintah → aksi memakai timestamp PC, jadi kasar (resolusi USB-serial).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
