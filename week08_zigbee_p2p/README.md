```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
     MODUL 08 — Zigbee P2P: Join & Binding

     ESP32-H2 · ZIGBEE · ZC ↔ ZED · Level: Advanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 08 |
| Misi | Membentuk jaringan Zigbee, memasukkan satu end device ke dalamnya, dan mengendalikannya lewat binding |
| Platform | ESP32-H2 (Arduino core 3.x) + library `Zigbee` bawaan |
| Durasi | 3 × 50 menit |
| Mode | P2P Zigbee — Coordinator (switch) ↔ End Device (light) |
| Level | Advanced |
| Instrumen | Serial Monitor 115200 baud (2 terminal) + LED RGB bawaan |

## 2 · Keterkaitan Antar-Modul

Pada M07 frame disusun sendiri: tidak ada identitas jaringan, tidak ada keamanan, tidak ada penemuan perangkat. Zigbee menambahkan ketiganya di atas radio 802.15.4 yang **sama persis**. Yang menarik justru harga yang harus dibayar: firmware jauh lebih besar (butuh tabel partisi khusus), dan perangkat menyimpan keanggotaan jaringan di NVS — sesuatu yang tidak pernah jadi masalah di modul-modul BLE.

| | Cakupan |
|---|---|
| Prasyarat | M07 — channel, PAN ID, dan pemahaman bahwa Zigbee berjalan di radio 802.15.4 yang sama |
| Dibangun di modul ini | Pembentukan PAN, window join, find-and-bind, cluster ON/OFF, mode build ZCZR vs ED, tabel partisi Zigbee, NVS jaringan |
| Dipakai lagi di | M09 (satu coordinator, banyak end device — binding table) → M10 (router menambah hop) → M16 (Zigbee jadi salah satu protokol yang dibandingkan) |

**Peta modul blok Zigbee**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 07 | 802.15.4 telanjang — frame disusun manual |
| **08 (ini)** | **Jaringan Zigbee terbentuk: join, binding, cluster ON/OFF** |
| 09 | Satu coordinator melayani banyak end device (binding table) |
| 10 | Router menambah hop — routing multi-hop otomatis |

**Kontrak data lab ini.** Zigbee tidak mengirim "string", melainkan **perintah cluster standar** (`On/Off`). Perbedaan ini penting untuk M16: BLE dan Thread di lab ini mengirim payload bebas, Zigbee mengirim perintah baku. Catat konsekuensinya pada interoperabilitas — perangkat Zigbee merek berbeda bisa saling mengerti, payload BLE buatan sendiri tidak.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membentuk jaringan Zigbee dengan satu coordinator dan memasukkan satu end device melalui window join 180 detik, dibuktikan dari log kedua board.
2. Menjelaskan perbedaan **join** dan **binding** dengan menunjuk baris log yang menandai masing-masing tahap.
3. Mengukur waktu join + binding dan latency perintah ON/OFF (coordinator → LED berubah di end device) pada minimal 4 jarak.
4. Menjelaskan mengapa dua peran membutuhkan `build_flags` dan tabel partisi berbeda, serta akibatnya bila tertukar.

**Kriteria keberhasilan**

- ☐ Coordinator mencetak `End device ter-binding!`.
- ☐ LED RGB pada end device berubah ON/OFF tiap 5 detik mengikuti perintah.
- ☐ Waktu join + binding tercatat, minimal 3 percobaan.
- ☐ Tabel jarak–latency–success terisi dari pengukuran sendiri.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (ZDO, APS layer, key management, Zigbee Cluster Library lengkap) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Zigbee | Protokol jaringan di atas IEEE 802.15.4 untuk otomasi; dipakai lewat library `Zigbee` Arduino core 3.x. |
| Coordinator (ZC) | Membentuk dan mengelola PAN; build flag `-DZIGBEE_MODE_ZCZR`. |
| End Device (ZED) | Node akhir hemat daya, tidak meneruskan trafik; build flag `-DZIGBEE_MODE_ED`. |
| Endpoint | "Nomor kamar" fungsi di dalam satu perangkat: switch EP 5, light EP 10. |
| Join | End device masuk ke jaringan yang dibuka coordinator (`setRebootOpenNetwork(180)`). |
| Binding | Mengaitkan endpoint switch dengan endpoint light (find-and-bind) agar perintah punya tujuan. |
| Cluster ON/OFF | Perintah standar Zigbee untuk menyalakan/mematikan beban (`lightOn()` / `lightOff()`). |
| Partisi khusus | `partitions_zczr.csv` / `partitions_ed.csv` menyediakan `zb_storage` dan `zb_fct`. |
| NVS jaringan | Keanggotaan Zigbee disimpan di flash — bertahan melewati reset **dan** melewati flash ulang firmware. |

**Join ≠ binding.** Join membuat perangkat menjadi **anggota jaringan** (punya alamat, punya kunci). Binding membuat satu endpoint **tahu harus mengirim ke endpoint mana**. Perangkat bisa sudah join tetapi belum ter-binding — dan perintahnya tidak akan sampai ke mana pun. Dua tahap ini muncul sebagai dua baris log yang berbeda; pastikan keduanya dapat ditunjuk.

**Sekuens protokol yang diamati**

```
 Coordinator boot ──► Zigbee.begin(ZIGBEE_COORDINATOR)
    ──► network terbuka 180 s ──► ED join ──► find-and-bind switch↔light
    ──► loop 5 s: lightOn() / lightOff() ──► ED: setLED ON/OFF
