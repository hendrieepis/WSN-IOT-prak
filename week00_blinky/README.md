```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
        MODUL 00A — Blinky ESP32-H2 (Warm-up)

     Waveshare ESP32-H2-DEV-KIT-N4 · Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 00A (warm-up, sebelum M01) |
| Misi | Memastikan toolchain PlatformIO, board, dan jalur flash bekerja sebelum modul komunikasi dimulai |
| Platform | Waveshare ESP32-H2-DEV-KIT-N4 (ESP32-H2-MINI-1, Arduino core 3.x) + PlatformIO |
| Durasi | 1 × 50 menit |
| Mode | Single node — LED RGB onboard berkedip |
| Level | Basic |
| Instrumen | Serial Monitor 115200 baud |

## 2 · Keterkaitan Antar-Modul

Modul ini tidak mengajarkan protokol apa pun. Fungsinya menutup satu sumber kebingungan yang berulang di laboratorium: ketika sebuah modul komunikasi gagal, penyebabnya bisa berada di protokol, di firmware, atau di rantai kerja paling dasar — toolchain, board, kabel, dan port. Dengan menuntaskan modul ini lebih dahulu, kemungkinan terakhir dapat dicoret sejak awal.

| | Cakupan |
|---|---|
| Prasyarat | Dasar bahasa C dan pemasangan PlatformIO Core/IDE |
| Dibangun di modul ini | Struktur proyek PlatformIO, proses build–flash–monitor, kendali LED RGB WS2812 |
| Dipakai lagi di | M00B (input digital), M01–M16 (setiap modul memakai rantai build–flash–monitor yang sama) |

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

1. Menjelaskan posisi ESP32-H2 dalam ekosistem ESP32 (inti RISC-V, radio BLE + IEEE 802.15.4) dan kesetaraan pinout Waveshare ESP32-H2-DEV-KIT-N4 dengan ESP32-H2-DevKitM-1.
2. Membuat proyek PlatformIO menggunakan fork pioarduino, serta menjelaskan alasan platform resmi belum dapat dipakai untuk board ESP32-H2.
3. Melakukan build, flash, dan monitor firmware, serta memverifikasi LED RGB WS2812 pada GPIO8 bekerja sesuai program.
4. Membaca keluaran Serial Monitor sebagai instrumen verifikasi, bukan sekadar catatan tambahan.

**Kriteria keberhasilan**

- ☐ Proses `pio run -t upload` selesai tanpa galat.
- ☐ LED RGB onboard berkedip dengan periode 1 detik.
- ☐ Serial Monitor menampilkan pesan startup tepat satu kali setelah reset.
- ☐ Warna LED berhasil diubah melalui `strip.Color(r, g, b)`.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan.

| Istilah | Definisi kerja di lab ini |
|---|---|
| ESP32-H2 | SoC berinti RISC-V dengan radio BLE 5 dan IEEE 802.15.4, tanpa Wi-Fi. |
| pioarduino | Fork platform espressif32 yang menyediakan definisi board ESP32-H2, yang belum tersedia pada platform resmi PlatformIO. |
| WS2812 | LED RGB beralamat: warna dikirim sebagai deretan bit pada satu jalur data, bukan diatur oleh tegangan pin seperti LED biasa. |
| Urutan byte warna | Urutan pengiriman komponen warna. WS2812 umumnya GRB; pada board ini pengamatan empiris menunjukkan urutan **RGB**, sehingga dipakai `NEO_RGB`. |
| Environment PlatformIO | Konfigurasi build bernama pada `platformio.ini`; dipilih dengan opsi `-e`. |

## 5 · Perangkat & Pin

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | Waveshare ESP32-H2-DEV-KIT-N4 | 1 |
| 2 | Kabel USB-C | kabel data, bukan *charge-only* | 1 |
| 3 | PC/Laptop | PlatformIO Core/IDE terpasang | 1 |

| Fungsi | GPIO | Keterangan (dari skematik board) |
|---|---|---|
| LED RGB WS2812 | GPIO8 | `RGB_CTRL`, satu pixel, urutan byte RGB |

**Struktur proyek**

```
week00_blinky/
├── platformio.ini
└── src/
    └── main.cpp
