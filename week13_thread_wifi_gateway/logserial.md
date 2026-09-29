# Log Serial — Week 13 (Gateway Thread → Wi-Fi / HTTP)

Hasil aktual dari board nyata. Baud 115200, gateway **ESP32-C6 DevKitC-1** dan
node sensor **ESP32-H2 DevKitM-1**, firmware versi terbaru: setelah attach,
kedua board mencetak info network Thread (peran, network name, channel, PAN
ID, Extended PAN ID, RLOC16, Extended Address, EUI-64, Mesh-Local EID), dan
gateway juga mencetak info Wi-Fi (SSID, IP, RSSI, channel, BSSID, MAC). Log
direkam 90 detik dengan `monitor_serial.py` (kedua port dalam satu komputer,
satu sumbu waktu) lewat port UART CH343 di Windows.

Kedua board di-`erase` lalu di-flash; monitor me-reset keduanya saat port
dibuka. Board H2 lain yang masih tercolok di-`erase` agar tidak ikut
bergabung (firmware M12 memakai channel, PAN ID, dan network key yang sama).
`SERVER_URL` firmware menunjuk `http://192.168.1.5:8080/post`, sedangkan
`http_sink.py` **tidak** dijalankan — rekaman ini sengaja memperlihatkan
perilaku gateway saat server tidak terjangkau.

## Board & Port

| Node | Board | Peran (terpilih) | RLOC16 | EUI-64 (pabrik) | Port serial (UART) |
|---|---|---|---|---|---|
| Gateway | ESP32-C6 DevKitC-1 | Child + Wi-Fi STA, forward ke HTTP | `0x6C01` | `40:4C:CA:FF:FE:5E:C5:40` | `COM9` |
| SensorH2 | ESP32-H2 DevKitM-1 | **Leader**, kirim telemetri tiap 3 s | `0x6C00` | `74:4D:BD:FF:FE:61:E6:2C` | `COM5` |

Thread `ESP_OT_GW`, channel **15**, PAN ID **`0xABCD`**, Extended PAN ID
**`DE:AD:00:BE:EF:00:CA:FE`** — sama di kedua board. Wi-Fi gateway: SSID
`SprH-3`, channel **8**, IP `192.168.1.109`, RSSI −63 dBm.

## Gateway (C6) — COM9

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
Konek Wi-Fi SprH-3......
Wi-Fi OK, IP: 192.168.1.109 | RSSI: -63 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Child
Default netif dikembalikan ke Wi-Fi STA (err=0)
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_GW
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C01
  Extended addr  : BE:21:63:FE:AC:75:5F:60
  EUI-64         : 40:4C:CA:FF:FE:5E:C5:40
  Mesh-Local EID : fdde:ad00:beef:0:15c:9037:1e71:3135
Info network Wi-Fi:
  SSID           : SprH-3
  IP             : 192.168.1.109
  RSSI           : -64 dBm
  Channel Wi-Fi  : 8
  BSSID (AP)     : 24:C0:13:CB:4B:27
  MAC            : 40:4C:CA:5E:C5:40
Gateway siap (Thread -> Wi-Fi).
SIM sensor (Thread): suhu:25.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.0
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.6
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.4
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:23.4
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:21.6
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:22.3
```

## SensorH2 — COM5

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
Sensor H2 (Thread node) starting...
Menunggu join ke gateway (C6)...
Attached as: Leader
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_GW
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C00
  Extended addr  : D6:48:6C:1E:E0:BC:16:6B
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:7c1b:2b3:3487:1195
TX via Thread: suhu:24.4
TX via Thread: suhu:25.0
TX via Thread: suhu:24.3
TX via Thread: suhu:24.8
TX via Thread: suhu:24.0
TX via Thread: suhu:24.2
TX via Thread: suhu:24.5
TX via Thread: suhu:24.8
TX via Thread: suhu:23.8
TX via Thread: suhu:24.5
TX via Thread: suhu:24.6
TX via Thread: suhu:25.0
TX via Thread: suhu:24.4
TX via Thread: suhu:23.4
TX via Thread: suhu:24.2
TX via Thread: suhu:23.4
TX via Thread: suhu:23.5
TX via Thread: suhu:22.5
TX via Thread: suhu:21.6
TX via Thread: suhu:21.9
TX via Thread: suhu:22.3
TX via Thread: suhu:22.1
TX via Thread: suhu:21.4
TX via Thread: suhu:21.8
TX via Thread: suhu:21.5
```

## Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)

```
[   0.750] SensorH2 | Sensor H2 (Thread node) starting...
[   0.750] SensorH2 | Menunggu join ke gateway (C6)...
[   3.849] Gateway  | Konek Wi-Fi SprH-3......
[   3.849] Gateway  | Wi-Fi OK, IP: 192.168.1.109 | RSSI: -63 dBm
[   3.849] Gateway  | coex preference = WIFI (err=0)
[   3.849] Gateway  | Menunggu attach Thread...
[  15.556] SensorH2 | Attached as: Leader
[  15.556] SensorH2 | Info network Thread:
[  15.556] SensorH2 |   Peran          : Leader
[  15.556] SensorH2 |   Network name   : ESP_OT_GW
[  15.556] SensorH2 |   Channel        : 15
[  15.556] SensorH2 |   PAN ID         : 0xABCD
[  15.556] SensorH2 |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  15.556] SensorH2 |   RLOC16         : 0x6C00
[  15.769] SensorH2 |   Extended addr  : D6:48:6C:1E:E0:BC:16:6B
[  15.769] SensorH2 |   EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
[  15.770] SensorH2 |   Mesh-Local EID : fdde:ad00:beef:0:7c1b:2b3:3487:1195
[  15.770] SensorH2 | TX via Thread: suhu:24.4
[  18.772] SensorH2 | TX via Thread: suhu:25.0
[  21.780] SensorH2 | TX via Thread: suhu:24.3
[  22.907] Gateway  | Thread attached as: Child
[  22.907] Gateway  | Default netif dikembalikan ke Wi-Fi STA (err=0)
[  22.907] Gateway  | Info network Thread:
[  22.907] Gateway  |   Peran          : Child
[  22.907] Gateway  |   Network name   : ESP_OT_GW
[  22.907] Gateway  |   Channel        : 15
[  22.907] Gateway  |   PAN ID         : 0xABCD
[  22.908] Gateway  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  22.930] Gateway  |   RLOC16         : 0x6C01
[  22.930] Gateway  |   Extended addr  : BE:21:63:FE:AC:75:5F:60
[  22.930] Gateway  |   EUI-64         : 40:4C:CA:FF:FE:5E:C5:40
[  22.930] Gateway  |   Mesh-Local EID : fdde:ad00:beef:0:15c:9037:1e71:3135
[  22.930] Gateway  | Info network Wi-Fi:
[  22.930] Gateway  |   SSID           : SprH-3
[  22.930] Gateway  |   IP             : 192.168.1.109
[  23.161] Gateway  |   RSSI           : -64 dBm
[  23.161] Gateway  |   Channel Wi-Fi  : 8
[  23.161] Gateway  |   BSSID (AP)     : 24:C0:13:CB:4B:27
[  23.161] Gateway  |   MAC            : 40:4C:CA:5E:C5:40
[  23.161] Gateway  | Gateway siap (Thread -> Wi-Fi).
[  23.161] Gateway  | SIM sensor (Thread): suhu:25.8
[  24.772] SensorH2 | TX via Thread: suhu:24.8
[  27.797] SensorH2 | TX via Thread: suhu:24.0
[  30.810] SensorH2 | TX via Thread: suhu:24.2
[  31.146] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  31.146] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
[  33.814] SensorH2 | TX via Thread: suhu:24.5
[  36.810] SensorH2 | TX via Thread: suhu:24.8
[  39.158] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  39.158] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.0
[  39.816] SensorH2 | TX via Thread: suhu:23.8
[  42.817] SensorH2 | TX via Thread: suhu:24.5
[  45.806] SensorH2 | TX via Thread: suhu:24.6
[  47.151] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  47.151] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
[  48.834] SensorH2 | TX via Thread: suhu:25.0
[  51.825] SensorH2 | TX via Thread: suhu:24.4
[  54.833] SensorH2 | TX via Thread: suhu:23.4
[  55.168] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  55.169] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.6
[  57.836] SensorH2 | TX via Thread: suhu:24.2
[  60.852] SensorH2 | TX via Thread: suhu:23.4
[  63.167] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  63.167] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.4
[  63.867] SensorH2 | TX via Thread: suhu:23.5
[  66.854] SensorH2 | TX via Thread: suhu:22.5
[  69.862] SensorH2 | TX via Thread: suhu:21.6
[  71.168] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  71.168] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:23.4
[  72.864] SensorH2 | TX via Thread: suhu:21.9
[  75.882] SensorH2 | TX via Thread: suhu:22.3
[  78.884] SensorH2 | TX via Thread: suhu:22.1
[  79.169] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  79.170] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:21.6
[  81.897] SensorH2 | TX via Thread: suhu:21.4
[  84.881] SensorH2 | TX via Thread: suhu:21.8
[  87.167] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  87.168] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:22.3
[  87.894] SensorH2 | TX via Thread: suhu:21.5
```