```

## 5 · Topologi

```
          BOARD #1                              BOARD #2
+---------------------------+   perintah ON/OFF (5 s)   +---------------------------+
|        ESP32-H2           | ------------------------> |        ESP32-H2           |
| Coordinator (switch)      |   join + binding          | End Device (light)        |
| ZIGBEE_MODE_ZCZR          | <------------------------ | ZIGBEE_MODE_ED            |
| endpoint 5 (ZigbeeSwitch) |   laporan status lampu    | endpoint 10 (ZigbeeLight) |
+---------------------------+                           +---------------------------+
      env: coordinator                                       env: enddevice
```

| Node | Board | Environment | Peran | Endpoint |
|---|---|---|---|---|
| Coordinator | ESP32-H2 DevKitM-1 | `coordinator` | ZC + switch | EP 5 |
| End device | ESP32-H2 DevKitM-1 | `enddevice` | ZED + light | EP 10 |

Kedua peran memakai **ESP32-H2 DevKitM-1**. Perbedaannya hanya pada `build_flags` (`-DZIGBEE_MODE_ZCZR` vs `-DZIGBEE_MODE_ED`) dan tabel partisi — board-nya identik, jadi board mana pun bisa diberi peran mana pun.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1, **dengan LED RGB bawaan** (`RGB_BUILTIN`) | 2 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 3 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 4 | Platform PlatformIO | pioarduino `espressif32` 55.03.311 (library `Zigbee` bawaan core 3.x) | — |
| 5 | Tabel partisi | `partitions_zczr.csv` (ZC) dan `partitions_ed.csv` (ED) — sudah ada di folder modul | — |

**platformio.ini — dua peran, dua tabel partisi**

```ini
[env:coordinator]
build_src_filter = +<coordinator/*.cpp>
build_flags =
    -DZIGBEE_MODE_ZCZR
    -lesp_zb_api.zczr
    -lzboss_stack.zczr
    -lzboss_port.native
board_build.partitions = partitions_zczr.csv
upload_port  = /dev/ttyACM0
monitor_port = /dev/ttyACM0

[env:enddevice]
build_src_filter = +<enddevice/*.cpp>
build_flags =
    -DZIGBEE_MODE_ED
    -lesp_zb_api.ed
    -lzboss_stack.ed
    -lzboss_port.native
board_build.partitions = partitions_ed.csv
upload_port  = /dev/ttyACM1
monitor_port = /dev/ttyACM1
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, dua port dicatat dan diisikan di atas.
- ☐ **Hapus NVS kedua board sebelum flash pertama:** `pio run -d week08_zigbee_p2p -e enddevice -t erase`. Tanpa ini, board yang pernah join jaringan lain akan terus mencari koordinator lama.
- ☐ Environment `coordinator` (ZCZR) dan `enddevice` (ED) dikenali PlatformIO.
- ☐ Serial Monitor 115200 baud untuk kedua board.
- ☐ Endpoint dipahami: switch EP 5, light EP 10.
- ☐ Tidak ada jaringan Zigbee lain aktif di sekitar (hindari interferensi dan salah join).

**Deploy** — coordinator dulu, lalu end device **dalam 180 detik**:

```bash
pio run -d week08_zigbee_p2p -e enddevice   -t erase     # bersihkan NVS
pio run -d week08_zigbee_p2p -e coordinator -t erase
pio run -d week08_zigbee_p2p -e coordinator -t upload -t monitor
pio run -d week08_zigbee_p2p -e enddevice   -t upload    # jangan lewat 180 s
```

## 7 · Percobaan

### EXP-01 — Pembentukan Jaringan (Coordinator)

Unggah environment `coordinator`, buka Serial Monitor, verifikasi: coordinator membuka network 180 detik dan menunggu binding.

```
 boot ──► begin(ZIGBEE_COORDINATOR) OK
      ──► network terbuka 180 s
      ──► menunggu: . . . . . (titik tiap 500 ms)
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Pesan awal coordinator | |
| Lama network terbuka (s) | |
| Endpoint switch | |
| Perintah yang dikirim tiap 5 s | |

**Buka abstraksinya** — bandingkan ukuran firmware modul ini dengan modul BLE (lihat ringkasan `RAM/Flash` di akhir `pio run`). Lalu buka `partitions_zczr.csv` dan temukan partisi `zb_storage` dan `zb_fct`. Jawab: apa yang disimpan di sana, dan mengapa tabel partisi default Arduino tidak cukup?

> **CHECKPOINT** — Coordinator mencetak titik-titik `.` berulang. Jika langsung muncul `Zigbee gagal start!` lalu board restart, tabel partisi atau `build_flags` tidak cocok — perbaiki sebelum lanjut.

### EXP-02 — Join & Binding (End Device)

Unggah environment `enddevice` ke board kedua **sebelum 180 detik habis**. Amati proses join lalu binding, dan verifikasi RGB bawaan berkedip ON/OFF tiap 5 detik.

```
 ED boot ──► Zigbee.begin() ──► scan channel
          ──► join network ──► find & bind ke switch
 ZC loop 5 s: lightOn() … lightOff() … (bergantian)
```

**Expected output — Coordinator**

```
Menunggu end device ter-binding...
................
End device ter-binding!
Perintah: Lampu ON
Perintah: Lampu OFF
```

> Baris `Lampu sekarang: ...` berasal dari callback `onLightStateChange()`, yaitu **laporan balik** dari lampu ke switch. Pada firmware Arduino core 3.3.x baris ini tidak muncul karena `ZigbeeLight` tidak mengonfigurasi attribute reporting ke switch secara otomatis — perintah tetap sampai dan lampu tetap menyala. Mengaktifkan laporan balik justru menjadi CH-2.

**Expected output — End device**

```
Menunggu bergabung ke network koordinator...
Berhasil bergabung ke network!
Lampu ON
Lampu OFF
```

> **CHECKPOINT** — Dua hal harus terjadi berurutan: end device mencetak `Berhasil bergabung ke network!` (join), lalu coordinator mencetak `End device ter-binding!` (binding). Jika join berhasil tetapi binding tidak pernah terjadi, perintah tidak akan sampai — jangan lanjut, ulangi dengan menghapus NVS kedua board.

### EXP-03 — Keandalan Kontrol

1. Hitung siklus ON/OFF per menit (harapan 12) dan bandingkan status di kedua Serial Monitor.
2. Reset end device — catat waktu join ulang dan verifikasi apakah keanggotaan tersimpan (network terbuka lagi tiap coordinator reboot 180 s).
3. **Cabut daya coordinator selama 30 detik**, lalu nyalakan lagi. Amati apakah end device otomatis kembali atau perlu di-reset.
4. Geser jarak bertahap dan catat kapan perintah mulai tertinggal.

**Data capture**

| Parameter | Hasil |
|---|---|
| Siklus ON/OFF per menit | |
| Waktu join ulang setelah reset ED | |
| Perilaku saat coordinator mati lalu hidup | |
| Sinkron status ZC vs ED? | |
| Jarak mulai ada perintah tertinggal (m) | |

> **CHECKPOINT** — Praktikan dapat menjelaskan mengapa end device yang di-reset bisa kembali **tanpa** window join dibuka lagi (petunjuk: keanggotaan tersimpan di NVS, join hanya diperlukan sekali).

### Verifikasi hardware (log referensi)

Dijalankan pada 2 × **ESP32-H2 DevKitM-1** (flash di-erase lebih dulu agar tidak ada sisa jaringan Zigbee lama di NVS), capture 70 detik.

```
# Coordinator (ESP32-H2, ZCZR)         # End device (ESP32-H2, ED)
[0.401] Menunggu end device ...        [0.401] Menunggu bergabung ...
[3.407] ......                         [3.205] Berhasil bergabung ke network!
[3.407] End device ter-binding!
[5.209] Perintah: Lampu ON             [5.207] Lampu ON
[10.219] Perintah: Lampu OFF           [10.214] Lampu OFF
```

| Parameter | Hasil terukur |
|---|---|
| Waktu join + binding sejak boot | 3,4 s |
| Perintah dikirim coordinator | 13 |
| Aksi terjadi di end device | 13 (0 % loss) |
| Selisih waktu perintah → aksi | ≈ 2 ms |
| Siklus ON/OFF per menit | 12 |

## 8 · Pengukuran

| Jarak | RSSI (dBm) | Latency perintah (kasar) | Success ON/OFF (%) |
|---|---|---|---|
| 1 m | | | |
| 3 m | | | |
| 5 m | | | |
| 10 m | | | |
| 15 m | | | |

**Pengukuran per-node** (pengamatan 2 menit, jarak tetap):

| Node | Perintah terkirim | Aksi terlaksana | Loss (%) |
|---|---|---|---|
| Coordinator (switch) | | — | |
| End device (light) | — | | |

**Waktu join + binding** (minimal 3 percobaan, hapus NVS tiap kali):

| Percobaan | Waktu join (s) | Waktu binding (s) | Total (s) |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

**Bandingkan dengan M07.** Pada jarak yang sama, apakah success rate Zigbee lebih baik, sama, atau lebih buruk daripada raw 802.15.4? Radionya identik — jadi selisih apa pun berasal dari lapisan di atasnya.

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Bagaimana pengaruh jarak terhadap keberhasilan perintah ON/OFF diterima lampu?
2. Apakah latency perintah (ZC hingga LED berubah di ED) bertambah pada jarak jauh?
3. Berapa persen perintah gagal dalam 2 menit pengamatan, dan pola gagalnya bagaimana (acak atau berkelompok)?
4. Berapa waktu proses join + binding dari tiga percobaan, dan apa yang membuatnya bervariasi?
5. Apakah Zigbee (join/binding otomatis + enkripsi) lebih cocok untuk WSN dibanding raw 802.15.4 M07? Sebutkan apa yang diperoleh dan apa harga yang dibayar.

## 10 · Concept Check

1. Apa fungsi coordinator dalam jaringan Zigbee?
2. Apa perbedaan proses join dan binding? Bisakah salah satu terjadi tanpa yang lain?
3. Mengapa end device memakai partisi dan library berbeda (`partitions_ed.csv`, `esp_zb_api.ed`)?
4. Apa yang terjadi bila end device dinyalakan setelah window 180 detik berakhir, dan bagaimana cara memperbaikinya?
5. Mengapa `allowMultipleBinding(false)` dipakai pada skenario P2P ini, dan apa yang berubah di Modul 09?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Latency terukur.** Ukur latency perintah secara objektif: kirim timestamp di payload atau catat `millis()` saat `lightOn()` di coordinator dan saat `setLED()` di end device, lalu bandingkan. Lakukan 20 kali dan hitung rata-rata serta sebarannya.

- **CH-2 — Laporan balik (menutup celah `onLightStateChange`).** Aktifkan attribute reporting pada `ZigbeeLight` sehingga coordinator benar-benar mencetak `Lampu sekarang: ON/OFF`. Bandingkan jumlah perintah terkirim vs laporan diterima untuk menghitung loss arah balik.

- **CH-3 — Kontrol dari end device.** Tambahkan tombol pada end device yang mengirim perintah toggle ke coordinator. Diskusikan mengapa ini memerlukan binding arah sebaliknya.

- **CH-4 — Uji ketahanan NVS.** Flash ulang end device **tanpa** `-t erase`, lalu amati apakah ia langsung kembali ke jaringan. Jelaskan perbedaannya dengan perangkat BLE di M01–06 yang tidak menyimpan apa pun.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (Zigbee, ZC/ZED, endpoint, join vs binding, cluster ON/OFF)
3. Konfigurasi — `build_flags`, tabel partisi, endpoint, window join 180 s
4. Hasil eksperimen — log kedua board (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel jarak, tabel per-node, tabel waktu join+binding, perbandingan dengan M07
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
