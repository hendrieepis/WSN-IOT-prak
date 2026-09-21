// ============================================================================
// Buku Petunjuk Praktikum Wireless Sensor Network & Internet of Things
// Hasil konversi berkas README.md tiap modul pada repositori WSN-IOT-prak.
//
// Berkas ini hanya menangani konfigurasi global, halaman judul, daftar isi,
// dan pemanggilan setiap modul. Isi buku berada di folder `chapters/`.
// Kompilasi:  typst compile main.typ
// ============================================================================

#import "@preview/orange-book:0.7.1": book, chapter, appendices, update-heading-image
#import "config.typ": lampiran
#import "lib/cover.typ": cover-page

#let warna-utama = rgb("#F36619")

#show: book.with(
  // Blok judul bawaan template dinonaktifkan (title/subtitle/author kosong
  // + latar transparan) karena halaman sampul digambar sendiri oleh
  // lib/cover.typ. Judul, subjudul, dan penulis diisi di cover-page(...).
  title: "",
  subtitle: "",
  author: "",
  cover-background: rgb(0%, 0%, 0%, 0%),
  cover: cover-page(
    kicker: "IoT Communication Lab · Buku Kerja Laboratorium",
    // "\n" memaksa ganti baris agar "Wireless Sensor Network &" tidak terpotong.
    title: "Petunjuk Praktikum\nWireless Sensor Network & Internet of Things",
    highlight: "Internet of Things",
    // Subjudul mengikuti edisi buku di config.typ:
    //   "dosen"     -> "... Buku Pegangan untuk Pengajar"
    //   "mahasiswa" -> "... Buku Pegangan untuk Mahasiswa"
    topics: ("BLE", "IEEE 802.15.4", "Zigbee", "Thread", "Wi-Fi/MQTT"),
    author: "Akhmad Hendriawan",
    publisher: "2026",
  ),
  date: datetime(year: 2026, month: 9, day: 20),
  main-color: warna-utama,
  lang: "id",
  list-of-figure-title: "Daftar Gambar",
  list-of-table-title: "Daftar Tabel",
  // Penomoran bab berjalan 1, 2, 3, … sedangkan label modul pada sumber tidak
  // berurutan (01, …, 05B, 05C, …). Supplement dibuat "Bab" agar
  // kedua penomoran itu tidak tertukar; kode modul ditulis pada judul bab dan
  // pada kotak identitas di awal tiap bab.
  supplement-chapter: "Bab",
  supplement-part: "Bagian",
  heading-style: 0,
  outline-depth: 3,
  first-line-indent: false,
  lowercase-references: false,
  copyright: [
    *Lisensi Dokumen*

    Copyright © 2026 oleh Akhmad Hendriawan.

    Dokumen ini disusun sebagai petunjuk praktikum mata kuliah Wireless Sensor
    Network dan Internet of Things. Seluruh isinya dapat digunakan dan
    disebarkan secara bebas untuk tujuan bukan komersial (nonprofit), dengan
    syarat tidak menghapus atau mengubah atribut penulis dan pernyataan
    copyright yang disertakan di dalamnya.

    Seluruh angka hasil pengujian yang dicantumkan pada buku ini berasal dari
    pengukuran pada perangkat nyata, bukan nilai contoh. Kode sumber setiap
    modul berada pada repositori praktikum, di dalam folder `weekNN_nama`
    yang disebut pada awal tiap modul.

    Departemen Teknik Elektro, Politeknik Elektronika Negeri Surabaya
  ],
)

// --- Gaya tambahan khusus buku ini -------------------------------------------
// Kode sumber memakai font monospaced yang lebih rapat agar listing panjang
// tetap muat di dalam margin, dan memuat karakter penggambar kotak Unicode
// yang dipakai diagram topologi.
#show raw: set text(font: ("DejaVu Sans Mono", "Consolas", "Courier New"))

// Nama fungsi dan konstanta yang panjang (mis.
// `esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`) tidak memiliki titik henti
// baris, sehingga dapat menembus tepi kolom tabel. Aturan berikut menyisipkan
// peluang ganti baris (spasi selebar nol) sesudah garis bawah dan kurung buka
// pada kode sebaris, tanpa mengubah teks yang tercetak.
#show raw.where(block: false): it => {
  show "_": "_" + sym.zws
  show "(": "(" + sym.zws
  it
}

// Listing kode pada buku ini banyak yang lebih panjang dari satu halaman,
// sehingga figure harus boleh terpotong antar halaman.
#show figure: set block(breakable: true)

// `orange-book` mereset penomoran gambar dan tabel pada setiap bab, tetapi
// tidak mereset penomoran listing kode. Aturan berikut melengkapinya agar
// nomor listing juga dimulai ulang dari 1 pada tiap modul.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: raw)).update(0)
  it
}

// Paragraf tidak memakai indentasi baris pertama, sehingga jarak antar
// paragraf perlu sedikit dilonggarkan.
#set par(spacing: 0.9em)

// Teks di dalam sel tabel tidak dijustifikasi: kolom sempit yang
// dijustifikasi menghasilkan jarak antar kata yang melebar dan sulit dibaca.
#show table: set par(justify: false)

// Jarak antar item daftar dirapatkan supaya langkah percobaan tetap padu.
#set enum(spacing: 0.9em, indent: 0.4em, body-indent: 0.5em)
#set list(spacing: 0.9em, indent: 0.4em, body-indent: 0.5em)

// --- Prakata ------------------------------------------------------------------
#include "chapters/00-prakata.typ"

// --- Modul --------------------------------------------------------------------
#include "chapters/modul-01-ble-p2p.typ"
#include "chapters/modul-02-ble-data.typ"
#include "chapters/modul-03-ble-client-server.typ"
#include "chapters/modul-04-ble-telemetry.typ"
#include "chapters/modul-05-ble-multinode.typ"
#include "chapters/modul-05b-smart-sensor.typ"
#include "chapters/modul-05c-pager.typ"
#include "chapters/modul-06-ble-relay.typ"
#include "chapters/modul-07-802154-raw.typ"
#include "chapters/modul-08-zigbee-p2p.typ"
#include "chapters/modul-09-zigbee-multinode.typ"
#include "chapters/modul-10-zigbee-mesh.typ"
#include "chapters/modul-11-thread-p2p.typ"
#include "chapters/modul-12-thread-mesh.typ"
#include "chapters/modul-13-gateway-thread-wifi.typ"
#include "chapters/modul-14-mqtt.typ"
#include "chapters/modul-15-e2e-iot.typ"
#include "chapters/modul-16-benchmark.typ"

// --- Bagian pelengkap ---------------------------------------------------------
#show: appendices.with("Bagian Pelengkap")

// Daftar lampiran (dan lampiran mana yang tampil per edisi) diatur di
// config.typ.
#lampiran
