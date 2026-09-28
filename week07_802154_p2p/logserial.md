# Log Serial — Week 07 (IEEE 802.15.4 P2P / raw frame)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1,
firmware `src/node1..3` versi terbaru (promiscuous dimatikan, alamat pengirim
dibaca dari `SrcAddr` frame). Log diambil lewat port UART CH343 di Windows.

## Board & Port

| Node | Peran | short addr | Port serial (UART) |
|---|---|---|---|
| Node1 | Sender (kirim PING tiap 2 s) | `0x0001` | `COM5` |
| Node2 | Receiver (balas PONG) | `0x0002` | `COM11` |
| Node3 | Receiver tambahan (broadcast, promiscuous) | `0x0003` | `COM13` |

Channel 15, PAN ID `0xCAFE` (kecuali disebut lain).

## 1. Baseline — PING–PONG Node1 ↔ Node2 (kode asli)

Semua node memakai `esp_ieee802154_set_promiscuous(false)`. Node3 menyala
tetapi tidak mencetak `RX` apa pun, karena PING ditujukan ke `0x0002`.

### Node1 — COM5

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
Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0x0002: PING 1
RX dari 0x0002: PONG 1
TX ke 0x0002: PING 2
RX dari 0x0002: PONG 2
TX ke 0x0002: PING 3
RX dari 0x0002: PONG 3
TX ke 0x0002: PING 4
RX dari 0x0002: PONG 4
TX ke 0x0002: PING 5
RX dari 0x0002: PONG 5
TX ke 0x0002: PING 6
RX dari 0x0002: PONG 6
TX ke 0x0002: PING 7
RX dari 0x0002: PONG 7
TX ke 0x0002: PING 8
RX dari 0x0002: PONG 8
```

### Node2 — COM11

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
Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0002
RX dari 0x0001: PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001: PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001: PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001: PING 4
TX balasan ke 0x0001: PONG 4
RX dari 0x0001: PING 5
TX balasan ke 0x0001: PONG 5
RX dari 0x0001: PING 6
TX balasan ke 0x0001: PONG 6
RX dari 0x0001: PING 7
TX balasan ke 0x0001: PONG 7
RX dari 0x0001: PING 8
TX balasan ke 0x0001: PONG 8
```

### Node3 — COM13

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
Node3 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0003
```

## 2. EXP-04-e — Broadcast (`PEER_ADDR 0xFFFF` di Node1)

Baris ROM boot dihilangkan. Node2 dan Node3 menerima semua PING dan sama-sama
membalas, tetapi Node1 hanya mencetak PONG dari `0x0003`: kedua PONG dikirim
hampir bersamaan dan bertabrakan, Node1 menangkap yang lebih kuat.

### Node1 — COM5

```
Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0xFFFF: PING 1
RX dari 0x0003: PONG 1
TX ke 0xFFFF: PING 2
RX dari 0x0003: PONG 2
TX ke 0xFFFF: PING 3
RX dari 0x0003: PONG 3
TX ke 0xFFFF: PING 4
RX dari 0x0003: PONG 4
```

### Node2 — COM11

```
Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0002
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 4
TX balasan ke 0x0001: PONG 4
```

### Node3 — COM13

```
Node3 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0003
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 4
TX balasan ke 0x0001: PONG 4
```

## 3. EXP-05-b — PAN beda, Node2 promiscuous `true`

Node2 memakai `PAN_ID 0xBEEF` dan `set_promiscuous(true)`. Node2 menerima PING
dari PAN asing (terlihat dari `PAN 0xCAFE` pada log), tetapi PONG-nya membawa
Dest PAN `0xBEEF` sehingga disaring Node1.

### Node1 — COM5

```
Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0x0002: PING 1
TX ke 0x0002: PING 2
TX ke 0x0002: PING 3
TX ke 0x0002: PING 4
```

### Node2 — COM11

```
Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xBEEF, short addr 0x0002
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 4
TX balasan ke 0x0001: PONG 4
```

### Node3 — COM13

```
Node3 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0003
```

## 4. EXP-05-d — PAN sama, Node3 promiscuous `true`

Node3 ikut menerima PING yang ditujukan ke `0x0002` dan membalasnya. PONG Node2
dan Node3 bertabrakan; pada capture ini seluruh PONG yang sampai ke Node1
berasal dari `0x0003`. Pembagiannya bervariasi antar-percobaan — pada uji
25 detik sebelumnya: 5 PONG dari `0x0002` dan 7 dari `0x0003` (bila PING di
Node3 sudah tertimpa PONG Node2, Node3 mencetak
`RX dari 0x0002 (ke 0x0001, ...)` dan tidak membalas).

### Node1 — COM5

```
Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0x0002: PING 1
RX dari 0x0003: PONG 1
TX ke 0x0002: PING 2
RX dari 0x0003: PONG 2
TX ke 0x0002: PING 3
RX dari 0x0003: PONG 3
TX ke 0x0002: PING 4
RX dari 0x0003: PONG 4
TX ke 0x0002: PING 5
RX dari 0x0003: PONG 5
TX ke 0x0002: PING 6
RX dari 0x0003: PONG 6
```

### Node2 — COM11

```
Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0002
RX dari 0x0001: PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001: PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001: PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001: PING 4
TX balasan ke 0x0001: PONG 4
RX dari 0x0001: PING 5
TX balasan ke 0x0001: PONG 5
RX dari 0x0001: PING 6
TX balasan ke 0x0001: PONG 6
```

### Node3 — COM13

```
Node3 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0003
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 4
TX balasan ke 0x0001: PONG 4
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 5
TX balasan ke 0x0001: PONG 5
RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 6
TX balasan ke 0x0001: PONG 6
```

## Catatan

- Node1 mengirim frame 802.15.4 (raw, tanpa stack Zigbee/Thread) berisi `PING n`
  tiap 2 detik ke `PEER_ADDR` (`0x0002`, atau `0xFFFF` saat uji broadcast).
- Node2/Node3 membalas `PONG n` ke **alamat pengirim** yang dibaca dari
  `SrcAddr` frame, dan hanya membalas PING.
- `RX dari 0x....` adalah alamat asli dari header frame. Bila frame bukan untuk
  node tersebut (broadcast atau lolos karena promiscuous), tujuan dan PAN-nya
  ikut dicetak: `RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE)`.
- FCS dihitung otomatis oleh hardware; pada sisi RX dua byte FCS diganti RSSI+LQI.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
