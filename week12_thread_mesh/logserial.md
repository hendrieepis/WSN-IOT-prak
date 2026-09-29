# Log Serial — Week 12 (Thread Mesh)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1,
firmware versi terbaru: setelah attach, tiap node mencetak info network
Thread — peran, network name, channel, PAN ID, Extended PAN ID, RLOC16,
Extended Address, EUI-64, dan Mesh-Local EID. Log direkam 60 detik dengan
`monitor_serial.py` (ketiga port dalam satu komputer, satu sumbu waktu) lewat port
UART CH343 di Windows. Board di-`erase` lalu di-flash; monitor me-reset semua
board saat port dibuka, sehingga semua node boot hampir bersamaan.

## Board & Port

| Node | Peran (terpilih) | RLOC16 | EUI-64 (pabrik) | Extended addr (acak) | Port serial (UART) |
|---|---|---|---|---|---|
| Node1 | Router | `0x1C00` | `74:4D:BD:FF:FE:61:E6:2C` | `56:22:E4:9A:19:AC:56:CA` | `COM5` |
| Node2 | Child (parent: Node1) | `0x1C01` | `74:4D:BD:FF:FE:61:E8:C1` | `FE:8E:2B:FE:9E:44:7E:ED` | `COM11` |
| Node3 | **Leader** | `0x6C00` | `74:4D:BD:FF:FE:61:F3:97` | `AA:64:77:10:45:C5:74:41` | `COM13` |

Network `ESP_OT_MESH`, channel **15**, PAN ID **`0xABCD`**, Extended PAN ID
**`DE:AD:00:BE:EF:00:CA:FE`** — sama di ketiga node. Group multicast
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
Node1 (Thread) starting...
Attached as: Router
Info network Thread:
  Peran          : Router
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x1C00
  Extended addr  : 56:22:E4:9A:19:AC:56:CA
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE1:1
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
TX multicast: NODE1:2
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
TX multicast: NODE1:3
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
TX multicast: NODE1:4
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
TX multicast: NODE1:5
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
TX multicast: NODE1:6
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
TX multicast: NODE1:7
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
TX multicast: NODE1:8
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
TX multicast: NODE1:9
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
TX multicast: NODE1:10
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
TX multicast: NODE1:11
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
Node2 (Thread) starting...
E (11623) OT_STATE: handle_ot_role_change(105): Failed to get the active dataset
Attached as: Child
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x1C01
  Extended addr  : FE:8E:2B:FE:9E:44:7E:ED
  EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
  Mesh-Local EID : fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE2:1
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
TX multicast: NODE2:2
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
TX multicast: NODE2:3
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
TX multicast: NODE2:4
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
TX multicast: NODE2:5
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
TX multicast: NODE2:6
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
TX multicast: NODE2:7
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
TX multicast: NODE2:8
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
TX multicast: NODE2:9
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
TX multicast: NODE2:10
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11
```

## Node3 — COM13

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
Node3 (Thread) starting...
Attached as: Leader
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C00
  Extended addr  : AA:64:77:10:45:C5:74:41
  EUI-64         : 74:4D:BD:FF:FE:61:F3:97
  Mesh-Local EID : fdde:ad00:beef:0:f915:1df2:1a01:26c9
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE3:1
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:1
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
TX multicast: NODE3:2
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
TX multicast: NODE3:3
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
TX multicast: NODE3:4
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
TX multicast: NODE3:5
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
TX multicast: NODE3:6
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
TX multicast: NODE3:7
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
TX multicast: NODE3:8
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
TX multicast: NODE3:9
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
TX multicast: NODE3:10
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
TX multicast: NODE3:11
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11
```

## Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)