```

## 6 · Build & Flash

```bash
pio run -d week00_blinky -e node -t upload
pio device monitor -e node
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan dan port board tercatat.
- ☐ Kabel yang dipakai dipastikan kabel data.
- ☐ Environment `node` dikenali PlatformIO.

## 7 · Percobaan

### EXP-01 — Build dan Flash Pertama

Bangun dan unggah firmware, lalu amati LED serta Serial Monitor.

**Expected output**

```
Blinky RGB WS2812 ESP32-H2-DEV-KIT-N4 dimulai
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Port serial yang terdeteksi | |
| Waktu build pertama (s) | |
| Pemakaian Flash / RAM dari ringkasan build | |
| Periode kedip terukur (s) | |

> **CHECKPOINT** — LED berkedip **dan** pesan startup muncul tepat satu kali. Pesan yang muncul berulang menandakan board melakukan reset berkala; hentikan dan periksa catu daya serta kabel sebelum melanjutkan.

### EXP-02 — Warna sebagai Data

Ubah argumen `strip.Color(r, g, b)`, unggah ulang, dan amati perubahannya. Percobaan ini menegaskan perbedaan mendasar LED beralamat dari LED biasa: yang dikirim adalah **nilai**, bukan sekadar keadaan nyala atau padam.

| Nilai `Color(r, g, b)` | Warna yang teramati |
|---|---|
| `(255, 0, 0)` | |
| `(0, 255, 0)` | |
| `(0, 0, 255)` | |
| `(255, 255, 255)` | |

> **CHECKPOINT** — Warna yang teramati sesuai dengan urutan RGB. Apabila `(255, 0, 0)` justru menghasilkan hijau, urutan byte board berbeda dan konstanta `NEO_RGB` perlu diganti `NEO_GRB`.

## 8 · Analisis

1. Mengapa nilai `strip.setBrightness(50)` memengaruhi seluruh warna secara proporsional, sedangkan `strip.Color()` menentukan komposisinya?
2. Apa yang terjadi apabila `strip.show()` tidak dipanggil setelah `setPixelColor()`? Jelaskan berdasarkan cara kerja WS2812.
3. Berdasarkan ringkasan build, berapa persen Flash yang sudah terpakai oleh program sesederhana ini? Apa penyebabnya?

## 9 · Concept Check

1. Apa perbedaan LED digital biasa dan LED beralamat seperti WS2812?
2. Mengapa proyek ini memerlukan fork pioarduino, bukan platform espressif32 resmi?
3. Apa fungsi `build_src_filter` dan `default_envs` pada `platformio.ini`?
4. Serial Monitor menampilkan pesan startup hanya sekali. Apa arti pengamatan itu terhadap alur `setup()` dan `loop()`?

## 10 · Challenge (tugas modifikasi)

- **CH-1 — Pola napas.** Ubah kedipan menjadi transisi terang–redup bertahap (*breathing*) menggunakan `setBrightness()` di dalam `loop()`.
- **CH-2 — Non-blocking.** Ganti `delay()` dengan penjadwalan berbasis `millis()`, lalu jelaskan mengapa pola ini wajib pada modul komunikasi berikutnya.
- **CH-3 — Indikator status.** Rancang tiga warna sebagai kode status (mis. hijau = siap, kuning = menunggu, merah = galat) dan terapkan pada urutan `setup()`.

## 11 · Laporan

**Deliverable**

1. Misi dan capaian pembelajaran
2. Konfigurasi — isi `platformio.ini` beserta alasan pemilihan platform
3. Hasil eksperimen — tangkapan Serial Monitor dan foto/video LED (EXP-01…02)
4. Tabel pengamatan warna
5. Analisis dan concept check
6. Challenge — minimal CH-1
7. Kesimpulan yang disusun sendiri berdasarkan hasil pengujian
