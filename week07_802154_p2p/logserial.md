# Log Serial — Week 07 (IEEE 802.15.4 P2P / raw frame)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1,
firmware `src/node1..3` versi terbaru: promiscuous dimatikan, alamat pengirim
dibaca dari `SrcAddr` frame, dan setiap baris RX membawa RSSI serta LQI.
Semua log direkam dengan `monitor_serial.py` (ketiga port dalam satu komputer,
satu sumbu waktu) lewat port UART CH343 di Windows.

## Board & Port

| Node | Peran | short addr | Port serial (UART) |
|---|---|---|---|
| Node1 | Sender (kirim PING tiap 2 s) | `0x0001` | `COM5` |
| Node2 | Receiver (balas PONG) | `0x0002` | `COM11` |
| Node3 | Receiver tambahan (broadcast, promiscuous) | `0x0003` | `COM13` |

Channel 15, PAN ID `0xCAFE` (kecuali disebut lain).

Format baris RX:

```
RX dari 0x0002: PONG 1  [RSSI -12 dBm, LQI 11]                          # frame untuk node ini
RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 1  [RSSI -12 dBm, LQI 11]  # broadcast / promiscuous
```

RSSI sudah dikoreksi driver ESP-IDF (byte mentah di akhir frame sekitar 10 dB
lebih rendah). LQI adalah nilai mentah hardware ESP32-H2 dengan skala khusus
chip (teramati 6–11), tidak sebanding dengan LQI 0–255 radio lain.

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
RX dari 0x0002: PONG 1  [RSSI -12 dBm, LQI 11]
TX ke 0x0002: PING 2
RX dari 0x0002: PONG 2  [RSSI -12 dBm, LQI 11]
TX ke 0x0002: PING 3
RX dari 0x0002: PONG 3  [RSSI -12 dBm, LQI 11]
TX ke 0x0002: PING 4
RX dari 0x0002: PONG 4  [RSSI -12 dBm, LQI 11]
TX ke 0x0002: PING 5
RX dari 0x0002: PONG 5  [RSSI -12 dBm, LQI 11]
TX ke 0x0002: PING 6
RX dari 0x0002: PONG 6  [RSSI -12 dBm, LQI 10]
TX ke 0x0002: PING 7
RX dari 0x0002: PONG 7  [RSSI -12 dBm, LQI 9]
TX ke 0x0002: PING 8
RX dari 0x0002: PONG 8  [RSSI -12 dBm, LQI 10]
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
RX dari 0x0001: PING 1  [RSSI -11 dBm, LQI 10]
TX balasan ke 0x0001: PONG 1
RX dari 0x0001: PING 2  [RSSI -11 dBm, LQI 11]
TX balasan ke 0x0001: PONG 2
RX dari 0x0001: PING 3  [RSSI -11 dBm, LQI 11]
TX balasan ke 0x0001: PONG 3
RX dari 0x0001: PING 4  [RSSI -11 dBm, LQI 10]
TX balasan ke 0x0001: PONG 4
RX dari 0x0001: PING 5  [RSSI -11 dBm, LQI 10]
TX balasan ke 0x0001: PONG 5
RX dari 0x0001: PING 6  [RSSI -11 dBm, LQI 10]
TX balasan ke 0x0001: PONG 6
RX dari 0x0001: PING 7  [RSSI -11 dBm, LQI 10]
TX balasan ke 0x0001: PONG 7
RX dari 0x0001: PING 8  [RSSI -11 dBm, LQI 10]
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

### Ringkasan `monitor_serial.py`

```
Durasi: 17.8 s
  Node2  0x0002  COM11          27 baris
  Node3  0x0003  COM13          11 baris
  Node1  0x0001  COM5           27 baris

Link (pengirim -> penerima)      jenis  kirim  terima   loss   RSSI dBm rata2 (min..max)   LQI rata2 (min..max)
----------------------------------------------------------------------------------------------------------------
Node1(0x0001) -> Node2(0x0002)   PING       8      8    0.0%    -11.0 (-11..-11)             10.2 (10..11)
Node2(0x0002) -> Node1(0x0001)   PONG       8      8    0.0%    -12.0 (-12..-12)             10.5 (9..11)

kirim = TX pengirim yang dialamatkan ke penerima (unicast atau broadcast); '-' = tidak dialamatkan.
```

## 2. EXP-04-e — Broadcast (`PEER_ADDR 0xFFFF` di Node1)

Node2 dan Node3 menerima semua PING dan sama-sama membalas, tetapi seluruh
PONG yang sampai ke Node1 berasal dari `0x0003`. RSSI menjelaskannya: di Node1,
sinyal Node3 sekitar −4 dBm, sedangkan sinyal Node2 sekitar −12 dBm (lihat
baseline). Kedua PONG bertabrakan dan Node1 menangkap yang lebih kuat
(*capture effect*); tanpa ACK, Node2 tidak tahu PONG-nya hilang.

