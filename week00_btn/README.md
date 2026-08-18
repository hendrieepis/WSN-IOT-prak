```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 00B — Tombol BOOT → LED (Warm-up)

     Waveshare ESP32-H2-DEV-KIT-N4 · Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan


Modul 00B adalah modul pemanasan lanjutan dari `week00_blinky`, dirancang untuk satu pertemuan (1 × 50 menit) pada tingkat dasar. Misinya menambahkan **input** pada board: keadaan LED tidak lagi ditentukan timer, melainkan oleh penekanan tombol. Percobaan berjalan pada satu node dengan tombol BOOT mengendalikan LED RGB onboard, dan Serial Monitor 115200 baud sebagai instrumen pengamatan.

M00A membuktikan jalur **keluaran** bekerja. Modul ini melengkapinya dengan jalur **masukan**, sehingga board memiliki dua unsur minimal sebuah simpul sensor: sesuatu yang dibaca dari lingkungan, dan sesuatu yang ditampilkan sebagai tanggapan. Keduanya dipakai kembali secara langsung pada M05B, ketika tombol yang sama berperan sebagai simulasi *proximity switch*.

Prasyaratnya adalah M00A: rantai build–flash–monitor dan kendali LED WS2812. Yang dibangun di sini adalah pembacaan digital input, logika *active low*, pengenalan *bounce* kontak mekanis, dan pemetaan masukan ke keluaran di dalam satu `loop()`. Keempatnya dipakai lagi pada M05B ketika tombol BOOT berperan sebagai proximity switch simulasi, dan pada setiap modul yang memerlukan pemicu manual saat pengujian.

## 2 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

1. Membaca digital input pada ESP32-H2 menggunakan `pinMode(..., INPUT_PULLUP)` dan `digitalRead()`.
2. Menjelaskan logika **active low**: tombol tidak ditekan bernilai `HIGH`, tombol ditekan bernilai `LOW`, beserta peran resistor pull-up.
3. Menghubungkan masukan (tombol) dengan keluaran (LED RGB WS2812) di dalam satu `loop()`.
4. Menjelaskan gejala *bounce* kontak mekanis dan cara paling sederhana meredamnya.
5. Menjelaskan risiko GPIO9 sebagai *strapping pin* dan implikasinya saat pengujian.

**Kriteria keberhasilan**

- ☐ LED menyala selama tombol BOOT ditahan dan padam saat dilepas.
- ☐ Serial Monitor mencetak tepat satu baris untuk setiap perubahan keadaan.
- ☐ Perilaku *strapping pin* GPIO9 dapat dijelaskan berdasarkan pengamatan sendiri.

## 3 · Dasar Teori (secukupnya)

| Istilah | Definisi kerja di lab ini |
|---|---|
| Digital input | Pembacaan tegangan pin sebagai dua keadaan logika, `HIGH` atau `LOW`. |
| Pull-up | Resistor yang menahan pin pada tegangan tinggi ketika tidak ada yang menariknya turun, sehingga pin tidak mengambang. Pada board ini bernilai 10K. |
| Active low | Konvensi ketika keadaan **aktif** diwakili tegangan rendah. Tombol BOOT terhubung ke GND saat ditekan, sehingga ditekan berarti `LOW`. |
| Bounce | Pantulan kontak mekanis selama beberapa milidetik saat tombol ditekan; tanpa penyaringan, satu penekanan terbaca sebagai banyak kejadian. |
| Strapping pin | Pin yang keadaannya dibaca chip **pada saat reset** untuk menentukan mode boot. GPIO9 termasuk di dalamnya. |

**Mengapa pencetakan dibatasi pada perubahan keadaan?** `loop()` berjalan ribuan kali per detik. Mencetak pada setiap iterasi akan membanjiri Serial Monitor dan menyembunyikan informasi yang justru dicari, yaitu **kapan** keadaan berubah. Pola "cetak hanya saat berubah" ini dipakai kembali pada seluruh modul komunikasi.

## 4 · Alat yang Digunakan

Modul ini dijalankan di atas Waveshare ESP32-H2-DEV-KIT-N4 (ESP32-H2-MINI-1, Arduino core 3.x) + PlatformIO.

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | Waveshare ESP32-H2-DEV-KIT-N4 | 1 |
| 2 | Kabel USB-C | kabel data, bukan *charge-only* | 1 |
| 3 | PC/Laptop | PlatformIO Core/IDE terpasang | 1 |

| Fungsi | GPIO | Keterangan (dari skematik board) |
|---|---|---|
| LED RGB WS2812 | GPIO8 | `RGB_CTRL`, satu pixel, urutan byte RGB |
| Tombol BOOT | GPIO9 | `Key2`, terhubung ke GND saat ditekan, pull-up 10K di board → **active low** |

Tidak diperlukan pengawatan tambahan: tombol dan LED sudah terpasang di board.

**Struktur proyek**

```
week00_btn/
├── platformio.ini
└── src/
    └── main.cpp