## Ringkasan `monitor_serial.py`

```
Durasi: 90.2 s
  Gateway  Child   COM9             50 baris, boot 1x, attach Thread 22.54 s sejak boot
           Wi-Fi: IP 192.168.1.109, 3.5 s sejak boot, RSSI -63 dBm
           Wi-Fi channel 8, SSID SprH-3, MAC 40:4C:CA:5E:C5:40
           Thread ESP_OT_GW, channel 15, PAN 0xABCD, RLOC16 0x6C01, EUI-64 40:4C:CA:FF:FE:5E:C5:40
  SensorH2 Leader  COM5             47 baris, boot 1x, attach Thread 15.19 s sejak boot
           Thread ESP_OT_GW, channel 15, PAN 0xABCD, RLOC16 0x6C00, EUI-64 74:4D:BD:FF:FE:61:E6:2C
  Network name/Channel/PAN ID/Extended PAN ID Thread: sama (satu network)

Hop                                   dikirim  diterima    loss
----------------------------------------------------------------
Thread  (H2 TX -> C6 RX)                   22         8    63.6%
Wi-Fi   (C6 -> server, telemetri)           7         0   100.0%
Wi-Fi   (C6 -> server, SIM sensor)          1         0   100.0%
End-to-end (H2 TX -> HTTP 2xx)             22         0   100.0%

Kode HTTP: -1: 8x
Lama POST: rata2 8.00 s (7.99..8.02) — dari baris sumber sampai baris Forward, timestamp PC
Telemetri H2 yang tidak sampai ke gateway: suhu:24.2 @ 30.8 s, suhu:24.5 @ 33.8 s, suhu:23.8 @ 39.8 s, suhu:24.5 @ 42.8 s, suhu:25.0 @ 48.8 s, suhu:23.4 @ 54.8 s, suhu:24.2 @ 57.8 s, suhu:23.5 @ 63.9 s ...

Bandingkan jumlah HTTP 2xx dengan jumlah POST yang tercatat di http_sink.py.
```

## Catatan

- **Info network Thread cocok di kedua board** (network name, channel, PAN ID,
  Extended PAN ID dari dataset yang ditulis kode).
- **Peran dipilih jaringan.** H2 attach lebih dulu (15,2 s) dan menjadi
  **Leader** `0x6C00`; gateway C6 attach 22,5 s sebagai **Child** `0x6C01` —
  Router ID sama, jadi parent gateway adalah H2. Gateway tidak harus Leader.
- **EUI-64 C6 diturunkan dari MAC Wi-Fi-nya**: MAC `40:4C:CA:5E:C5:40` →
  EUI-64 `40:4C:CA:FF:FE:5E:C5:40` (disisipi `FF:FE`). Extended addr Thread
  tetap diacak dan berbeda dari keduanya.
- **Channel Wi-Fi 8 (±2447 MHz) vs Thread channel 15 (2425 MHz)**: frekuensinya
  tidak bertumpuk, tetapi keduanya berbagi satu radio dan satu antena di C6.
- **Loss terbesar ada di aplikasi gateway, bukan radio Thread.** Setiap
  `http.POST()` gagal (`HTTP -1`) setelah ±8 s karena server tidak terjangkau;
  selama itu `loop()` tertahan dan socket UDP tidak dibaca. Hanya satu paket
  yang tertampung per periode, sehingga H2 mengirim 25 telemetri (22 setelah
  gateway siap) tetapi gateway hanya mencetak **8** `RX via Thread`, masing-
  masing tertunda beberapa detik. Semua POST gagal, jadi end-to-end 0 %.
- Untuk rekaman dengan server hidup, jalankan `http_sink.py` dan arahkan
  `SERVER_URL` ke IP laptop di jaringan Wi-Fi yang sama.
- `E (…) OT_STATE: … Failed to get the active dataset` adalah peringatan
  non-fatal saat transisi role.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