```
[  0.507] Node3 | Node3 (802.15.4 receiver) starting...
[  0.507] Node2 | Node2 (802.15.4 receiver) starting...
[  0.507] Node2 | Channel 15, PAN 0xCAFE, short addr 0x0002
[  0.507] Node3 | Channel 15, PAN 0xCAFE, short addr 0x0003
[  0.524] Node1 | Node1 (802.15.4 sender) starting...
[  0.524] Node1 | Channel 15, PAN 0xCAFE, short addr 0x0001
[  2.493] Node1 | TX ke 0xFFFF: PING 1
[  2.493] Node2 | RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 1  [RSSI -12 dBm, LQI 11]
[  2.493] Node3 | RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 1  [RSSI -6 dBm, LQI 11]
[  2.493] Node3 | TX balasan ke 0x0001: PONG 1
[  2.493] Node2 | TX balasan ke 0x0001: PONG 1
[  2.493] Node1 | RX dari 0x0003: PONG 1  [RSSI -2 dBm, LQI 10]
[  4.495] Node1 | TX ke 0xFFFF: PING 2
[  4.495] Node3 | RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 2  [RSSI -6 dBm, LQI 11]
[  4.495] Node2 | RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 2  [RSSI -12 dBm, LQI 11]
[  4.495] Node2 | TX balasan ke 0x0001: PONG 2
[  4.495] Node3 | TX balasan ke 0x0001: PONG 2
[  4.495] Node1 | RX dari 0x0003: PONG 2  [RSSI -3 dBm, LQI 9]
[  6.500] Node2 | RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 3  [RSSI -12 dBm, LQI 11]
[  6.500] Node2 | TX balasan ke 0x0001: PONG 3
[  6.500] Node1 | TX ke 0xFFFF: PING 3
[  6.500] Node3 | RX dari 0x0001 (ke 0xFFFF, PAN 0xCAFE): PING 3  [RSSI -6 dBm, LQI 11]
[  6.500] Node1 | RX dari 0x0003: PONG 3  [RSSI -6 dBm, LQI 8]
[  6.500] Node3 | TX balasan ke 0x0001: PONG 3
```

```
Durasi: 25.6 s
  Node2  0x0002  COM11          35 baris
  Node3  0x0003  COM13          35 baris
  Node1  0x0001  COM5           35 baris

Link (pengirim -> penerima)      jenis  kirim  terima   loss   RSSI dBm rata2 (min..max)   LQI rata2 (min..max)
----------------------------------------------------------------------------------------------------------------
Node1(0x0001) -> Node2(0x0002)   PING      12     12    0.0%    -12.0 (-12..-12)             10.2 (9..11)
Node1(0x0001) -> Node3(0x0003)   PING      12     12    0.0%     -5.4 (-6..-5)               10.6 (10..11)
Node2(0x0002) -> Node1(0x0001)   PONG      12      0  100.0%   -                           -
Node3(0x0003) -> Node1(0x0001)   PONG      12     12    0.0%     -3.8 (-6..-2)                8.8 (7..10)

kirim = TX pengirim yang dialamatkan ke penerima (unicast atau broadcast); '-' = tidak dialamatkan.
```

## 3. EXP-05-b — PAN beda, Node2 promiscuous `true`

Node2 memakai `PAN_ID 0xBEEF` dan `set_promiscuous(true)`. Node2 menerima PING
dari PAN asing (terlihat dari `PAN 0xCAFE` pada log), tetapi PONG-nya membawa
Dest PAN `0xBEEF` sehingga disaring Node1.

```
[  0.502] Node2 | Node2 (802.15.4 receiver) starting...
[  0.502] Node2 | Channel 15, PAN 0xBEEF, short addr 0x0002
[  0.517] Node3 | Node3 (802.15.4 receiver) starting...
[  0.517] Node1 | Node1 (802.15.4 sender) starting...
[  0.517] Node1 | Channel 15, PAN 0xCAFE, short addr 0x0001
[  0.517] Node3 | Channel 15, PAN 0xCAFE, short addr 0x0003
[  2.483] Node1 | TX ke 0x0002: PING 1
[  2.499] Node2 | RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 1  [RSSI -11 dBm, LQI 10]
[  2.499] Node2 | TX balasan ke 0x0001: PONG 1
[  4.489] Node1 | TX ke 0x0002: PING 2
[  4.504] Node2 | RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 2  [RSSI -11 dBm, LQI 10]
[  4.504] Node2 | TX balasan ke 0x0001: PONG 2
[  6.495] Node1 | TX ke 0x0002: PING 3
[  6.495] Node2 | RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 3  [RSSI -11 dBm, LQI 10]
[  6.495] Node2 | TX balasan ke 0x0001: PONG 3
```

```
Durasi: 25.9 s
  Node2  0x0002  COM11          35 baris
  Node3  0x0003  COM13          11 baris
  Node1  0x0001  COM5           23 baris

Link (pengirim -> penerima)      jenis  kirim  terima   loss   RSSI dBm rata2 (min..max)   LQI rata2 (min..max)
----------------------------------------------------------------------------------------------------------------
Node1(0x0001) -> Node2(0x0002)   PING      12     12    0.0%    -11.0 (-11..-11)             10.2 (10..11)
Node2(0x0002) -> Node1(0x0001)   PONG      12      0  100.0%   -                           -

kirim = TX pengirim yang dialamatkan ke penerima (unicast atau broadcast); '-' = tidak dialamatkan.
```

