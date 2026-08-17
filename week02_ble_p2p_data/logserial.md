# Log Serial — Week 02 (BLE P2P Data)

Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial (UART) |
|---|---|---|---|
| Node1 | BLE Server (notify + write) | `NODE1_H2` | `/dev/ttyACM0` |
| Node2 | BLE Client (scan + subscribe) | `NODE2_H2` | `/dev/ttyACM2` |

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
Node1 (BLE Server) starting...
Menunggu koneksi dari Node2...
Client terhubung
TX ke Node2: Hello dari Node1 (2005)
RX dari Node2: Halo dari Node2 (3001)
TX ke Node2: Hello dari Node1 (4006)
TX ke Node2: Hello dari Node1 (6007)
RX dari Node2: Halo dari Node2 (6002)
TX ke Node2: Hello dari Node1 (8008)
RX dari Node2: Halo dari Node2 (9003)
TX ke Node2: Hello dari Node1 (10009)
TX ke Node2: Hello dari Node1 (12010)
RX dari Node2: Halo dari Node2 (12004)
TX ke Node2: Hello dari Node1 (14011)
RX dari Node2: Halo dari Node2 (15005)
TX ke Node2: Hello dari Node1 (16012)
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
Node2 (BLE Client) starting...
Scanning Node1...
Node1 ditemukan
Terhubung ke Node1
Koneksi berhasil
RX dari Node1: Hello dari Node1 (2005)
RX dari Node1: Halo dari Node2 (3001)
TX ke Node1: Halo dari Node2 (3001)
RX dari Node1: Hello dari Node1 (4006)
RX dari Node1: Hello dari Node1 (6007)
RX dari Node1: Halo dari Node2 (6002)
TX ke Node1: Halo dari Node2 (6002)
RX dari Node1: Hello dari Node1 (8008)
RX dari Node1: Halo dari Node2 (9003)
TX ke Node1: Halo dari Node2 (9003)
RX dari Node1: Hello dari Node1 (10009)
RX dari Node1: Hello dari Node1 (12010)
RX dari Node1: Halo dari Node2 (12004)
TX ke Node1: Halo dari Node2 (12004)
RX dari Node1: Hello dari Node1 (14011)
RX dari Node1: Halo dari Node2 (15005)
TX ke Node1: Halo dari Node2 (15005)
RX dari Node1: Hello dari Node1 (16012)
```

## Catatan

- Node1 mengirim `Hello dari Node1 (ms)` tiap 2 detik via notify (CHAR_TX).
- Node2 mengirim `Halo dari Node2 (ms)` tiap 3 detik via write (CHAR_RX).
- Pesan dari Node2 diterima Node1 (`RX dari Node2`), lalu digemakan balik lewat notify
  sehingga Node2 melihatnya lagi sebagai `RX dari Node1: Halo dari Node2 (...)`.
- Angka dalam kurung adalah nilai `millis()` saat pesan dibuat (bukan counter urut).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
