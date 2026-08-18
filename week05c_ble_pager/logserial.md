# Log Serial — Week 05C (Pager Restoran, BLE One-to-Many)

Hasil aktual dari board nyata. Baud 115200, empat board ESP32-H2.

## Board & Port

| Node | Peran | Identitas radio | Port serial |
|---|---|---|---|
| Kasir | BLE Central, maksimum 2 koneksi serentak | `ORDER_CONTROLLER` | `/dev/ttyACM0` |
| Pager 101 | BLE Peripheral | `PAGER_101` | `/dev/ttyACM2` |
| Pager 102 | BLE Peripheral | `PAGER_102` | `/dev/ttyACM4` |
| Pager 103 | BLE Peripheral | `PAGER_103` | `/dev/ttyACM6` |

Keempat aliran serial direkam bersamaan, sehingga stempel waktunya berasal dari satu sumbu yang sama.

## Temuan yang mengubah rancangan: batas dua koneksi

Rancangan pertama memelihara koneksi ke ketiga pager sekaligus, seperti M05 dan M05B. Hasilnya controller **reboot berulang** tepat saat koneksi ketiga terbentuk:

```
[  0.64] KASIR| Pager #101 terhubung
[  1.81] KASIR| Pager #103 terhubung
[  2.66] KASIR| Pager #102 ditemukan (RSSI -30 dBm)
[  2.66] KASIR| assertion:callout
[  2.66] KASIR| line:654,function:npl_freertos_callout_init
[  2.74] KASIR| assert failed: npl_freertos_callout_init npl_os_freertos.c:654 (0)
...
[  3.14] KASIR| Rebooting...
[  3.50] KASIR| Order Controller (kasir) starting...
[  3.90] KASIR| Pager #102 terhubung
[  5.59] KASIR| Pager #101 terhubung
[  6.44] KASIR| assertion:callout          <-- selalu pada koneksi ketiga
```

Urutan pagernya berbeda-beda tiap boot, tetapi kegagalannya selalu jatuh pada koneksi **ketiga** — jadi bukan soal pager tertentu.

Penyebabnya ada di konfigurasi controller BLE ESP32-H2 pada Arduino core ini:

```
$ grep CONN /home/…/framework-arduinoespressif32-libs/esp32h2/sdkconfig
CONFIG_BT_NIMBLE_MAX_CONNECTIONS=3
CONFIG_BT_LE_CONN_RESERVED_MEMORY_COUNT=2      <-- batas sesungguhnya
```

Host NimBLE mengizinkan 3, tetapi memori yang dicadangkan controller hanya untuk 2. Penambahan `-DCONFIG_BT_LE_MAX_CONNECTIONS=3` dan `-DCONFIG_BT_LE_CONN_RESERVED_MEMORY_COUNT=3` pada `build_flags` **sudah dicoba dan tidak berpengaruh** — assert berasal dari pustaka controller yang sudah terkompilasi, di luar jangkauan build flag.

Rancangan lalu diubah: alamat seluruh pager disimpan hasil pemindaian, koneksi dibuka hanya saat memanggil dan ditutup setelah ACK.

## EXP-02 & EXP-03 — Panggilan terarah, ACK, dan pelepasan slot

```
[  0.32] KASIR| Mencari pager...
[  0.32] KASIR| Pager #101 ditemukan (RSSI -16 dBm)
[  0.32] KASIR| Pager #102 ditemukan (RSSI -26 dBm)
[  0.40] KASIR| Pager #103 ditemukan (RSSI -32 dBm)
[  0.40] KASIR| Seluruh 3 pager terdaftar — kasir siap menerima perintah
[  0.40] KASIR| Perintah: READY <id> | CANCEL <id> | LIST | HELP  (maksimum 2 panggilan berjalan bersamaan)
--- kasir mengetik "READY 102" ---
[ 10.22] P102 | Controller terhubung
[ 10.30] KASIR| Pager #102 terhubung
[ 11.18] P102 | [PANGGIL] Pesanan siap — menunggu tombol ACK
[ 11.22] KASIR| [KIRIM] READY -> pager #102 saja (pager lain tidak menerima apa pun)
--- pelanggan pager 102 menekan tombol ACK ---
[ 14.12] P102 | [ACK    ] Pelanggan menekan tombol setelah 2.9 s
[ 14.16] KASIR| [ACK  ] Pager #102 diambil pelanggan — 2.9 s menurut pager, 3.0 s menurut kasir
[ 14.16] KASIR| [LEPAS] Koneksi pager #102 ditutup — slot koneksi kembali bebas
[ 14.28] P102 | Controller terputus, advertise ulang
```

Selama seluruh rentang di atas, Serial pager #101 dan #103 **tidak bertambah satu baris pun** (terhitung otomatis: `P101=0 P103=0`). Inilah bukti langsung bahwa perintah tidak tersiar — pager lain tidak menyaring pesan, melainkan memang tidak menerimanya.

