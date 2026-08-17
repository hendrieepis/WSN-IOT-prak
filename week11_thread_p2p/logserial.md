# Log Serial — Week 11 (Thread P2P / IPv6)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.

## Board & Port

| Node | Peran | Port serial (UART) |
|---|---|---|
| Node1 | Thread Leader (menjawab PING) | `/dev/ttyACM0` |
| Node2 | Thread Child (mengirim PING) | `/dev/ttyACM2` |

Group multicast `ff03::abcd`, port UDP 5050, channel 15, PAN `0xABCD`.

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
Node1 (Thread Leader) starting...
Menunggu attach...
Attached as: Leader
Mesh-Local EID: fdde:ad00:beef:0:6f99:51e5:8c04:5813
Mendengarkan [ff03::abcd]:5050 (dan unicast)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
```

## Node2 — `/dev/ttyACM2`

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
E (16776) OT_STATE: handle_ot_role_change(105): Failed to get the active dataset
Attached as: Child
Mesh-Local EID: fdde:ad00:beef:0:2375:2134:ab58:2cec
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]:5050 -> 'PONG'
```

## Catatan

- Kedua node memakai dataset Thread identik (nama `ESP_OT_P2P`, channel 15,
  PAN 0xABCD, netkey sama) dan mesh-local prefix yang dipaksa sama agar multicast
  mesh-local (`ff03::/16`) bisa terkirim lintas node.
- Node1 menjadi **Leader**, Node2 menjadi **Child**.
- Node2 mengirim `PING` (UDP multicast ke `ff03::abcd:5050`) tiap 3 detik;
  Node1 menerima dan membalas `PONG` secara unicast ke alamat pengirim.
- Alamat IPv6 pada `RX […]` adalah Mesh-Local EID node pengirim (unik per board).
- Pesan `E (16776) OT_STATE: … Failed to get the active dataset` adalah peringatan
  non-fatal dari port OpenThread ESP32 saat transisi role; tidak menghalangi
  attach maupun komunikasi PING/PONG.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
