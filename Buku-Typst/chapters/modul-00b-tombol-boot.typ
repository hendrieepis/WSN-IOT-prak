// ============================================================================
// Modul 00B — Tombol BOOT → LED (Warm-up)
// Sumber: week00_btn/README.md; listing kode dibaca langsung dari salinan
//         berkas sumber di assets/code/week00_btn/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 00B — Tombol BOOT ke LED", l: "bab:modul-00b")

#identitas-modul(
  "Modul 00B",
  [Read the First Input --- Tombol BOOT ke LED (modul pemanasan)],
  [Waveshare ESP32-H2-DEV-KIT-N4 · satu node · level Basic · 1 × 50 menit ·
   folder kode `week00_btn`],
)

#pengantar([Gambaran Umum])[
Modul 00B adalah modul pemanasan lanjutan dari `week00_blinky`, dirancang untuk
satu pertemuan (1 × 50 menit) pada tingkat dasar. Misinya menambahkan *input*
pada board: keadaan LED tidak lagi ditentukan timer, melainkan oleh penekanan
tombol. Percobaan berjalan pada satu node dengan tombol BOOT mengendalikan LED
RGB onboard, dan Serial Monitor 115200 baud sebagai instrumen pengamatan.
]

== Pendahuluan

Modul 00A membuktikan jalur *keluaran* bekerja. Modul ini melengkapinya dengan
jalur *masukan*, sehingga board memiliki dua unsur minimal sebuah simpul
sensor: sesuatu yang dibaca dari lingkungan, dan sesuatu yang ditampilkan
sebagai tanggapan. Keduanya dipakai kembali secara langsung pada M05B, ketika
tombol yang sama berperan sebagai simulasi _proximity switch_.

Prasyaratnya adalah M00A: rantai build--flash--monitor dan kendali LED WS2812.
Yang dibangun di sini adalah pembacaan digital input, logika _active low_,
pengenalan _bounce_ kontak mekanis, dan pemetaan masukan ke keluaran di dalam
satu `loop()`. Keempatnya dipakai lagi pada M05B ketika tombol BOOT berperan
sebagai proximity switch simulasi, dan pada setiap modul yang memerlukan pemicu
manual saat pengujian.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membaca masukan digital dan memetakannya ke keluaran])[
  + Membaca digital input pada ESP32-H2 menggunakan
    `pinMode(..., INPUT_PULLUP)` dan `digitalRead()`.
  + Menjelaskan logika *active low*: tombol tidak ditekan bernilai `HIGH`,
    tombol ditekan bernilai `LOW`, beserta peran resistor pull-up.
  + Menghubungkan masukan (tombol) dengan keluaran (LED RGB WS2812) di dalam
    satu `loop()`.
  + Menjelaskan gejala _bounce_ kontak mekanis dan cara paling sederhana
    meredamnya.
  + Menjelaskan risiko GPIO9 sebagai _strapping pin_ dan implikasinya saat
    pengujian.
]

*Kriteria keberhasilan*

#checklist((
  [LED menyala selama tombol BOOT ditahan dan padam saat dilepas.],
  [Serial Monitor mencetak tepat satu baris untuk setiap perubahan keadaan.],
  [Perilaku _strapping pin_ GPIO9 dapat dijelaskan berdasarkan pengamatan
   sendiri.],
))

== Dasar Teori (Secukupnya)

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Digital input], [Pembacaan tegangan pin sebagai dua keadaan logika, `HIGH` atau `LOW`.],
    [Pull-up], [Resistor yang menahan pin pada tegangan tinggi ketika tidak ada yang menariknya turun, sehingga pin tidak mengambang. Pada board ini bernilai 10K.],
    [Active low], [Konvensi ketika keadaan *aktif* diwakili tegangan rendah. Tombol BOOT terhubung ke GND saat ditekan, sehingga ditekan berarti `LOW`.],
    [Bounce], [Pantulan kontak mekanis selama beberapa milidetik saat tombol ditekan; tanpa penyaringan, satu penekanan terbaca sebagai banyak kejadian.],
    [Strapping pin], [Pin yang keadaannya dibaca chip *pada saat reset* untuk menentukan mode boot. GPIO9 termasuk di dalamnya.],
  ),
  [Istilah kerja Modul 00B],
  "tbl:m00b-istilah",
)