## 4. EXP-05-d — PAN sama, Node3 promiscuous `true`

Node3 ikut menerima PING yang ditujukan ke `0x0002` dan membalasnya. PONG Node2
dan Node3 bertabrakan: Node1 hanya menerima PONG dari `0x0003` (sinyal lebih
kuat), dan pada sebagian besar PING tidak menerima PONG sama sekali.

```
[  0.502] Node2 | Node2 (802.15.4 receiver) starting...
[  0.502] Node3 | Node3 (802.15.4 receiver) starting...
[  0.502] Node2 | Channel 15, PAN 0xCAFE, short addr 0x0002
[  0.502] Node3 | Channel 15, PAN 0xCAFE, short addr 0x0003
[  0.516] Node1 | Node1 (802.15.4 sender) starting...
[  0.516] Node1 | Channel 15, PAN 0xCAFE, short addr 0x0001
[  2.487] Node1 | TX ke 0x0002: PING 1
[  2.487] Node2 | RX dari 0x0001: PING 1  [RSSI -11 dBm, LQI 11]
[  2.487] Node3 | RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 1  [RSSI -5 dBm, LQI 10]
[  2.487] Node3 | TX balasan ke 0x0001: PONG 1
[  2.487] Node2 | TX balasan ke 0x0001: PONG 1
[  4.492] Node1 | TX ke 0x0002: PING 2
[  4.492] Node3 | RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 2  [RSSI -5 dBm, LQI 10]
[  4.492] Node2 | RX dari 0x0001: PING 2  [RSSI -11 dBm, LQI 10]
[  4.492] Node1 | RX dari 0x0003: PONG 2  [RSSI -4 dBm, LQI 8]
[  4.492] Node3 | TX balasan ke 0x0001: PONG 2
[  4.492] Node2 | TX balasan ke 0x0001: PONG 2
[  6.490] Node1 | TX ke 0x0002: PING 3
[  6.490] Node2 | RX dari 0x0001: PING 3  [RSSI -11 dBm, LQI 10]
[  6.490] Node2 | TX balasan ke 0x0001: PONG 3
[  6.505] Node3 | RX dari 0x0001 (ke 0x0002, PAN 0xCAFE): PING 3  [RSSI -5 dBm, LQI 10]
[  6.505] Node3 | TX balasan ke 0x0001: PONG 3
```

```
Durasi: 25.8 s
  Node2  0x0002  COM11          35 baris
  Node3  0x0003  COM13          35 baris
  Node1  0x0001  COM5           28 baris

Link (pengirim -> penerima)      jenis  kirim  terima   loss   RSSI dBm rata2 (min..max)   LQI rata2 (min..max)
----------------------------------------------------------------------------------------------------------------
Node1(0x0001) -> Node2(0x0002)   PING      12     12    0.0%    -11.0 (-11..-11)             10.5 (10..11)
Node1(0x0001) -> Node3(0x0003)   PING       -     12     n/a     -5.0 (-5..-5)               10.3 (10..11)
Node2(0x0002) -> Node1(0x0001)   PONG      12      0  100.0%   -                           -
Node3(0x0003) -> Node1(0x0001)   PONG      12      5   58.3%     -3.2 (-4..-2)                7.6 (6..9)

Frame yang bukan untuk penerimanya (hanya lolos bila promiscuous aktif):
  Node3(0x0003) menangkap PING dari Node1(0x0001) ke Node2(0x0002): 12x

kirim = TX pengirim yang dialamatkan ke penerima (unicast atau broadcast); '-' = tidak dialamatkan.
```

## Catatan

- Node1 mengirim frame 802.15.4 (raw, tanpa stack Zigbee/Thread) berisi `PING n`
  tiap 2 detik ke `PEER_ADDR` (`0x0002`, atau `0xFFFF` saat uji broadcast).
- Node2/Node3 membalas `PONG n` ke **alamat pengirim** yang dibaca dari
  `SrcAddr` frame, dan hanya membalas PING.
- `RX dari 0x....` adalah alamat asli dari header frame. Bila frame bukan untuk
  node tersebut (broadcast atau lolos karena promiscuous), tujuan dan PAN-nya
  ikut dicetak.
- FCS dihitung otomatis oleh hardware; pada sisi RX dua byte FCS diganti RSSI+LQI,
  yang disalin driver ke `frame_info->rssi` dan `frame_info->lqi`.
- Timestamp dicatat PC saat baris tiba di port masing-masing. Baris dengan
  timestamp sama berasal dari port berbeda, sehingga urutannya tidak selalu
  mencerminkan urutan kejadian di udara (mis. `RX ... PONG` bisa tercetak
  sebelum `TX ... PING`).
- Kolom `kirim` pada ringkasan dihitung dari baris TX; frame yang dikirim tepat
  sebelum monitor berhenti bisa tercatat hilang (selisih satu).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
