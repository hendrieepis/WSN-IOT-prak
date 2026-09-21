// ============================================================================
// Lampiran D — Modul 00A: Blinky ESP32-H2 (Warm-up)
// Sumber: week00_blinky/README.md; listing kode dibaca langsung dari salinan
//         berkas sumber di assets/code/week00_blinky/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 00A — Blinky ESP32-H2", l: "bab:modul-00a")

#identitas-modul(
  "Modul 00A",
  [Verify the Toolchain --- Blinky ESP32-H2 (modul pemanasan)],
  [Waveshare ESP32-H2-DEV-KIT-N4 · satu node · level Basic · 1 × 50 menit ·
   folder kode `week00_blinky`],
)

#pengantar([Gambaran Umum])[
Modul 00A adalah modul pemanasan yang dikerjakan sebelum M01, dirancang untuk
satu pertemuan (1 × 50 menit) pada tingkat dasar. Misinya tunggal dan sempit:
memastikan toolchain PlatformIO, board, dan jalur flash benar-benar bekerja
sebelum modul komunikasi dimulai. Percobaan berjalan pada satu node dengan LED
RGB onboard yang berkedip sebagai penanda keberhasilan, dan Serial Monitor pada
115200 baud sebagai satu-satunya instrumen pengamatan.
]

== Pendahuluan

Modul ini tidak mengajarkan protokol apa pun. Fungsinya menutup satu sumber
kebingungan yang berulang di laboratorium: ketika sebuah modul komunikasi
gagal, penyebabnya bisa berada di protokol, di firmware, atau di rantai kerja
paling dasar --- toolchain, board, kabel, dan port. Dengan menuntaskan modul
ini lebih dahulu, kemungkinan terakhir dapat dicoret sejak awal.

Bekal yang diperlukan hanya dasar bahasa C dan PlatformIO Core/IDE yang sudah
terpasang; tidak ada modul yang mendahuluinya. Yang dibangun di sini ada tiga,
dan ketiganya dipakai terus-menerus sesudahnya: struktur proyek PlatformIO,
alur kerja build--flash--monitor, serta kendali LED RGB WS2812. Ketiganya
langsung dipakai kembali pada M00B ketika jalur masukan ditambahkan, sedangkan
rantai build--flash--monitor yang sama menjadi dasar kerja seluruh modul M01
hingga M16.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membuktikan rantai kerja PlatformIO ke ESP32-H2])[
  + Menjelaskan posisi ESP32-H2 dalam ekosistem ESP32 (inti RISC-V, radio BLE
    dan IEEE 802.15.4) dan kesetaraan pinout Waveshare ESP32-H2-DEV-KIT-N4
    dengan ESP32-H2-DevKitM-1.
  + Membuat proyek PlatformIO menggunakan fork pioarduino, serta menjelaskan
    alasan platform resmi belum dapat dipakai untuk board ESP32-H2.
  + Melakukan build, flash, dan monitor firmware, serta memverifikasi LED RGB
    WS2812 pada GPIO8 bekerja sesuai program.
  + Membaca keluaran Serial Monitor sebagai instrumen verifikasi, bukan sekadar
    catatan tambahan.
]

*Kriteria keberhasilan*

#checklist((
  [Proses `pio run -t upload` selesai tanpa galat.],
  [LED RGB onboard berkedip dengan periode 1 detik.],
  [Serial Monitor menampilkan pesan startup tepat satu kali setelah reset.],
  [Warna LED berhasil diubah melalui `strip.Color(r, g, b)`.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Istilah kerja yang
diperlukan dirangkum pada @tbl:m00a-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [ESP32-H2], [SoC berinti RISC-V dengan radio BLE 5 dan IEEE 802.15.4, tanpa Wi-Fi.],
    [pioarduino], [Fork platform `espressif32` yang menyediakan definisi board ESP32-H2, yang belum tersedia pada platform resmi PlatformIO.],
    [WS2812], [LED RGB beralamat: warna dikirim sebagai deretan bit pada satu jalur data, bukan diatur oleh tegangan pin seperti LED biasa.],
    [Urutan byte warna], [Urutan pengiriman komponen warna. WS2812 umumnya GRB; pada board ini pengamatan empiris menunjukkan urutan *RGB*, sehingga dipakai `NEO_RGB`.],
    [Environment PlatformIO], [Konfigurasi build bernama pada `platformio.ini`; dipilih dengan opsi `-e`.],
  ),
  [Istilah kerja Modul 00A],
  "tbl:m00a-istilah",
)

== Alat yang Digunakan

Seluruh percobaan dijalankan pada Waveshare ESP32-H2-DEV-KIT-N4 (modul
ESP32-H2-MINI-1) dengan Arduino core 3.x di atas PlatformIO.

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
  [Alat dan bahan Modul 00A],
  "tbl:m00a-alat",
)

#tbl(
  table(
    columns: (auto, auto, 1fr),
    align: (left, center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Fungsi], th[GPIO], th[Keterangan (dari skematik board)]),
    [LED RGB WS2812], [GPIO8], [`RGB_CTRL`, satu pixel, urutan byte RGB],
  ),
  [Pemetaan pin Modul 00A],
  "tbl:m00a-pin",
)

