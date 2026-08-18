# Log Serial — Week 05B (Mini Project: Smart Sensor Jendela & Pintu)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial |
|---|---|---|---|
| Hub | BLE Central (scan + subscribe ke 2 sensor) | `HUB_RUMAH` | `/dev/ttyACM4` |
| Sensor jendela | BLE Peripheral, event-driven | `SENSOR_JENDELA1` | `/dev/ttyACM0` |
| Sensor pintu | BLE Peripheral, event-driven | `SENSOR_PINTU1` | `/dev/ttyACM2` |

## Hub — `/dev/ttyACM4`, setelah reset

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
Hub Smart Home (BLE central) starting...
Mencari smart sensor jendela dan pintu...
Jendela 1 ditemukan (RSSI -30 dBm)
Pintu 1 ditemukan (RSSI -29 dBm)
Jendela 1 terhubung
Pintu 1 terhubung
Semua sensor terpantau — sistem siaga
```

Jarak antar-board saat pengambilan log ±20 cm (RSSI −29…−30 dBm).

## EXP-02 — Kejadian sensor jendela, dilihat dari dua sisi

Dua kali "tekan-lepas" pada node jendela. Baris `[NODEA]` diambil dari
`/dev/ttyACM0`, baris `[HUB  ]` dari `/dev/ttyACM4`, direkam bersamaan.

```
--- tekan tombol ke-1 ---
[NODEA] Notify: JENDELA1:OPEN:1
[HUB  ] [ALARM] [ 43.851 s] Jendela 1 TERBUKA (event #1)
[NODEA] Notify: JENDELA1:CLOSED:2
[HUB  ] [INFO ] [ 45.051 s] Jendela 1 tertutup kembali (event #2)
--- tekan tombol ke-2 ---
[NODEA] Notify: JENDELA1:OPEN:3
[HUB  ] [ALARM] [ 46.601 s] Jendela 1 TERBUKA (event #3)
[NODEA] Notify: JENDELA1:CLOSED:4
[HUB  ] [INFO ] [ 47.801 s] Jendela 1 tertutup kembali (event #4)
```

## EXP-02 — Kejadian sensor pintu (tombol ditahan 2 detik)

```
[NODEB] Notify: PINTU1:OPEN:3
[HUB  ] [ALARM] [ 59.062 s] Pintu 1 TERBUKA (event #3)
[NODEB] Notify: PINTU1:CLOSED:4
[HUB  ] [INFO ] [ 61.112 s] Pintu 1 tertutup kembali (event #4)
```

Selisih `OPEN` → `CLOSED` di hub = 61,112 − 59,062 = **2,05 s**, cocok dengan
lama tombol ditahan (2,0 s). Label tidak tertukar: node pintu → `Pintu 1`.

## EXP-03 — Sambung ulang otomatis

Node jendela ditahan mati 17 detik (EN ditahan LOW), lalu dihidupkan lagi.
Selagi hub sibuk mencoba menyambung ulang, tombol pada node **pintu** ditekan
untuk memastikan alarmnya tetap jalan.

```
[   4.41] Semua sensor terpantau — sistem siaga
--- node jendela dimatikan ---
[   9.58] [WARN ] Jendela 1 terputus (reason 520) — mencoba sambung ulang
[  16.65] Gagal terhubung ke Jendela 1
[  20.76] Gagal terhubung ke Jendela 1
[  26.07] Gagal terhubung ke Jendela 1
[  26.07] Jendela 1 tidak menjawab 3 kali — scan ulang
--- tombol node pintu ditekan selagi hub sibuk retry ---
[  32.24] [ALARM] [ 31.947 s] Pintu 1 TERBUKA (event #1)
[  33.70] [INFO ] [ 33.447 s] Pintu 1 tertutup kembali (event #2)
--- node jendela dihidupkan lagi ---
[  36.96] Jendela 1 ditemukan (RSSI -27 dBm)
[  37.27] Jendela 1 terhubung
[  37.87] [PULIH] Jendela 1 tersambung lagi setelah 28.3 s
[  37.87] Semua sensor terpantau — sistem siaga
```

Percobaan lain dengan sensor hanya mati sebentar (4 detik) pulih lewat jalur
cepat, tanpa perlu scan ulang:

```
[  10.63] [WARN ] Pintu 1 terputus (reason 520) — mencoba sambung ulang
[  14.64] Pintu 1 terhubung
[  15.24] [PULIH] Pintu 1 tersambung lagi setelah 4.6 s
```

| Parameter | Hasil |
|---|---|
| Pemulihan sensor mati singkat (< 5 s) | 4,6 s, tanpa scan ulang |
| Pemulihan sensor mati lama (17 s) | 28,3 s, lewat 3× gagal → scan ulang |
| Alarm sensor lain selama pemulihan | ✅ tetap tiba (`Pintu 1 TERBUKA`) |
| Perlu reset hub? | tidak |
| `reason` disconnect yang teramati | 520 (BLE_HS_ETIMEOUT_HCI — supervision timeout) |

Catatan: dengan `CONNECT_TIMEOUT_MS` bawaan library (30 detik), tiga baris
`Gagal terhubung` di atas tidak akan pernah muncul — satu percobaan saja sudah
menahan `loop()` 30 detik, sehingga jalur scan ulang praktis tak terpakai.
Nilai 4 detik dipilih agar logika retry benar-benar berputar.

## Hasil terukur

| Parameter | Hasil |
|---|---|
| Waktu scan → dua koneksi aktif | < 1 s (RSSI −29…−30 dBm, jarak ±20 cm) |
| Kejadian dikirim / diterima hub | 8 / 8 (0 % hilang) |
| Baris `[LOSS ]` | tidak pernah muncul |
| Nomor event berurutan di hub | ya (1, 2, 3, 4 …) |
| Durasi bukaan terjaga? | ya — 2,0 s ditahan → 2,05 s di hub |

## Catatan pengambilan log

- Penekanan tombol disimulasikan dari host dengan menarik **DTR** turun.
  Pada rangkaian *auto program* board, DTR terhubung ke **IO9** — pin yang
  sama dengan tombol BOOT — sehingga efeknya identik dengan menekan tombol.
  Saat praktikum, tombol ditekan langsung dengan jari.
- Nomor event sensor pintu mulai dari 3 karena dua kejadian pertama terpicu
  oleh transisi DTR saat port dibuka, sebelum perekaman dimulai. Ini efek
  samping metode simulasi di atas, bukan perilaku firmware.
- Kedipan LED RGB (GPIO8) tidak terekam di log serial — verifikasi bagian itu
  secara visual di board.