## EXP-04 — Dua panggilan bersamaan dan penolakan yang ketiga

```
[ 17.78] KASIR| Pager #101 terhubung
[ 18.66] P101 | [PANGGIL] Pesanan siap — menunggu tombol ACK
[ 23.44] KASIR| Pager #103 terhubung
[ 24.29] P103 | [PANGGIL] Pesanan siap — menunggu tombol ACK
[ 24.33] KASIR| --- Status pager (2/2 slot koneksi terpakai) ---
[ 24.33] KASIR|   #101 : MEMANGGIL      (6 s berjalan)
[ 24.33] KASIR|   #102 : terdaftar
[ 24.33] KASIR|   #103 : MEMANGGIL      (0 s berjalan)
--- panggilan ketiga ---
[ 25.53] KASIR| [GAGAL] Slot koneksi penuh (2/2). Tunggu ACK panggilan berjalan atau CANCEL salah satunya.
--- kedua pelanggan menekan ACK ---
[ 28.59] KASIR| [ACK  ] Pager #101 diambil pelanggan — 9.9 s menurut pager, 9.9 s menurut kasir
[ 28.63] KASIR| [LEPAS] Koneksi pager #101 ditutup — slot koneksi kembali bebas
[ 31.04] KASIR| [ACK  ] Pager #103 diambil pelanggan — 6.7 s menurut pager, 6.7 s menurut kasir
[ 31.04] KASIR| [LEPAS] Koneksi pager #103 ditutup — slot koneksi kembali bebas
[ 34.37] KASIR| --- Status pager (0/2 slot koneksi terpakai) ---
[ 34.37] KASIR|   #101 : terdaftar
[ 34.37] KASIR|   #102 : terdaftar
[ 34.37] KASIR|   #103 : terdaftar
```

Perbedaan penting dengan rancangan pertama: batas yang sama tetap ada, tetapi kini **ditolak dengan pesan** alih-alih membuat controller reboot.

## Pembatalan panggilan

```
[ 12.78] KASIR| Pager #102 terhubung
[ 13.62] P102 | [PANGGIL] Pesanan siap — menunggu tombol ACK
[ 14.55] P102 | [BATAL  ] Panggilan dibatalkan kasir
[ 14.59] KASIR| [KIRIM] CANCEL -> pager #102 saja (pager lain tidak menerima apa pun)
[ 14.59] KASIR| [LEPAS] Koneksi pager #102 ditutup — slot koneksi kembali bebas
```

## Hasil terukur

| Parameter | Hasil |
|---|---|
| Pindai → tiga pager terdaftar | 0,4 s |
| `READY` → koneksi terbentuk | ± 0,9 s |
| `READY` → pager berbunyi | ± 1,0 s |
| Baris baru pada pager yang tidak dipanggil | 0 |
| Waktu tanggap: versi pager vs versi kasir | selisih ≤ 0,1 s pada 4 pengukuran (2,9/3,0 · 9,9/9,9 · 6,7/6,7 · 1,9/1,9) |
| Panggilan serentak maksimum | 2 (yang ketiga ditolak dengan pesan) |
| Build | controller Flash 53,0% RAM 6,6%; pager Flash 55,3% RAM 6,8% |

## Cacat yang ditemukan dan diperbaiki lewat pengujian ini

| Gejala | Sebab | Perbaikan |
|---|---|---|
| Controller reboot pada koneksi ketiga | Controller BLE ESP32-H2 hanya mencadangkan memori untuk 2 koneksi | Koneksi dibuka saat memanggil, ditutup setelah ACK; panggilan ketiga ditolak |
| `[PULIH]` muncul pada koneksi pertama | Pemulihan tidak dibedakan dari koneksi awal | Pesan hanya muncul bila koneksi benar-benar sempat putus |
| `E (Tone.cpp) noTone(): Tone is not running on given pin 10` | `noTone()` dipanggil saat buzzer sedang di fase diam | Status buzzer dilacak `buzzerAktif`, `noTone()` hanya saat sedang berbunyi |

## Catatan pengambilan log

- Penekanan tombol ACK disimulasikan dari host dengan menarik **DTR** turun. Pada rangkaian *auto program* board, DTR terhubung ke **IO9** — pin yang sama dengan tombol BOOT — sehingga efeknya identik dengan menekan tombol. Saat praktikum, tombol ditekan langsung dengan jari.
- **Buzzer belum diverifikasi secara akustik.** Tidak ada buzzer yang terpasang saat pengujian; yang terbukti adalah jalur perintah, LED, tombol ACK, pelepasan slot, dan pelaporan status. Pemanggilan `tone()`/`noTone()` pada GPIO10 berjalan tanpa galat, tetapi bunyinya perlu diverifikasi sendiri saat buzzer dipasang.
