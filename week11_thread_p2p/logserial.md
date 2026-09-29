# Log Serial — Week 11 (Thread P2P / IPv6)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2 DevKitM-1,
firmware versi terbaru: setelah attach, tiap node mencetak info network
Thread — peran, network name, channel, PAN ID, Extended PAN ID, RLOC16,
Extended Address, EUI-64, dan Mesh-Local EID. Log direkam 60 detik dengan
`monitor_serial.py` (kedua port dalam satu komputer, satu sumbu waktu) lewat port
UART CH343 di Windows. Board di-`erase` lalu di-flash; monitor me-reset semua
board saat port dibuka, sehingga semua node boot hampir bersamaan.

## Board & Port

| Node | Peran (terpilih) | RLOC16 | EUI-64 (pabrik) | Extended addr (acak) | Port serial (UART) |
|---|---|---|---|---|---|
| Node1 | Child — menjawab PING | `0xE801` | `74:4D:BD:FF:FE:61:E6:2C` | `FA:FE:07:23:A6:B1:A9:FB` | `COM5` |
| Node2 | **Leader** — mengirim PING | `0xE800` | `74:4D:BD:FF:FE:61:E8:C1` | `3E:CC:8F:12:00:85:DF:E5` | `COM11` |

Network `ESP_OT_P2P`, channel **15**, PAN ID **`0xABCD`**, Extended PAN ID
**`DE:AD:00:BE:EF:00:CA:FE`** — sama di kedua node. Group multicast
`ff03::abcd`, port UDP 5050.

## Node1 — COM5

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
Node1 (Thread Leader) starting...
Menunggu attach...
Attached as: Child
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_P2P
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0xE801
  Extended addr  : FA:FE:07:23:A6:B1:A9:FB
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:e54c:17e1:80ad:62a4
Mendengarkan [ff03::abcd]:5050 (dan unicast)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
```

## Node2 — COM11

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
Node2 (Thread Child) starting...
Menunggu join ke network Leader...
Attached as: Leader
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_P2P
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0xE800
  Extended addr  : 3E:CC:8F:12:00:85:DF:E5
  EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
  Mesh-Local EID : fdde:ad00:beef:0:cbc4:ae06:ccea:2768
TX PING (multicast)
TX PING (multicast)
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
```

## Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)

```
[   0.739] Node2  | Node2 (Thread Child) starting...
[   0.739] Node2  | Menunggu join ke network Leader...
[   0.752] Node1  | Node1 (Thread Leader) starting...
[   0.752] Node1  | Menunggu attach...
[   7.303] Node2  | Attached as: Leader
[   7.303] Node2  | Info network Thread:
[   7.303] Node2  |   Peran          : Leader
[   7.303] Node2  |   Network name   : ESP_OT_P2P
[   7.303] Node2  |   Channel        : 15
[   7.303] Node2  |   PAN ID         : 0xABCD
[   7.303] Node2  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[   7.303] Node2  |   RLOC16         : 0xE800
[   7.529] Node2  |   Extended addr  : 3E:CC:8F:12:00:85:DF:E5
[   7.529] Node2  |   EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
[   7.529] Node2  |   Mesh-Local EID : fdde:ad00:beef:0:cbc4:ae06:ccea:2768
[   7.529] Node2  | TX PING (multicast)
[  10.527] Node2  | TX PING (multicast)
[  10.562] Node1  | Attached as: Child
[  10.562] Node1  | Info network Thread:
[  10.562] Node1  |   Peran          : Child
[  10.562] Node1  |   Network name   : ESP_OT_P2P
[  10.562] Node1  |   Channel        : 15
[  10.562] Node1  |   PAN ID         : 0xABCD
[  10.562] Node1  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  10.562] Node1  |   RLOC16         : 0xE801
[  10.780] Node1  |   Extended addr  : FA:FE:07:23:A6:B1:A9:FB
[  10.781] Node1  |   EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
[  10.781] Node1  |   Mesh-Local EID : fdde:ad00:beef:0:e54c:17e1:80ad:62a4
[  10.781] Node1  | Mendengarkan [ff03::abcd]:5050 (dan unicast)
[  13.541] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  13.541] Node1  | TX PONG (unicast ke pengirim)
[  13.581] Node2  | TX PING (multicast)
[  13.581] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  16.554] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  16.554] Node1  | TX PONG (unicast ke pengirim)
[  16.570] Node2  | TX PING (multicast)
[  16.570] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  19.547] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  19.548] Node1  | TX PONG (unicast ke pengirim)
[  19.582] Node2  | TX PING (multicast)
[  19.582] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  22.551] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  22.552] Node1  | TX PONG (unicast ke pengirim)
[  22.567] Node2  | TX PING (multicast)
[  22.567] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  25.556] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  25.556] Node1  | TX PONG (unicast ke pengirim)
[  25.582] Node2  | TX PING (multicast)
[  25.582] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  28.568] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  28.569] Node1  | TX PONG (unicast ke pengirim)
[  28.568] Node2  | TX PING (multicast)
[  28.569] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  31.561] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  31.561] Node1  | TX PONG (unicast ke pengirim)
[  31.584] Node2  | TX PING (multicast)
[  31.584] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  34.571] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  34.571] Node1  | TX PONG (unicast ke pengirim)
[  34.586] Node2  | TX PING (multicast)
[  34.586] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  37.577] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  37.577] Node1  | TX PONG (unicast ke pengirim)
[  37.583] Node2  | TX PING (multicast)
[  37.584] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  40.573] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  40.573] Node1  | TX PONG (unicast ke pengirim)
[  40.583] Node2  | TX PING (multicast)
[  40.583] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  43.583] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  43.583] Node1  | TX PONG (unicast ke pengirim)
[  43.583] Node2  | TX PING (multicast)
[  43.584] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  46.587] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  46.587] Node1  | TX PONG (unicast ke pengirim)
[  46.598] Node2  | TX PING (multicast)
[  46.598] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  49.600] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  49.600] Node1  | TX PONG (unicast ke pengirim)
[  49.600] Node2  | TX PING (multicast)
[  49.601] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  52.600] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  52.601] Node1  | TX PONG (unicast ke pengirim)
[  52.614] Node2  | TX PING (multicast)
[  52.614] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  55.605] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  55.605] Node1  | TX PONG (unicast ke pengirim)
[  55.621] Node2  | TX PING (multicast)
[  55.621] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  58.628] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  58.628] Node1  | TX PONG (unicast ke pengirim)
[  58.628] Node2  | TX PING (multicast)
[  58.628] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
```