#catatan[
  *Mengapa pencetakan dibatasi pada perubahan keadaan?* `loop()` berjalan
  ribuan kali per detik. Mencetak pada setiap iterasi akan membanjiri Serial
  Monitor dan menyembunyikan informasi yang justru dicari, yaitu *kapan*
  keadaan berubah. Pola "cetak hanya saat berubah" ini dipakai kembali pada
  seluruh modul komunikasi.
]

== Alat yang Digunakan

Modul ini dijalankan di atas Waveshare ESP32-H2-DEV-KIT-N4 (ESP32-H2-MINI-1,
Arduino core 3.x) dengan PlatformIO.

#tbl(
  table(
    columns: (auto, 1fr, 1.2fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [Waveshare ESP32-H2-DEV-KIT-N4], [1],
    [2], [Kabel USB-C], [kabel data, bukan _charge-only_], [1],
    [3], [PC/Laptop], [PlatformIO Core/IDE terpasang], [1],
  ),
  [Alat dan bahan Modul 00B],
  "tbl:m00b-alat",
)

#tbl(
  table(
    columns: (auto, auto, 1fr),
    align: (left, center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Fungsi], th[GPIO], th[Keterangan (dari skematik board)]),
    [LED RGB WS2812], [GPIO8], [`RGB_CTRL`, satu pixel, urutan byte RGB],
    [Tombol BOOT], [GPIO9], [`Key2`, terhubung ke GND saat ditekan, pull-up 10K di board, sehingga *active low*],
  ),
  [Pemetaan pin Modul 00B],
  "tbl:m00b-pin",
)

Tidak diperlukan pengawatan tambahan: tombol dan LED sudah terpasang di board.
Skematik lengkap board tersedia pada @bab:lampiran-skematik

*Struktur proyek*

#diagram(```
week00_btn/
├── platformio.ini
└── src/
    └── main.cpp
```.text)

== Kode Program

#sumber-kode("week00_btn", ("platformio.ini", "src/main.cpp"))

#kode-berkas("week00_btn/platformio.ini",
  [`platformio.ini` Modul 00B],
  "lst:m00b-ini",
)

#kode-berkas("week00_btn/src/main.cpp",
  [`src/main.cpp` --- tombol BOOT mengendalikan LED RGB],
  "lst:m00b-main",
)

== Build dan Flash

#keluaran("pio run -d week00_btn -e node -t upload --upload-port /dev/ttyACM0
pio device monitor -p /dev/ttyACM0 -b 115200")

#penting[
  *Pilih port USB-to-UART, bukan USB native.* Board ESP32-H2 muncul sebagai
  *dua* port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan
  USB-Serial/JTAG bawaan chip (`303a:1001`). Flash dilakukan lewat *jembatan
  UART*, karena jalur itulah yang tersambung ke rangkaian _auto program_
  (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan tombol.
  Pada Linux keduanya berselang-seling: port *genap* adalah UART, port *ganjil*
  adalah USB native. Satu board memakai `/dev/ttyACM0`, dua board
  `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board `/dev/ttyACM0`, `/dev/ttyACM2`,
  dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port
  ber-Hardware ID `1A86:55D3`.
]

#peringatan[
  *Peringatan operasional.* GPIO9 juga merupakan _strapping pin_ mode download.
  Menahan tombol *pada saat board direset* akan membuat board masuk mode flash
  dan program tidak berjalan. Tombol hanya ditekan setelah firmware berjalan.
]

== Percobaan

=== EXP-01 --- Input Mengendalikan Output

Unggah firmware, buka Serial Monitor, lalu tekan dan lepas tombol BOOT beberapa
kali.

*Expected output*

