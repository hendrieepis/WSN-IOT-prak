# Log Serial — Week 05 (BLE Multi-Node)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial (UART) |
|---|---|---|---|
| Central | BLE Client (hub, scan + subscribe ke 2 node) | `MULTI_CENTRAL` | `/dev/ttyACM0` |
| NodeA | BLE Server, notify tiap 2 detik | `MULTI_NODE_A` | `/dev/ttyACM2` |
| NodeB | BLE Server, notify tiap 3 detik | `MULTI_NODE_B` | `/dev/ttyACM4` |

## Central — `/dev/ttyACM0`

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
Central (multi-node) starting...
Scanning node A dan B...
Node A ditemukan
Node B ditemukan
NodeA terhubung
NodeB terhubung
Koneksi ke kedua node selesai
[NodeA] RX: A:1
[NodeB] RX: B:1
[NodeA] RX: A:2
[NodeB] RX: B:2
[NodeA] RX: A:3
[NodeA] RX: A:4
[NodeB] RX: B:3
[NodeA] RX: A:5
[NodeA] RX: A:6
[NodeB] RX: B:4
[NodeA] RX: A:7
[NodeB] RX: B:5
[NodeA] RX: A:8
[NodeA] RX: A:9
[NodeB] RX: B:6
```

## NodeA — `/dev/ttyACM2`

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
Node A (peripheral) starting...
Menunggu central...
Central terhubung
Notify: A:1
Notify: A:2
Notify: A:3
Notify: A:4
Notify: A:5
Notify: A:6
Notify: A:7
Notify: A:8
Notify: A:9
```

## NodeB — `/dev/ttyACM4`

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
Node B (peripheral) starting...
Menunggu central...
Central terhubung
Notify: B:1
Notify: B:2
Notify: B:3
Notify: B:4
Notify: B:5
Notify: B:6
```

## Catatan

- Central melakukan satu sesi scan 5 detik untuk mengumpulkan alamat A dan B,
  lalu terhubung + subscribe ke keduanya.
- NodeA mengirim `A:<n>` tiap 2 detik, NodeB mengirim `B:<n>` tiap 3 detik;
  identitas sumber dikodekan pada payload (`A:` / `B:`).
- Di log Central, urutan `[NodeA]` / `[NodeB]` sesuai urutan kedatangan notify,
  tidak selalu selang-seling karena interval keduanya berbeda.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