## Ringkasan `monitor_serial.py`

```
Durasi: 60.4 s
  Node1  Child   COM5             55 baris, boot 1x, attach 10.20 s sejak boot
         EID fdde:ad00:beef:0:e54c:17e1:80ad:62a4
         network ESP_OT_P2P, channel 15, PAN 0xABCD, RLOC16 0xE801, EUI-64 74:4D:BD:FF:FE:61:E6:2C
  Node2  Leader  COM11            56 baris, boot 1x, attach  6.92 s sejak boot
         EID fdde:ad00:beef:0:cbc4:ae06:ccea:2768
         network ESP_OT_P2P, channel 15, PAN 0xABCD, RLOC16 0xE800, EUI-64 74:4D:BD:FF:FE:61:E8:C1
  Network name/Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Link (pengirim -> penerima)   jenis   kirim  terima    loss
------------------------------------------------------------
Node1 -> Node2                PONG       16      16     0.0%
Node2 -> Node1                PING       16      16     0.0%

Round-trip di Node2: 16/18 PING dijawab PONG (88.9%)
  RTT PING -> PONG: rata2 0 ms (0..0) — timestamp PC, kasar

Loss hanya menghitung pesan setelah penerima siap; 'n/a' = tidak bisa dihitung.
```

## Catatan

- **Info network cocok di kedua node**: network name, channel, PAN ID, dan
  Extended PAN ID sama — nilai ini berasal dari dataset yang ditulis kode,
  bukan dipilih jaringan (berbeda dengan Zigbee).
- **Peran tidak ditentukan kode.** Banner firmware menyebut
  `Node1 (Thread Leader)`, tetapi pada rekaman ini **Node2 menjadi Leader**
  (attach 6,9 s) dan Node1 menjadi Child (10,2 s): node yang lebih dulu
  membentuk partisi menjadi Leader. Aplikasi tetap berjalan karena PING/PONG
  tidak bergantung pada peran.
- **RLOC16 menunjukkan parent.** Leader `0xE800` adalah router dengan Router ID
  58 (`0xE800 >> 10`); Child `0xE801` memakai Router ID yang sama ditambah
  Child ID 1, artinya parent Node1 adalah Node2.
- **Padanan alamat** (bandingkan dengan XBee dan Zigbee di Modul 08):
  `RLOC16` ≈ MY (alamat 16-bit, dibagikan jaringan dan **bisa berubah** bila
  peran/parent berubah); `EUI-64` = SH+SL (alamat pabrik, tetap);
  `Channel` = CH; `PAN ID` = OI; `Extended PAN ID` = OP.
- **Extended addr ≠ EUI-64.** Thread memakai Extended Address **acak** sebagai
  alamat MAC 64-bit (privasi), berbeda dengan Zigbee yang memakai IEEE address
  pabrik. Alamat yang tetap untuk mengenali board tetap EUI-64.
- **Mesh-Local EID** adalah alamat IPv6 node di dalam mesh; alamat ini yang
  muncul di baris `RX [...]`. Awalannya (`fdde:ad00:beef:0:`) harus sama di
  semua node.
- **PING/PONG 16/16 (0 % loss)** setelah Node1 siap. Dua PING pertama Node2
  (dikirim sebelum Node1 attach) tidak terjawab, sehingga round-trip tercatat
  16/18. RTT tercatat 0 ms karena PONG tiba di bawah resolusi timestamp PC.
- Selisih waktu memakai timestamp PC, jadi kasar (resolusi USB-serial).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
