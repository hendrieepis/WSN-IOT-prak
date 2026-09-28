# Log Serial — Week 08 (Zigbee P2P)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1,
firmware `src/coordinator` dan `src/enddevice` versi terbaru: setelah network
terbentuk (coordinator) atau setelah join (end device), tiap board mencetak
info network — channel, PAN ID, Extended PAN ID, short address, IEEE address,
dan endpoint. Log direkam 60 detik dengan `monitor_serial.py` (ketiga port
dalam satu komputer, satu sumbu waktu) lewat port UART CH343 di Windows.

Ketiga board di-`erase` lalu di-flash; network terbentuk pada boot pertama
coordinator. Log di bawah direkam setelah monitor me-reset ketiga board saat
port dibuka, jadi coordinator **memulihkan** network dari NVS (bukan membentuk
baru) dan end device bergabung kembali ke network yang sama.

## Board & Port

| Node | Peran | Endpoint | Short address (MY) | IEEE address (SH+SL) | Port serial (UART) |
|---|---|---|---|---|---|
| Coordinator | Zigbee Coordinator (ZCZR) — switch | 5 | `0x0000` | `74:4D:BD:FF:FE:61:E6:2C` | `COM5` |
| ED COM11 | Zigbee End Device (ED) — light, **ter-binding** | 10 | `0x7EC7` | `74:4D:BD:FF:FE:61:E8:C1` | `COM11` |
| ED COM13 | Zigbee End Device (ED) — light, tidak ter-binding | 10 | `0xEF6E` | `74:4D:BD:FF:FE:61:F3:97` | `COM13` |

Network: channel **18**, PAN ID **`0x4FC6`**, Extended PAN ID
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
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
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

## ED COM11 (ter-binding, menerima perintah)

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
Info network:
  Peran          : End Device (ED)
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x7EC7 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
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

## ED COM13 (join, tidak ter-binding)

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
Info network:
  Peran          : End Device (ED)
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0xEF6E (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 10 (light)
```

## Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)

```
[   0.452] Coordinator | Network Zigbee terbentuk:
[   0.452] Coordinator |   Peran          : Coordinator (ZC)
[   0.452] Coordinator |   Channel        : 18
[   0.452] Coordinator |   PAN ID         : 0x4FC6
[   0.452] Coordinator |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.452] Coordinator |   Short address  : 0x0000
[   0.452] Coordinator |   IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
[   0.452] Coordinator |   Endpoint       : 5 (switch)
[   0.670] Coordinator | Menunggu end device ter-binding...
[   0.670] Coordinator | End device ter-binding!
[   0.702] ED COM11    | Menunggu bergabung ke network koordinator...
[   0.702] ED COM11    | Berhasil bergabung ke network!
[   0.702] ED COM11    | Info network:
[   0.702] ED COM11    |   Peran          : End Device (ED)
[   0.702] ED COM11    |   Channel        : 18
[   0.702] ED COM11    |   PAN ID         : 0x4FC6
[   0.702] ED COM11    |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.924] ED COM11    |   Short address  : 0x7EC7 (diberikan coordinator)
[   0.924] ED COM11    |   IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
[   0.924] ED COM11    |   Endpoint       : 10 (light)
[   5.602] ED COM11    | Lampu ON
[   5.602] Coordinator | Perintah: Lampu ON
[   6.460] ED COM13    | Menunggu bergabung ke network koordinator...
[   6.460] ED COM13    | Berhasil bergabung ke network!
[   6.460] ED COM13    | Info network:
[   6.460] ED COM13    |   Peran          : End Device (ED)
[   6.460] ED COM13    |   Channel        : 18
[   6.460] ED COM13    |   PAN ID         : 0x4FC6
[   6.460] ED COM13    |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   6.682] ED COM13    |   Short address  : 0xEF6E (diberikan coordinator)
[   6.682] ED COM13    |   IEEE address   : 74:4D:BD:FF:FE:61:F3:97
[   6.682] ED COM13    |   Endpoint       : 10 (light)
[  10.591] Coordinator | Perintah: Lampu OFF
[  10.591] ED COM11    | Lampu OFF
[  15.587] Coordinator | Perintah: Lampu ON
[  15.603] ED COM11    | Lampu ON
[  20.600] Coordinator | Perintah: Lampu OFF
[  20.601] ED COM11    | Lampu OFF
[  25.589] Coordinator | Perintah: Lampu ON
[  25.605] ED COM11    | Lampu ON
[  30.596] Coordinator | Perintah: Lampu OFF
[  30.612] ED COM11    | Lampu OFF
[  35.605] Coordinator | Perintah: Lampu ON
[  35.605] ED COM11    | Lampu ON
[  40.594] Coordinator | Perintah: Lampu OFF
[  40.610] ED COM11    | Lampu OFF
[  45.612] Coordinator | Perintah: Lampu ON
[  45.612] ED COM11    | Lampu ON
[  50.592] Coordinator | Perintah: Lampu OFF
[  50.608] ED COM11    | Lampu OFF
[  55.613] Coordinator | Perintah: Lampu ON
[  55.613] ED COM11    | Lampu ON
```

## Ringkasan `monitor_serial.py`

```
Durasi: 60.4 s
  Coordinator switch, ep 5  COM5             30 baris, boot 1x, ter-binding  0.30 s sejak boot
              channel 18, PAN 0x4FC6, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x0000
  ED COM11    light, ep 10  COM11            30 baris, boot 1x, bergabung  0.33 s sejak boot
              channel 18, PAN 0x4FC6, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x7EC7
  ED COM13    light, ep 10  COM13            19 baris, boot 1x, bergabung  6.09 s sejak boot
              channel 18, PAN 0x4FC6, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0xEF6E
  Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Perintah Coordinator -> ED COM11 (COM11)
