```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
        MODUL 00A — Blinky ESP32-H2 (Warm-up)

     Waveshare ESP32-H2-DEV-KIT-N4 · Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan

Modul 00A adalah modul pemanasan yang dikerjakan sebelum M01, dirancang untuk satu pertemuan (1 × 50 menit) pada tingkat dasar. Misinya tunggal dan sempit: memastikan toolchain PlatformIO, board, dan jalur flash benar-benar bekerja sebelum modul komunikasi dimulai. Percobaan berjalan pada satu node dengan LED RGB onboard yang berkedip sebagai penanda keberhasilan, dan Serial Monitor pada 115200 baud sebagai satu-satunya instrumen pengamatan.

Modul ini tidak mengajarkan protokol apa pun. Fungsinya menutup satu sumber kebingungan yang berulang di laboratorium: ketika sebuah modul komunikasi gagal, penyebabnya bisa berada di protokol, di firmware, atau di rantai kerja paling dasar — toolchain, board, kabel, dan port. Dengan menuntaskan modul ini lebih dahulu, kemungkinan terakhir dapat dicoret sejak awal.

Bekal yang diperlukan hanya dasar bahasa C dan PlatformIO Core/IDE yang sudah terpasang; tidak ada modul yang mendahuluinya. Yang dibangun di sini ada tiga, dan ketiganya dipakai terus-menerus sesudahnya: struktur proyek PlatformIO, alur kerja build–flash–monitor, serta kendali LED RGB WS2812. Ketiganya langsung dipakai kembali pada M00B ketika jalur masukan ditambahkan, sedangkan rantai build–flash–monitor yang sama menjadi dasar kerja seluruh modul M01 hingga M16.

## 2 · Capaian Pembelajaran

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

## 3 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan.

| Istilah | Definisi kerja di lab ini |
|---|---|
| ESP32-H2 | SoC berinti RISC-V dengan radio BLE 5 dan IEEE 802.15.4, tanpa Wi-Fi. |
| pioarduino | Fork platform espressif32 yang menyediakan definisi board ESP32-H2, yang belum tersedia pada platform resmi PlatformIO. |
| WS2812 | LED RGB beralamat: warna dikirim sebagai deretan bit pada satu jalur data, bukan diatur oleh tegangan pin seperti LED biasa. |
| Urutan byte warna | Urutan pengiriman komponen warna. WS2812 umumnya GRB; pada board ini pengamatan empiris menunjukkan urutan **RGB**, sehingga dipakai `NEO_RGB`. |
| Environment PlatformIO | Konfigurasi build bernama pada `platformio.ini`; dipilih dengan opsi `-e`. |

## 4 · Alat yang Digunakan

Seluruh percobaan dijalankan pada Waveshare ESP32-H2-DEV-KIT-N4 (modul ESP32-H2-MINI-1) dengan Arduino core 3.x di atas PlatformIO.

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

## 5 · Build & Flash

```bash
pio run -d week00_blinky -e node -t upload --upload-port /dev/ttyACM0
pio device monitor -p /dev/ttyACM0 -b 115200
```

> **Pilih port USB-to-UART, bukan USB native.** Board ESP32-H2 muncul sebagai **dua** port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan USB-Serial/JTAG bawaan chip (`303a:1001`). Flash dilakukan lewat **jembatan UART**, karena jalur itulah yang tersambung ke rangkaian *auto program* (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan tombol. Pada Linux keduanya berselang-seling: port **genap** adalah UART, port **ganjil** adalah USB native. Satu board memakai `/dev/ttyACM0`, dua board `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board `/dev/ttyACM0`, `/dev/ttyACM2`, dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port ber-Hardware ID `1A86:55D3`.

**Pre-flight checklist**

- ☐ `pio device list` dijalankan dan port jembatan UART (`1A86:55D3`) tercatat.
- ☐ Kabel yang dipakai dipastikan kabel data.
- ☐ Environment `node` dikenali PlatformIO.

## 6 · Percobaan

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

## 7 · Analisis

1. Mengapa nilai `strip.setBrightness(50)` memengaruhi seluruh warna secara proporsional, sedangkan `strip.Color()` menentukan komposisinya?
2. Apa yang terjadi apabila `strip.show()` tidak dipanggil setelah `setPixelColor()`? Jelaskan berdasarkan cara kerja WS2812.
3. Berdasarkan ringkasan build, berapa persen Flash yang sudah terpakai oleh program sesederhana ini? Apa penyebabnya?

## 8 · Concept Check

1. Apa perbedaan LED digital biasa dan LED beralamat seperti WS2812?
2. Mengapa proyek ini memerlukan fork pioarduino, bukan platform espressif32 resmi?
3. Apa fungsi `build_src_filter` dan `default_envs` pada `platformio.ini`?
4. Serial Monitor menampilkan pesan startup hanya sekali. Apa arti pengamatan itu terhadap alur `setup()` dan `loop()`?

## 9 · Challenge (tugas modifikasi)

- **CH-1 — Pola napas.** Ubah kedipan menjadi transisi terang–redup bertahap (*breathing*) menggunakan `setBrightness()` di dalam `loop()`.
- **CH-2 — Non-blocking.** Ganti `delay()` dengan penjadwalan berbasis `millis()`, lalu jelaskan mengapa pola ini wajib pada modul komunikasi berikutnya.
- **CH-3 — Indikator status.** Rancang tiga warna sebagai kode status (mis. hijau = siap, kuning = menunggu, merah = galat) dan terapkan pada urutan `setup()`.

## 10 · Laporan

**Deliverable**

1. Misi dan capaian pembelajaran
2. Konfigurasi — isi `platformio.ini` beserta alasan pemilihan platform
3. Hasil eksperimen — tangkapan Serial Monitor dan foto/video LED (EXP-01…02)
4. Tabel pengamatan warna
5. Analisis dan concept check
6. Challenge — minimal CH-1
7. Kesimpulan yang disusun sendiri berdasarkan hasil pengujian