Skematik lengkap board tersedia pada @bab:lampiran-skematik

*Struktur proyek*

#diagram(```
week00_blinky/
├── platformio.ini
└── src/
    └── main.cpp
```.text)

== Kode Program

#sumber-kode("week00_blinky", ("platformio.ini", "src/main.cpp"))

#kode-berkas("week00_blinky/platformio.ini",
  [`platformio.ini` Modul 00A],
  "lst:m00a-ini",
)

Berkas `src/main.cpp` berisi keseluruhan program modul ini (@lst:m00a-main).
Program menyalakan satu pixel WS2812 pada GPIO8 dengan warna merah selama
500 ms, lalu memadamkannya selama 500 ms, sehingga periode kedipnya 1 detik.

#kode-berkas("week00_blinky/src/main.cpp",
  [`src/main.cpp` --- blinky LED RGB WS2812],
  "lst:m00a-main",
)

== Build dan Flash

#keluaran("pio run -d week00_blinky -e node -t upload --upload-port /dev/ttyACM0
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

*Pre-flight checklist*

#checklist((
  [`pio device list` dijalankan dan port jembatan UART (`1A86:55D3`) tercatat.],
  [Kabel yang dipakai dipastikan kabel data.],
  [Environment `node` dikenali PlatformIO.],
))

== Percobaan

=== EXP-01 --- Build dan Flash Pertama

Bangun dan unggah firmware, lalu amati LED serta Serial Monitor.

*Expected output*

#keluaran("Blinky RGB WS2812 ESP32-H2-DEV-KIT-N4 dimulai")

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Port serial yang terdeteksi], [#isian],
    [Waktu build pertama (s)], [#isian],
    [Pemakaian Flash / RAM dari ringkasan build], [#isian],
    [Periode kedip terukur (s)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m00a-exp01",
)

#checkpoint[
  LED berkedip *dan* pesan startup muncul tepat satu kali. Pesan yang muncul
  berulang menandakan board melakukan reset berkala; hentikan dan periksa catu
  daya serta kabel sebelum melanjutkan.
]

=== EXP-02 --- Warna sebagai Data

Ubah argumen `strip.Color(r, g, b)`, unggah ulang, dan amati perubahannya.
Percobaan ini menegaskan perbedaan mendasar LED beralamat dari LED biasa: yang
dikirim adalah *nilai*, bukan sekadar keadaan nyala atau padam.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Nilai `Color(r, g, b)`], th[Warna yang teramati]),
    [`(255, 0, 0)`], [#isian],
    [`(0, 255, 0)`], [#isian],
    [`(0, 0, 255)`], [#isian],
    [`(255, 255, 255)`], [#isian],
  ),
  [Lembar pengamatan EXP-02 --- pemetaan nilai warna],
  "tbl:m00a-exp02",
)

#checkpoint[
  Warna yang teramati sesuai dengan urutan RGB. Apabila `(255, 0, 0)` justru
  menghasilkan hijau, urutan byte board berbeda dan konstanta `NEO_RGB` perlu
  diganti `NEO_GRB`.
]

== Analisis

+ Mengapa nilai `strip.setBrightness(50)` memengaruhi seluruh warna secara
  proporsional, sedangkan `strip.Color()` menentukan komposisinya?
+ Apa yang terjadi apabila `strip.show()` tidak dipanggil setelah
  `setPixelColor()`? Jelaskan berdasarkan cara kerja WS2812.
+ Berdasarkan ringkasan build, berapa persen Flash yang sudah terpakai oleh
  program sesederhana ini? Apa penyebabnya?

== Concept Check

+ Apa perbedaan LED digital biasa dan LED beralamat seperti WS2812?
+ Mengapa proyek ini memerlukan fork pioarduino, bukan platform `espressif32`
  resmi?
+ Apa fungsi `build_src_filter` dan `default_envs` pada `platformio.ini`?
+ Serial Monitor menampilkan pesan startup hanya sekali. Apa arti pengamatan
  itu terhadap alur `setup()` dan `loop()`?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Memodifikasi perilaku LED])[
  / CH-1 --- Pola napas: Ubah kedipan menjadi transisi terang--redup bertahap
    (_breathing_) menggunakan `setBrightness()` di dalam `loop()`.

  / CH-2 --- Non-blocking: Ganti `delay()` dengan penjadwalan berbasis
    `millis()`, lalu jelaskan mengapa pola ini wajib pada modul komunikasi
    berikutnya.

  / CH-3 --- Indikator status: Rancang tiga warna sebagai kode status (misalnya
    hijau = siap, kuning = menunggu, merah = galat) dan terapkan pada urutan
    `setup()`.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Konfigurasi --- isi `platformio.ini` beserta alasan pemilihan platform.
+ Hasil eksperimen --- tangkapan Serial Monitor dan foto atau video LED
  (EXP-01 dan EXP-02).
+ Tabel pengamatan warna.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1.
+ Kesimpulan yang disusun sendiri berdasarkan hasil pengujian.