------------------------------------------------------------
  Perintah dikirim (ZC)      : 11  (ON 6, OFF 5)
  Aksi terlaksana (ED)       : 11
  Loss                       : 0.0%
  Selisih perintah -> aksi   : rata2 7 ms (-0..16)  — timestamp PC, kasar
  Siklus ON/OFF per menit    : 12.0  (harapan 12: satu perintah tiap 5 s)
  Status akhir ZC vs ED      : ON vs ON -> sinkron: ya

Perintah Coordinator -> ED COM13 (COM13)
------------------------------------------------------------
  Perintah dikirim (ZC)      : 11  (ON 6, OFF 5)
  Aksi terlaksana (ED)       : 0
  Loss                       : 100.0%
  Siklus ON/OFF per menit    : 12.0  (harapan 12: satu perintah tiap 5 s)
  Perintah tanpa aksi di ED  : ON @ 5.6 s, OFF @ 10.6 s, ON @ 15.6 s, OFF @ 20.6 s, ON @ 25.6 s, OFF @ 30.6 s, ON @ 35.6 s, OFF @ 40.6 s, ON @ 45.6 s, OFF @ 50.6 s ...

  Laporan balik ke switch ('Lampu sekarang', CH-2): 0

Aksi dipasangkan bila status sama dan jatuh -0.5..+2.0 s dari perintah.
```

## Catatan

- **Info network cocok di ketiga board**: channel 18, PAN ID `0x4FC6`, dan
  Extended PAN ID sama — bukti ketiganya berada di satu network. Short address
  coordinator `0x0000`; short address end device (`0x7EC7`, `0xEF6E`)
  dibagikan coordinator saat join.
- **Extended PAN ID = IEEE address coordinator** (`74:4D:BD:FF:FE:61:E6:2C`),
  karena Extended PAN ID tidak diatur di kode.
- Padanan XBee: `Short address` = MY, `IEEE address` = SH+SL
  (mis. ED COM11: SH `0x744DBDFF`, SL `0xFE61E8C1`), `Channel` = CH (18 =
  `0x12`), `PAN ID` = OI, `Extended PAN ID` = OP. Lihat tabel di README bagian
  Dasar Teori.
- **Hanya satu end device yang menerima perintah.** Coordinator memakai
  `allowMultipleBinding(false)` (P2P), sehingga hanya ED COM11 yang ada di
  binding table. ED COM13 tetap join dan mendapat alamat, tetapi tidak pernah
  mencetak `Lampu ON/OFF` — contoh nyata bahwa *join ≠ binding*.
- `End device ter-binding!` tercetak 0,67 s setelah boot karena binding table
  ikut dipulihkan dari NVS; coordinator tidak menunggu find-and-bind ulang.
- ED COM11 bergabung 0,33 s setelah boot, sebelum perintah pertama (5,6 s),
  sehingga **11 dari 11 perintah sampai (0 % loss)** dengan selisih 0–16 ms
  (timestamp PC, kasar) dan 12 perintah per menit sesuai interval 5 s.
- ED COM13 baru bergabung 6,1 s setelah boot. Lama join berbeda antar-end
  device dan antar-rekaman; bila end device yang ter-binding belum selesai join,
  perintah pertama akan tercatat hilang.
- Library Arduino core 3.3.x tidak pernah men-set `Zigbee.connected()` untuk
  coordinator yang **reboot** dengan `setRebootOpenNetwork()` aktif (seperti
  pada log ini); karena itu firmware coordinator tidak menunggu flag tersebut
  (lihat komentar di `src/coordinator/main.cpp`).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