```

## 5 · Build & Flash

```bash
pio run -d week00_btn -e node -t upload --upload-port /dev/ttyACM0
pio device monitor -p /dev/ttyACM0 -b 115200
```

> **Pilih port USB-to-UART, bukan USB native.** Board ESP32-H2 muncul sebagai **dua** port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan USB-Serial/JTAG bawaan chip (`303a:1001`). Flash dilakukan lewat **jembatan UART**, karena jalur itulah yang tersambung ke rangkaian *auto program* (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan tombol. Pada Linux keduanya berselang-seling: port **genap** adalah UART, port **ganjil** adalah USB native. Satu board memakai `/dev/ttyACM0`, dua board `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board `/dev/ttyACM0`, `/dev/ttyACM2`, dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port ber-Hardware ID `1A86:55D3`.

> **Peringatan operasional** — GPIO9 juga merupakan *strapping pin* mode download. Menahan tombol **pada saat board direset** akan membuat board masuk mode flash dan program tidak berjalan. Tombol hanya ditekan setelah firmware berjalan.

## 6 · Percobaan

### EXP-01 — Input Mengendalikan Output

Unggah firmware, buka Serial Monitor, lalu tekan dan lepas tombol BOOT beberapa kali.

**Expected output**

```
Tombol BOOT (GPIO9) -> LED RGB WS2812 (GPIO8) dimulai
Tombol DITEKAN  -> LED nyala
Tombol DILEPAS  -> LED mati
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Nilai `digitalRead()` saat tombol dilepas | |
| Nilai `digitalRead()` saat tombol ditekan | |
| Jumlah baris Serial untuk satu kali tekan-lepas | |
| Apakah LED padam tepat saat tombol dilepas? | |

> **CHECKPOINT** — Satu kali tekan-lepas menghasilkan **tepat dua** baris. Munculnya baris berlipat menandakan *bounce* belum teredam; catat gejalanya, karena hal itu menjadi bahan CH-3.

### EXP-02 — GPIO9 sebagai Strapping Pin

Tahan tombol BOOT, tekan tombol RESET, lalu lepaskan keduanya. Amati Serial Monitor.

**Data capture**

| Parameter | Hasil |
|---|---|
| Keluaran Serial setelah reset dengan tombol ditahan | |
| Apakah program aplikasi berjalan? | |
| Cara mengembalikan board ke mode normal | |

> **CHECKPOINT** — Board masuk mode download dan pesan startup **tidak** muncul. Pengamatan ini menjelaskan mengapa satu pin dapat memiliki dua peran berbeda, bergantung pada waktu pembacaannya.

## 7 · Analisis

1. Mengapa `INPUT_PULLUP` tetap digunakan meskipun board sudah menyediakan pull-up 10K secara perangkat keras?
2. Apa yang terjadi pada pembacaan pin apabila pull-up dihilangkan seluruhnya? Gunakan istilah *floating* dalam penjelasan.
3. `delay(20)` pada akhir `loop()` memiliki dua fungsi sekaligus. Sebutkan keduanya dan jelaskan konsekuensinya bila nilai tersebut diperbesar menjadi 500 ms.
4. Berdasarkan EXP-02, mengapa perancang board menempatkan tombol BOOT pada pin yang juga dipakai program aplikasi? Apa keuntungan dan risikonya?

## 8 · Concept Check

1. Apa arti *active low*, dan bagaimana hal itu tampak pada kode?
2. Apa perbedaan `INPUT` dan `INPUT_PULLUP`?
3. Mengapa keluaran Serial dibatasi hanya pada perubahan keadaan?
4. Apa yang dimaksud *bounce*, dan mengapa gejalanya lebih menonjol pada sakelar mekanis dibanding sensor elektronik?
5. Sebutkan satu contoh sensor nyata yang secara listrik berperilaku sama dengan tombol ini.

## 9 · Challenge (tugas modifikasi)

- **CH-1 — Toggle.** Ubah program sehingga LED berganti nyala/padam pada setiap **tepi turun** (saat tombol mulai ditekan), bukan mengikuti selama tombol ditahan.
- **CH-2 — Siklus warna.** Setiap penekanan menggeser warna: merah → hijau → biru → merah.
- **CH-3 — Debounce terukur.** Hapus `delay(20)`, catat berapa baris ganda yang muncul pada 10 kali penekanan, lalu terapkan debounce berbasis `millis()` dan bandingkan hasilnya dalam satu tabel.
- **CH-4 — Pengukuran durasi.** Cetak lama tombol ditahan dalam milidetik pada saat dilepas, dan bandingkan hasilnya dengan hitungan manual menggunakan stopwatch.

## 10 · Laporan

**Deliverable**

1. Misi dan capaian pembelajaran
2. Dasar teori ringkas (active low, pull-up, bounce, strapping pin)
3. Konfigurasi — pin GPIO8/GPIO9 beserta rujukan skematik
4. Hasil eksperimen — tangkapan Serial Monitor EXP-01 dan EXP-02 beserta checkpoint
5. Analisis dan concept check
6. Challenge — minimal CH-1 dan CH-3, disertai tabel pembanding debounce
7. Kesimpulan yang disusun sendiri berdasarkan hasil pengujian