```
[   0.682] Node3  | Node3 (Thread) starting...
[   0.682] Node2  | Node2 (Thread) starting...
[   0.682] Node1  | Node1 (Thread) starting...
[   7.547] Node3  | Attached as: Leader
[   7.547] Node3  | Info network Thread:
[   7.547] Node3  |   Peran          : Leader
[   7.547] Node3  |   Network name   : ESP_OT_MESH
[   7.547] Node3  |   Channel        : 15
[   7.547] Node3  |   PAN ID         : 0xABCD
[   7.547] Node3  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[   7.547] Node3  |   RLOC16         : 0x6C00
[   7.763] Node3  |   Extended addr  : AA:64:77:10:45:C5:74:41
[   7.763] Node3  |   EUI-64         : 74:4D:BD:FF:FE:61:F3:97
[   7.763] Node3  |   Mesh-Local EID : fdde:ad00:beef:0:f915:1df2:1a01:26c9
[   7.763] Node3  | Bergabung ke mesh, siap kirim/terima.
[   7.763] Node3  | TX multicast: NODE3:1
[  10.063] Node1  | Attached as: Router
[  10.064] Node1  | Info network Thread:
[  10.064] Node1  |   Peran          : Router
[  10.064] Node1  |   Network name   : ESP_OT_MESH
[  10.064] Node1  |   Channel        : 15
[  10.064] Node1  |   PAN ID         : 0xABCD
[  10.064] Node1  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  10.064] Node1  |   RLOC16         : 0x1C00
[  10.282] Node1  |   Extended addr  : 56:22:E4:9A:19:AC:56:CA
[  10.283] Node1  |   EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
[  10.283] Node1  |   Mesh-Local EID : fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
[  10.283] Node1  | Bergabung ke mesh, siap kirim/terima.
[  10.283] Node1  | TX multicast: NODE1:1
[  10.297] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:1
[  11.816] Node2  | E (11623) OT_STATE: handle_ot_role_change(105): Failed to get the active dataset
[  11.816] Node2  | Attached as: Child
[  11.816] Node2  | Info network Thread:
[  11.816] Node2  |   Peran          : Child
[  11.816] Node2  |   Network name   : ESP_OT_MESH
[  11.816] Node2  |   Channel        : 15
[  11.816] Node2  |   PAN ID         : 0xABCD
[  12.048] Node2  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  12.048] Node2  |   RLOC16         : 0x1C01
[  12.048] Node2  |   Extended addr  : FE:8E:2B:FE:9E:44:7E:ED
[  12.048] Node2  |   EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
[  12.048] Node2  |   Mesh-Local EID : fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d
[  12.048] Node2  | Bergabung ke mesh, siap kirim/terima.
[  12.048] Node2  | TX multicast: NODE2:1
[  12.048] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
[  12.111] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
[  12.778] Node3  | TX multicast: NODE3:2
[  12.786] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
[  12.834] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
[  15.284] Node1  | TX multicast: NODE1:2
[  15.297] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
[  15.297] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
[  17.039] Node2  | TX multicast: NODE2:2
[  17.052] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
[  17.129] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
[  17.778] Node3  | TX multicast: NODE3:3
[  17.791] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
[  17.791] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
[  20.290] Node1  | TX multicast: NODE1:3
[  20.311] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
[  20.311] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
[  22.041] Node2  | TX multicast: NODE2:3
[  22.054] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
[  22.097] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
[  22.776] Node3  | TX multicast: NODE3:4
[  22.791] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
[  22.791] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
[  25.296] Node1  | TX multicast: NODE1:4
[  25.312] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
[  25.313] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
[  27.059] Node2  | TX multicast: NODE2:4
[  27.061] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
[  27.075] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
[  27.787] Node3  | TX multicast: NODE3:5
[  27.802] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
[  27.802] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
[  30.308] Node1  | TX multicast: NODE1:5
[  30.323] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
[  30.323] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
[  32.063] Node2  | TX multicast: NODE2:5
[  32.063] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
[  32.128] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
[  32.791] Node3  | TX multicast: NODE3:6
[  32.800] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
[  32.804] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
[  35.322] Node1  | TX multicast: NODE1:6
[  35.323] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
[  35.328] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
[  37.060] Node2  | TX multicast: NODE2:6
[  37.075] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
[  37.140] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
[  37.794] Node3  | TX multicast: NODE3:7
[  37.807] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
[  37.807] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
[  40.334] Node1  | TX multicast: NODE1:7
[  40.334] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
[  40.334] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
[  42.076] Node2  | TX multicast: NODE2:7
[  42.092] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
[  42.123] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
[  42.800] Node3  | TX multicast: NODE3:8
[  42.815] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
[  42.816] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
[  45.334] Node1  | TX multicast: NODE1:8
[  45.349] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
[  45.350] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
[  47.077] Node2  | TX multicast: NODE2:8
[  47.093] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
[  47.109] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
[  47.813] Node3  | TX multicast: NODE3:9
[  47.828] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
[  47.828] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
[  50.344] Node1  | TX multicast: NODE1:9
[  50.359] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
[  50.360] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
[  52.089] Node2  | TX multicast: NODE2:9
[  52.105] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
[  52.136] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
[  52.804] Node3  | TX multicast: NODE3:10
[  52.820] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
[  52.820] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
[  55.345] Node1  | TX multicast: NODE1:10
[  55.358] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
[  55.358] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
[  57.094] Node2  | TX multicast: NODE2:10
[  57.110] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
[  57.141] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
[  57.823] Node3  | TX multicast: NODE3:11
[  57.838] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
[  57.838] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
[  60.357] Node1  | TX multicast: NODE1:11
[  60.371] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11
[  60.371] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11
```