#keluaran("Tombol BOOT (GPIO9) -> LED RGB WS2812 (GPIO8) dimulai
Tombol DITEKAN  -> LED nyala
Tombol DILEPAS  -> LED mati")

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nilai `digitalRead()` saat tombol dilepas], [#isian],
    [Nilai `digitalRead()` saat tombol ditekan], [#isian],
    [Jumlah baris Serial untuk satu kali tekan--lepas], [#isian],
    [Apakah LED padam tepat saat tombol dilepas?], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m00b-exp01",
)

#checkpoint[
  Satu kali tekan--lepas menghasilkan *tepat dua* baris. Munculnya baris
  berlipat menandakan _bounce_ belum teredam; catat gejalanya, karena hal itu
  menjadi bahan CH-3.
]

=== EXP-02 --- GPIO9 sebagai Strapping Pin

Tahan tombol BOOT, tekan tombol RESET, lalu lepaskan keduanya. Amati Serial
Monitor.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Keluaran Serial setelah reset dengan tombol ditahan], [#isian],
    [Apakah program aplikasi berjalan?], [#isian],
    [Cara mengembalikan board ke mode normal], [#isian],
  ),
  [Lembar pengamatan EXP-02],
  "tbl:m00b-exp02",
)

#checkpoint[
  Board masuk mode download dan pesan startup *tidak* muncul. Pengamatan ini
  menjelaskan mengapa satu pin dapat memiliki dua peran berbeda, bergantung
  pada waktu pembacaannya.
]

== Analisis

+ Mengapa `INPUT_PULLUP` tetap digunakan meskipun board sudah menyediakan
  pull-up 10K secara perangkat keras?
+ Apa yang terjadi pada pembacaan pin apabila pull-up dihilangkan seluruhnya?
  Gunakan istilah _floating_ dalam penjelasan.
+ `delay(20)` pada akhir `loop()` memiliki dua fungsi sekaligus. Sebutkan
  keduanya dan jelaskan konsekuensinya bila nilai tersebut diperbesar menjadi
  500 ms.
+ Berdasarkan EXP-02, mengapa perancang board menempatkan tombol BOOT pada pin
  yang juga dipakai program aplikasi? Apa keuntungan dan risikonya?

== Concept Check

+ Apa arti _active low_, dan bagaimana hal itu tampak pada kode?
+ Apa perbedaan `INPUT` dan `INPUT_PULLUP`?
+ Mengapa keluaran Serial dibatasi hanya pada perubahan keadaan?
+ Apa yang dimaksud _bounce_, dan mengapa gejalanya lebih menonjol pada sakelar
  mekanis dibanding sensor elektronik?
+ Sebutkan satu contoh sensor nyata yang secara listrik berperilaku sama dengan
  tombol ini.

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Memodifikasi logika masukan dan keluaran])[
  / CH-1 --- Toggle: Ubah program sehingga LED berganti nyala atau padam pada
    setiap *tepi turun* (saat tombol mulai ditekan), bukan mengikuti selama
    tombol ditahan.

  / CH-2 --- Siklus warna: Setiap penekanan menggeser warna: merah, hijau,
    biru, kembali ke merah.

  / CH-3 --- Debounce terukur: Hapus `delay(20)`, catat berapa baris ganda yang
    muncul pada 10 kali penekanan, lalu terapkan debounce berbasis `millis()`
    dan bandingkan hasilnya dalam satu tabel.

  / CH-4 --- Pengukuran durasi: Cetak lama tombol ditahan dalam milidetik pada
    saat dilepas, dan bandingkan hasilnya dengan hitungan manual menggunakan
    stopwatch.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (active low, pull-up, bounce, strapping pin).
+ Konfigurasi --- pin GPIO8 dan GPIO9 beserta rujukan skematik.
+ Hasil eksperimen --- tangkapan Serial Monitor EXP-01 dan EXP-02 beserta
  checkpoint.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-3, disertai tabel pembanding debounce.
+ Kesimpulan yang disusun sendiri berdasarkan hasil pengujian.
