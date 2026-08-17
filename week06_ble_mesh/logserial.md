# Log Serial — Week 06 (BLE Mesh Relay / Hop)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2.
Topologi: A → B → C (B sebagai relay).

## Board & Port

| Node | Peran | Identitas radio | Port serial (UART) |
|---|---|---|---|
| NodeA | Sumber pesan (server) | `MESH_NODE_A` | `/dev/ttyACM0` |
| NodeB | Relay (client ke A + server ke C) | `MESH_NODE_B` | `/dev/ttyACM2` |
| NodeC | Penerima akhir (client ke B) | `MESH_NODE_C` | `/dev/ttyACM4` |

## NodeA — `/dev/ttyACM0`

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
Node A (sumber pesan) starting...
Menunggu relay (Node B)...
Node B terhubung
Kirim ke B: A:1
Kirim ke B: A:2
Kirim ke B: A:3
Kirim ke B: A:4
Kirim ke B: A:5
```

## NodeB — `/dev/ttyACM2`

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
Node B (relay) starting...
Menunggu A dan C...
Node A ditemukan
Node C terhubung
Terhubung ke Node A
Koneksi ke A berhasil
Terima dari A: A:1 (diteruskan)
Teruskan ke C: A:1
Terima dari A: A:2 (diteruskan)
Teruskan ke C: A:2
Terima dari A: A:3 (diteruskan)
Teruskan ke C: A:3
Terima dari A: A:4 (diteruskan)
Teruskan ke C: A:4
Terima dari A: A:5 (diteruskan)
Teruskan ke C: A:5
```

## NodeC — `/dev/ttyACM4`

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
Node C (penerima akhir) starting...
Scanning Node B...
Node B ditemukan
Terhubung ke Node B
Koneksi ke B berhasil
Pesan tiba (via A -> B -> C): A:1
Pesan tiba (via A -> B -> C): A:2
Pesan tiba (via A -> B -> C): A:3
Pesan tiba (via A -> B -> C): A:4
Pesan tiba (via A -> B -> C): A:5
```

## Catatan

- NodeA mengirim `A:<n>` tiap 4 detik ke NodeB (notify).
- NodeB menerima dari A (`Terima dari A`), lalu meneruskannya apa adanya ke NodeC
  (`Teruskan ke C`) — payload tidak diubah (*transparent forwarding*).
- NodeC menerima pesan hasil dua hop dan mencetak `Pesan tiba (via A -> B -> C)`.
- NodeB berperan ganda: client ke A sekaligus server untuk C, sehingga `Node C
  terhubung` bisa muncul sebelum `Terhubung ke Node A` (dua peran berjalan paralel).
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
