// =====================================================================
//  Konfigurasi edisi buku
// =====================================================================
//
//  Ubah nilai `edisi_buku` di bawah ini, lalu kompilasi ulang:
//
//      typst compile main.typ
//
//  Nilai yang tersedia:
//
//    "dosen"     -> (default) seluruh isi ditampilkan, termasuk
//                   Lampiran A (Tanya Jawab/FAQ) dan Lampiran C
//                   (Perkakas Pendukung), serta tautan GitHub ke setiap
//                   berkas kode (kotak KODE SUMBER di tiap bab, baris
//                   tautan di bawah tiap listing, dan bagian repositori
//                   pada Pendahuluan).
//    "mahasiswa" -> Lampiran A, Lampiran C, dan seluruh tautan GitHub
//                   disembunyikan. Listing kode tetap dimuat lengkap
//                   sehingga buku berdiri sendiri.

#let edisi_buku = "dosen"

// ---------------------------------------------------------------------
//  Turunan otomatis dari edisi di atas (tidak perlu diubah)
// ---------------------------------------------------------------------

// Subjudul yang dicetak pada halaman sampul.
#let edisi-subtitle = if edisi_buku == "dosen" {
  "ESP32-H2 & ESP32-C6 Version - Buku Pegangan untuk Pengajar"
} else {
  "ESP32-H2 & ESP32-C6 Version - Buku Pegangan untuk Mahasiswa"
}

// Lampiran yang dicetak di Bagian Pelengkap (dipanggil main.typ lewat
// `#lampiran()`). Lampiran A dan C hanya muncul pada edisi dosen. Modul
// warm-up 00A dan 00B dimuat sebagai lampiran terakhir.
#let lampiran() = {
  if edisi_buku == "dosen" {
    include "chapters/lampiran-a-faq.typ"
  }
  include "chapters/lampiran-b-skematik.typ"
  if edisi_buku == "dosen" {
    include "chapters/lampiran-c-perkakas.typ"
  }
  include "chapters/lampiran-d-blinky.typ"
  include "chapters/lampiran-e-tombol-boot.typ"
}
