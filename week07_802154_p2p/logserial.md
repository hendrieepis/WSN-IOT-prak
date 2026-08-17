# Log Serial — Week 07 (IEEE 802.15.4 P2P / raw frame)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.

## Board & Port

| Node | Peran | short addr | Port serial (UART) |
|---|---|---|---|
| Node1 | Sender (kirim PING) | `0x0001` | `/dev/ttyACM0` |
| Node2 | Receiver (balas PONG) | `0x0002` | `/dev/ttyACM2` |

Channel 15, PAN ID `0xCAFE`.

## Node1 — `/dev/ttyACM0`

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

## Node2 — `/dev/ttyACM2`

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

## Catatan

- Node1 mengirim frame 802.15.4 (raw, tanpa stack Zigbee/Thread) berisi `PING n`
  tiap 2 detik ke short address `0x0002`.
- Node2 menerima, lalu membalas `PONG n` ke `0x0001`.
- FCS dihitung otomatis oleh hardware; pada sisi RX dua byte FCS diganti RSSI+LQI.
- Komunikasi dua arah terbukti dari sisi Node1 (`RX dari 0x0002: PONG n`) dan
  sisi Node2 (`RX dari 0x0001: PING n`).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
