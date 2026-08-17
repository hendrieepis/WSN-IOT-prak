# Log Serial — Week 01 (BLE Point-to-Point)

Hasil aktual dari board nyata (bukan contoh). Baud 115200, dua board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial |
|---|---|---|---|
| Node1 | BLE Peripheral (advertise) | `NODE1_H2` | `/dev/ttyACM0` |
| Node2 | BLE Central (scan + connect) | `NODE2_H2` | `/dev/ttyACM1` |

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
Node1 (BLE Peripheral) starting...
Advertise sebagai NODE1_H2, menunggu Node2...
Node2 terhubung (link P2P aktif)
Status: H2 <-> H2 terhubung
Status: H2 <-> H2 terhubung
Status: H2 <-> H2 terhubung
```

## Node2 — `/dev/ttyACM1`

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
Node2 (BLE Central) starting...
Scanning Node1...
Node1 ditemukan
Terhubung ke Node1
Koneksi berhasil
Status: H2 <-> H2 terhubung
Status: H2 <-> H2 terhubung
Status: H2 <-> H2 terhubung
```

## Urutan kejadian

1. Node1 boot → advertise `NODE1_H2` + Service UUID.
2. Node2 boot → active scan 5 detik.
3. Node2 menemukan `NODE1_H2` → `Node1 ditemukan`.
4. Node2 connect → Node1 cetak `Node2 terhubung (link P2P aktif)`, Node2 cetak `Terhubung ke Node1`.
5. Service UUID `4fafc201-…` diverifikasi → Node2 cetak `Koneksi berhasil`.
6. Kedua node mencetak heartbeat `Status: H2 <-> H2 terhubung` tiap 5 detik.

Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot ESP32-H2 (keluar sekali
saat reset), bukan bagian dari program aplikasi.
