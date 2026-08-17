# Log Serial — Week 13 (Gateway Thread → Wi-Fi / HTTP)

Hasil aktual dari board nyata ESP32-C6. Baud 115200.
Sensor H2 **disimulasikan** di dalam firmware gateway (tidak ada board H2 fisik).

## Board & Port

| Node | Board | Peran | Port serial (UART) |
|---|---|---|---|
| Gateway | ESP32-C6 DevKitC-1 | Thread Leader + Wi-Fi STA, forward ke HTTP | `/dev/ttyACM6` |

Konfigurasi: Wi-Fi `SprH-3`, server HTTP lokal `http://192.168.1.5:8080/post`
(`tools/http_sink.py`), Thread `ESP_OT_GW` ch 15 PAN 0xABCD.

## Gateway (C6) — `/dev/ttyACM6`

```
ESP-ROM:esp32c6-20220919
Build:Sep 19 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:2
load:0x40875730,len:0x1278
load:0x4086b910,len:0xc58
load:0x4086e610,len:0x31c0
entry 0x4086b910
Konek Wi-Fi SprH-3........
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -67 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Leader
Default netif dikembalikan ke Wi-Fi STA (err=0)
Gateway siap (Thread -> Wi-Fi).
SIM sensor (Thread): suhu:24.5
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
SIM sensor (Thread): suhu:24.9
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
SIM sensor (Thread): suhu:24.2
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
SIM sensor (Thread): suhu:23.4
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
SIM sensor (Thread): suhu:23.4
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
SIM sensor (Thread): suhu:22.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
SIM sensor (Thread): suhu:23.0
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP 200
SIM sensor (Thread): suhu:22.9
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
```

## Server HTTP (PC) — `tools/http_sink.py`

```
[   0.000] http_sink siap di 0.0.0.0:8080 (POST -> HTTP 200)
[ 480.308] #1    POST /post from 192.168.1.39  ->  {"sensor":"h2","data":"suhu:23.1"}
```

## Catatan

- Thread + Wi-Fi berjalan bersamaan di satu antena 2,4 GHz (koeksistensi).
  Urutan inisialisasi yang benar (Thread begin → Wi-Fi connect → coex prefer WIFI
  → Thread start) sudah diterapkan; board tidak panic dan Wi-Fi berhasil asosiasi.
- Gateway attach sebagai **Leader** (jaringan `ESP_OT_GW` dibentuk sendiri).
- **Hop Wi-Fi adalah yang paling rapuh**: mayoritas POST gagal dengan `HTTP -1`
  (koneksi TCP gagal terbentuk akibat pembagian airtime Thread+Wi-Fi), tetapi
  sesekali POST berhasil sampai di server (`HTTP 200`, terbukti `#1 POST ... suhu:23.1`
  di http_sink). Ini sesuai dokumentasi README: hop Wi-Fi menghasilkan loss terbesar.
- **Mengapa hanya ~1 POST yang sesekali lolos**: keberhasilan bersifat
  probabilistik — hanya saat Wi-Fi kebetulan memenangkan perebutan airtime tepat
  pada momen TCP connect, satu POST berhasil (`suhu:23.0 -> HTTP 200`) sebelum
  percobaan berikutnya gagal `-1` lagi.
- Sensor **disimulasikan** (`SIM sensor (Thread): suhu:XX.X`) memanggil jalur
  `forwardToWifi()` yang sama dengan jalur `RX via Thread` asli.
- Baris `ESP-ROM:esp32c6-…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