## Ringkasan `monitor_serial.py`

```
Durasi: 60.4 s
  Node1  Router  COM5             53 baris, boot 1x, attach  9.69 s sejak boot
         EID fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
         network ESP_OT_MESH, channel 15, PAN 0xABCD, RLOC16 0x1C00, EUI-64 74:4D:BD:FF:FE:61:E6:2C
  Node2  Child   COM11            53 baris, boot 1x, attach 11.44 s sejak boot, 1 peringatan OT
         EID fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d
         network ESP_OT_MESH, channel 15, PAN 0xABCD, RLOC16 0x1C01, EUI-64 74:4D:BD:FF:FE:61:E8:C1
  Node3  Leader  COM13            54 baris, boot 1x, attach  7.17 s sejak boot
         EID fdde:ad00:beef:0:f915:1df2:1a01:26c9
         network ESP_OT_MESH, channel 15, PAN 0xABCD, RLOC16 0x6C00, EUI-64 74:4D:BD:FF:FE:61:F3:97
  Network name/Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Link (pengirim -> penerima)  kirim  terima    loss   TX->RX ms rata2 (min..max)   jeda terpanjang
--------------------------------------------------------------------------------------------------
Node1 -> Node2                  10      10     0.0%       13 (0..21)                  5.0 s
Node1 -> Node3                  11      11     0.0%       13 (0..22)                  5.0 s
Node2 -> Node1                  10      10     0.0%       11 (-0..16)                 5.0 s
Node2 -> Node3                  10      10     0.0%       54 (16..89)                 5.1 s
Node3 -> Node1                  10      10     0.0%       14 (8..15)                  5.0 s
Node3 -> Node2                  10      10     0.0%       18 (9..56)                  5.0 s

Jeda terpanjang = selang terlama antara dua pesan yang diterima dari pengirim itu (normal ~5 s);
selisih TX->RX memakai timestamp PC (kasar).
```

## Catatan

- **Info network cocok di ketiga node**: network name, channel, PAN ID, dan
  Extended PAN ID sama (dari dataset yang ditulis kode).
- **Peran dipilih jaringan, bukan kode.** Node3 attach paling dulu (7,2 s) dan
  menjadi **Leader**; Node1 menjadi **Router**; Node2 menjadi **Child**.
- **RLOC16 memperlihatkan topologi.** Leader `0x6C00` = Router ID 27;
  Node1 `0x1C00` = Router ID 7; Node2 `0x1C01` = Router ID 7 + Child ID 1,
  artinya **parent Node2 adalah Node1**, bukan Leader.
- Selisih TX → RX paling besar pada link Node2 → Node3 (rata-rata 54 ms,
  lainnya 11–18 ms), sesuai dengan pesan Child yang harus lewat parent-nya.
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
- Semua link **0 % loss** selama rekaman, jeda terpanjang ±5 s (sesuai interval
  kirim 5 s).
- `E (…) OT_STATE: … Failed to get the active dataset` di Node2 adalah
  peringatan non-fatal saat transisi role, tidak mengganggu komunikasi.
- Selisih waktu memakai timestamp PC, jadi kasar (resolusi USB-serial).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
