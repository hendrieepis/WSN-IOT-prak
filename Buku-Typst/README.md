# Buku Typst — Petunjuk Praktikum WSN & IoT

Sumber Typst buku petunjuk praktikum, hasil konversi berkas `README.md` tiap modul
pada repositori `WSN-IOT-prak`. Template tampilan memakai
[orange-book](https://typst.app/universe/package/orange-book/) versi `0.7.1`.

## Kompilasi

```bash
typst compile main.typ          # menghasilkan main.pdf
typst watch main.typ            # kompilasi ulang otomatis saat berkas berubah
```

Paket `orange-book` diambil otomatis dari Typst Universe pada kompilasi pertama.
Buku ini diuji dengan Typst 0.14.2.

## Struktur

| Berkas / folder | Isi |
|---|---|
| `main.typ` | konfigurasi global, sampul, daftar isi, dan `include` tiap bab |
| `chapters/` | satu berkas Typst untuk setiap bab |
| `lib/callouts.typ` | kotak informasi: `catatan`, `tip`, `penting`, `peringatan`, `checkpoint`, `buka-abstraksi`, `todo`, `pengantar`, `tujuan-prak`, `identitas-modul` |
| `lib/helpers.typ` | pembungkus gambar, tabel, listing kode, blok keluaran, diagram ASCII, dan checklist |
| `assets/images/` | gambar; skematik board dirender dari `../skematik/*.pdf` pada 300 dpi |
| `assets/code/` | salinan **seluruh** berkas sumber tiap modul; dibaca `kode-berkas(...)` saat kompilasi |

## Peta bab dan sumbernya

| Bab | Berkas Typst | Sumber |
|---|---|---|
| Pendahuluan | `chapters/00-prakata.typ` | `../README.md` |
| Bab 1 — Modul 00A | `chapters/modul-00a-blinky.typ` | `../week00_blinky/` |
| Bab 2 — Modul 00B | `chapters/modul-00b-tombol-boot.typ` | `../week00_btn/` |
| Bab 3 — Modul 01 | `chapters/modul-01-ble-p2p.typ` | `../week01_ble_p2p/` |
| Bab 4 — Modul 02 | `chapters/modul-02-ble-data.typ` | `../week02_ble_p2p_data/` |
| Bab 5 — Modul 03 | `chapters/modul-03-ble-client-server.typ` | `../week03_ble_client_server/` |
| Bab 6 — Modul 04 | `chapters/modul-04-ble-telemetry.typ` | `../week04_ble_telemetry/` |
| Bab 7 — Modul 05 | `chapters/modul-05-ble-multinode.typ` | `../week05_ble_multinode/` |
| Bab 8 — Modul 05B | `chapters/modul-05b-smart-sensor.typ` | `../week05b_ble_multinode_project/` |
| Bab 9 — Modul 05C | `chapters/modul-05c-pager.typ` | `../week05c_ble_pager/` |
| Bab 10 — Modul 06 | `chapters/modul-06-ble-relay.typ` | `../week06_ble_mesh/` |
| Bab 11 — Modul 07 | `chapters/modul-07-802154-raw.typ` | `../week07_802154_p2p/` |
| Bab 12 — Modul 08 | `chapters/modul-08-zigbee-p2p.typ` | `../week08_zigbee_p2p/` |
| Bab 13 — Modul 09 | `chapters/modul-09-zigbee-multinode.typ` | `../week09_zigbee_multinode/` |
| Bab 14 — Modul 10 | `chapters/modul-10-zigbee-mesh.typ` | `../week10_zigbee_mesh/` |
| Bab 15 — Modul 11 | `chapters/modul-11-thread-p2p.typ` | `../week11_thread_p2p/` |
| Bab 16 — Modul 12 | `chapters/modul-12-thread-mesh.typ` | `../week12_thread_mesh/` |
| Bab 17 — Modul 13 | `chapters/modul-13-gateway-thread-wifi.typ` | `../week13_thread_wifi_gateway/` |
| Bab 18 — Modul 14 | `chapters/modul-14-mqtt.typ` | `../week14_mqtt/` |
| Bab 19 — Modul 15 | `chapters/modul-15-e2e-iot.typ` | `../week15_e2e_iot/` |
| Bab 20 — Modul 16 | `chapters/modul-16-benchmark.typ` | `../week16_comparative/` |
| Lampiran A — FAQ | `chapters/lampiran-a-faq.typ` | `../FAQ.md` |
| Lampiran B — Skematik | `chapters/lampiran-b-skematik.typ` | `../skematik/ESP32-H2-DEV-KIT-N4.pdf` |
| Lampiran C — Perkakas | `chapters/lampiran-c-perkakas.typ` | `../tools/` |

Seluruh modul sudah dikonversi. Untuk menambahkan modul baru, salin pola salah
satu berkas pada `chapters/`, lalu daftarkan dengan `#include` pada `main.typ`.

## Konvensi penulisan

- **Penomoran bab versus nomor modul.** Nomor bab berjalan 1, 2, 3, …, sedangkan
  label modul pada sumber tidak berurutan (00A, 00B, 01, …, 05B, 05C, …). Karena
  itu `supplement-chapter` diisi `"Bab"`, dan kode modul ditulis pada judul bab
  serta pada kotak `identitas-modul` di awal tiap bab.
- **Listing kode dibaca dari berkas, bukan diketik ulang.** Seluruh listing
  kode sumber memakai `kode-berkas("weekNN_x/src/.../main.cpp", ...)`, yang
  membaca isinya langsung dari `assets/code/` lewat `read()` bawaan Typst.
  Dengan begitu isi buku dijamin identik dengan berkas yang dijalankan di
  perangkat, dan tidak mungkin menyimpang akibat salah ketik. Gunakan `kode(...)`
  hanya untuk potongan yang memang tidak ada di repositori — misalnya varian
  `platformio.ini` yang diajarkan README dengan `upload_port` yang dipin, atau
  kerangka jawaban Challenge.
- **Memuat kode modul yang berkas sumbernya kembar.** Beberapa berkas identik
  antar modul (`partitions_ed.csv` dan `partitions_zczr.csv` pada M08/M09/M10,
  serta `http_sink.py` pada `tools/` dan `week13_.../`). Berkas seperti ini
  dimuat lengkap satu kali saja, lalu bab lain merujuknya dengan
  `@lst:...` disertai kalimat yang menyatakan keduanya identik — jangan mencetak
  listing yang sama dua kali.
- **Listing kode.** `kode(...)` bersifat tidak terpotong antar halaman. Untuk
  listing yang memang lebih panjang dari satu halaman, tambahkan `pecah: true`.
  Hal yang sama berlaku untuk `keluaran(...)`.
- **Diagram ASCII.** Dipertahankan apa adanya dari sumber melalui `diagram(...)`,
  memakai font DejaVu Sans Mono agar karakter penggambar kotak tampil benar.
  Tambahkan `rapat: true` hanya bila diagram lebih lebar dari sekitar 86 kolom.
- **Tabel pengamatan.** Sel yang harus diisi mahasiswa memakai `#isian` agar
  tinggi barisnya cukup untuk ditulis tangan.
- **Checklist.** Kotak centang digambar, bukan memakai karakter Unicode, supaya
  tampilannya tidak bergantung pada font yang terpasang.

## Kode sumber di dalam buku

Buku ini dirancang **berdiri sendiri**: seluruh berkas sumber setiap modul
dimuat lengkap di bagian *Kode Program* bab yang bersangkutan — 75 berkas,
mencakup tiap `platformio.ini`, tiap `main.cpp` per peran, tabel partisi Zigbee,
dan skrip bantu Python.

Salinannya disimpan di `assets/code/` dengan struktur yang sama persis dengan
repositori (`assets/code/week01_ble_p2p/src/node1/main.cpp` dan seterusnya),
dinormalisasi ke akhir baris LF. Karena `kode-berkas(...)` membacanya lewat
`read()` saat kompilasi, buku dapat dibangun tanpa folder `week*` di sebelahnya,
dan isi listing tidak mungkin melenceng dari berkas aslinya.

### Menyegarkan salinan kode

Setelah kode modul di repositori berubah, salin ulang lalu kompilasi:

```bash
# dijalankan dari akar repositori WSN-IOT-prak
rsync -a --delete \
  --include='*/' \
  --include='platformio.ini' --include='*.cpp' --include='*.h' \
  --include='*.csv' --include='*.py' --exclude='*' \
  week00_blinky week00_btn week0*_* week1*_* tools \
  Buku-Typst/assets/code/

cd Buku-Typst && typst compile main.typ
```

Verifikasi bahwa salinan masih identik dengan sumbernya sebelum menerbitkan
ulang; setiap berkas di `assets/code/` harus sama byte-per-byte dengan berkas
padanannya di repositori (setelah normalisasi CRLF menjadi LF).

### Rujukan ke GitHub

`lib/helpers.typ` menyimpan alamat repositori pada konstanta `REPO` beserta tiga
pembantu tautan:

| Fungsi | Kegunaan |
|---|---|
| `gh("week01_ble_p2p/src/node1/main.cpp")` | tautan ke satu berkas di GitHub |
| `gh-folder("week01_ble_p2p")` | tautan ke satu folder di GitHub |
| `sumber-kode(folder, (berkas, ...))` | kotak **KODE SUMBER** di awal bagian Kode Program |

Setiap bab modul membuka bagian *Kode Program* dengan satu panggilan
`sumber-kode(...)` yang mendaftarkan seluruh berkas modul itu. Bila alamat
repositori berubah, cukup ubah `REPO` pada `lib/helpers.typ` — seluruh tautan
di buku ikut menyesuaikan.

## Pemeriksaan mutu sebelum menerbitkan

1. `typst compile main.typ` selesai tanpa galat maupun peringatan.
2. Setiap berkas di `assets/code/` identik dengan sumbernya di repositori.
3. Setiap berkas di `assets/code/` dimuat oleh sebuah `kode-berkas(...)`, kecuali
   berkas kembar yang sudah dirujuk silang secara eksplisit di dalam teks.
4. Tidak ada teks yang menembus margin kanan atau bawah, dan tidak ada span teks
   yang bertumpuk (periksa dengan merender `main.pdf` lewat PyMuPDF).
5. Tidak ada baris di luar blok kode yang diawali `1.`, `+`, atau `/ ` secara
   tidak sengaja — pola itu ditafsirkan Typst sebagai daftar bernomor, daftar
   berpoin, atau daftar istilah.
