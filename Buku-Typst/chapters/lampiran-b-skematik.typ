// ============================================================================
// Lampiran B — Skematik Board
// Sumber: skematik/ESP32-H2-DEV-KIT-N4.pdf (dikonversi ke PNG 300 dpi pada
//         assets/images/skematik-esp32-h2-dev-kit-n4.png).
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": catatan, todo
#import "../lib/helpers.typ": tbl, th, kode-berkas, sumber-kode, gh, gh-folder

#chapter("Skematik Board ESP32-H2", l: "bab:lampiran-skematik")

Lampiran ini memuat skematik board Waveshare ESP32-H2-DEV-KIT-N4 yang dipakai
pada seluruh modul berbasis ESP32-H2. Skematik diperlukan setiap kali sebuah
modul menyebut nomor GPIO: rujukan pin pada tiap modul berasal dari lembar ini,
bukan dari datasheet chip. Gambar selengkapnya diberikan pada
@gbr:skematik-h2, yang ditempatkan pada halaman tersendiri dengan orientasi
mendatar agar seluruh blok rangkaian tetap terbaca.

== Pin yang Dipakai di Buku Ini

Dua pin berikut dipakai langsung pada modul warm-up dan dirujuk kembali pada
modul-modul selanjutnya.

#tbl(
  table(
    columns: (auto, auto, auto, 1fr),
    align: (left, center + horizon, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Fungsi], th[GPIO], th[Nama di skematik], th[Keterangan]),
    [LED RGB WS2812], [GPIO8], [`RGB_CTRL`], [satu pixel, urutan byte RGB],
    [Tombol BOOT], [GPIO9], [`Key2`], [terhubung ke GND saat ditekan, pull-up 10K di board, sehingga _active low_; sekaligus _strapping pin_ mode download],
  ),
  [Pin board yang dipakai pada Modul 00A dan 00B],
  "tbl:lampiran-pin",
)

#catatan[
  Board Waveshare ESP32-H2-DEV-KIT-N4 memakai modul ESP32-H2-MINI-1 dan pinout
  yang setara dengan ESP32-H2-DevKitM-1, sehingga definisi board
  `esp32-h2-devkitm-1` pada `platformio.ini` dapat dipakai apa adanya.
]

#catatan[
  Gambar pada lampiran ini dihasilkan dari berkas
  `skematik/ESP32-H2-DEV-KIT-N4.pdf` pada repositori praktikum, dirender pada
  resolusi 300 dpi. Berkas PDF aslinya tetap menjadi acuan bila diperlukan
  pembesaran lebih jauh.
]

// Halaman skematik: mendatar, margin dipersempit, dan figure dibuat tidak
// boleh terpotong agar caption tetap menyatu dengan gambarnya. Tanpa
// `breakable: false`, aturan global pada `main.typ` membuat gambar dan
// caption jatuh pada dua halaman yang berbeda.
#page(flipped: true, margin: (x: 1.5cm, y: 1.5cm), header: none, footer: none)[
  #show figure: set block(breakable: false)
  #figure(
    image("../assets/images/skematik-esp32-h2-dev-kit-n4.png", width: 88%),
    caption: [Skematik Waveshare ESP32-H2-DEV-KIT-N4],
  ) #label("gbr:skematik-h2")
]
