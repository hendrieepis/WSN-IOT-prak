```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 03 — GATT Server & Client Terstruktur

   ESP32-H2 · BLE GATT · READ/WRITE · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan

Modul 03 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah. Misinya merancang service GATT sendiri, dengan satu characteristic berperan sebagai data dan satu lagi sebagai kanal perintah. Percobaan berjalan dalam mode client-server memakai operasi GATT read dan write, diamati melalui dua terminal Serial Monitor pada 115200 baud, dengan nRF Connect sebagai pembanding opsional.

Modul 02 memindahkan *string bebas* lewat dua characteristic. Modul ini menaikkan satu tingkat abstraksi: characteristic tidak lagi sekadar pipa, tetapi **mewakili keadaan perangkat** — `CHAR_COUNTER` adalah nilai yang bisa dibaca kapan saja, `CHAR_CMD` adalah kanal perintah. Inilah pola *sensor + aktuator* yang nanti muncul lagi sebagai atribut Zigbee (M08) dan topic MQTT (M14).

Prasyaratnya adalah M02: service, characteristic, property, dan pola callback sudah dikenali. Yang dibangun di sini adalah rancangan service dengan dua characteristic berbeda peran, akses `READ` on-demand oleh client, kanal perintah `WRITE`, serta perbandingan biaya antara polling dan push. Rancangan itu dipakai lagi pada M04 ketika characteristic yang sama diubah menjadi push/notify, M08 pada perintah ON/OFF versi Zigbee, dan M14 ketika topic data dipisahkan dari topic perintah pada MQTT.

**Peta modul blok BLE**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 01 | Tautan BLE P2P terbentuk & stabil |
| 02 | Payload aplikasi mengalir dua arah |
| **03 (ini)** | **Characteristic mewakili state & perintah — bukan sekadar pipa** |
| 04 | State yang sama didorong berkala (notify), polling dihapus |
| 05 | Lebih dari dua node |
| 06 | Relay A→B→C |

**Kontrak data lab ini.** Pemisahan **kanal data** (`CHAR_COUNTER`) dan **kanal perintah** (`CHAR_CMD`) adalah pola yang dipertahankan sampai modul terakhir: Zigbee memisahkannya jadi cluster/endpoint, MQTT memisahkannya jadi `praktikum/h2/telemetri` dan `praktikum/h2/perintah`.

## 2 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Merancang satu service GATT berisi dua characteristic dengan property berbeda (`READ` untuk data, `WRITE` untuk perintah) dan menjelaskan alasan pemisahannya.
2. Membaca nilai characteristic dari sisi client secara berkala (`readValue()`) dan membuktikan nilainya berubah mengikuti counter di server.
3. Mengirim perintah dari client ke server dan menunjukkan jejaknya di log server (`onWrite`).
4. Menghitung jumlah transaksi radio per menit pada skema polling dan membandingkannya dengan skema notify Modul 04 memakai angka sendiri.

**Kriteria keberhasilan**

- ☐ Client mencetak `READ counter = <n>` tiap 2 detik dengan nilai yang naik.
- ☐ Selisih counter antar-read konsisten dengan rasio interval read : interval counter.
- ☐ Server mencetak `Perintah dari client: ON` tiap 5 detik.
- ☐ Tabel jarak–RSSI–keberhasilan read terisi dari pengukuran sendiri.

## 3 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (model atribut GATT, ATT MTU, hubungan dengan Bluetooth SIG profile) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| GATT Server | Pihak yang **memiliki** data; di sini ESP32-H2 dengan counter. |
| GATT Client | Pihak yang **meminta** data; melakukan read dan write. |
| Property READ | Client boleh membaca nilai kapan saja atas inisiatifnya sendiri. |
| Property WRITE | Client boleh mengubah nilai; server bereaksi lewat `onWrite`. |
| Polling | Client membaca berulang pada interval tetap — tiap read adalah satu transaksi radio. |
| `readValue()` | Permintaan baca dari client; server menjawab dengan nilai terkini. |
| Handle / UUID | Alamat characteristic di dalam service; UUID dipakai untuk mencarinya. |

**Mengapa counter, bukan sensor?** Counter naik 1 tiap 1000 ms secara pasti, jadi nilai yang hilang atau read yang gagal langsung terlihat sebagai lompatan angka. Sensor asli akan menyembunyikan kesalahan di balik fluktuasi nilai.

**Mengapa server hanya menaikkan counter saat ada client?** Agar nilai counter merepresentasikan **lama koneksi**, bukan lama board menyala — periksa `src/server/main.cpp` dan tunjukkan baris yang menegakkan aturan ini.

**Sekuens protokol yang diamati**

```
Server                                        Client
 counter++ tiap 1000 ms
        ◄───── READ CHAR_COUNTER (tiap 2000 ms) ─────
 kirim nilai ─────────────────────────────────►  "READ counter = 12"
        ◄───── WRITE "ON" ke CHAR_CMD (tiap 5000 ms) ─
 onWrite() → "Perintah dari client: ON"
```

## 4 · Topologi

```
      BOARD #1                            BOARD #2
┌──────────────────┐                  ┌──────────────────┐
│     ESP32-H2     │   READ counter   │     ESP32-H2     │
│    DevKitM-1     │ ◄──────────────  │    DevKitM-1     │
│  GATT Server     │                  │  GATT Client     │
│  (CHAR_COUNTER,  │  WRITE "ON"      │                  │
│   CHAR_CMD)      │ ──────────────►  │                  │
└──────────────────┘                  └──────────────────┘
     env: server                          env: client
```

| Node | Board | Environment | Peran | Aksi periodik |
|---|---|---|---|---|
| Server | ESP32-H2 DevKitM-1 | `server` | GATT Server (`GATT_SERVER`) | counter++ tiap 1000 ms |
| Client | ESP32-H2 DevKitM-1 | `client` | GATT Client (`GATT_CLIENT`) | read tiap 2000 ms, write `ON` tiap 5000 ms |

Kedua peran berjalan di **ESP32-H2** memakai radio Bluetooth LE; ESP32-C6 baru dipakai mulai Modul 13 (gateway Wi-Fi).

**Address map**

| Objek | UUID |
|---|---|
| Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| CHAR_COUNTER (READ) | `beb5483e-36e1-4688-b7f5-ea07361b26b0` |
| CHAR_CMD (WRITE) | `beb5483e-36e1-4688-b7f5-ea07361b26b1` |

## 5 · Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino.

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 2 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 3 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 4 | Library NimBLE-Arduino | `h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps` | — |
| 5 | nRF Connect (opsional) | Android/iOS — untuk melihat struktur GATT dari luar | 1 |

**platformio.ini — pin port agar tidak salah flash**

```ini
[env:server]
build_src_filter = +<server/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3  -- board Server
monitor_port = /dev/ttyACM0

[env:client]
build_src_filter = +<client/*.cpp>
upload_port  = /dev/ttyACM2     ; Windows: COM4  -- board Client
monitor_port = /dev/ttyACM2
```

> **Pilih port USB-to-UART, bukan USB native.** Setiap board ESP32-H2 muncul sebagai **dua** port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan USB-Serial/JTAG bawaan chip (`303a:1001`). Proses flash pada lab ini memakai **jembatan UART**, karena jalur itulah yang tersambung ke rangkaian *auto program* (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan tombol. Pada Linux keduanya berselang-seling: port **genap** adalah UART, port **ganjil** adalah USB native. Dengan demikian satu board memakai `/dev/ttyACM0`, dua board memakai `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board memakai `/dev/ttyACM0`, `/dev/ttyACM2`, dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port ber-Hardware ID `1A86:55D3`.

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, port tiap board dicatat dan diisikan di atas.
- ☐ Board pertama terhubung (env `server`), board kedua terhubung (env `client`).
- ☐ Firmware `server` dan `client` berhasil build tanpa error.
- ☐ Dua Serial Monitor 115200 baud dibuka lebih dulu, lalu RESET kedua board.

**Deploy**

```bash
pio device list
pio run -d week03_ble_client_server -e server -t upload
pio run -d week03_ble_client_server -e client -t upload -t monitor
```

## 6 · Percobaan

### EXP-01 — Service Discovery

Client scan, connect, lalu mencari service dan kedua characteristic berdasarkan UUID. Catat apa yang terjadi jika UUID tidak ditemukan (lihat penanganan `nullptr` di `src/client/main.cpp`).

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama device server | |
| Service UUID ditemukan | |
| Characteristic ditemukan (jumlah & UUID) | |
| Waktu scan → `Koneksi berhasil` (s) | |

**Buka abstraksinya** — buka `NODE`/`GATT_SERVER` dengan nRF Connect dan lihat daftar characteristic beserta property-nya (`READ`, `WRITE`). Cocokkan tiap baris di aplikasi dengan baris `createCharacteristic(...)` di `src/server/main.cpp`. Property yang muncul di aplikasi **berasal dari argumen kedua** fungsi itu — ubah salah satunya jadi `NIMBLE_PROPERTY::READ` saja lalu amati apa yang hilang di aplikasi.

> **CHECKPOINT** — Client mencetak `Koneksi berhasil`. Jika muncul `Characteristic tidak ditemukan`, berarti UUID di client dan server berbeda — samakan dulu sebelum lanjut.

### EXP-02 — Read: Client Menarik Data

Server menaikkan counter tiap 1000 ms **hanya saat ada client terhubung**. Client membaca tiap 2000 ms.

**Expected output — Server**

```
GATT Server starting...
Menunggu client...
Client terhubung
```

**Expected output — Client**

```
GATT Client starting...
Scanning server...
Server ditemukan
Terhubung ke server
Koneksi berhasil
READ counter = 2
READ counter = 4
READ counter = 6
```

> **CHECKPOINT** — Selisih dua `READ counter` berturut-turut adalah **2** (interval read 2000 ms ÷ interval counter 1000 ms). Jika selisihnya tidak konsisten, ada read yang gagal — catat kejadiannya sebagai data pengukuran.

### EXP-03 — Write: Client Mengirim Perintah

Client menulis `"ON"` ke `CHAR_CMD` tiap 5000 ms; server mencetak penerimaannya.

```
Server: counter++ tiap 1000 ms
Client: READ  ─────────────► "READ counter = 12"
Client: WRITE "ON" ────────► Server: "Perintah dari client: ON"
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Interval read client (ms) | 2000 |
| Interval write client (ms) | 5000 |
| Interval update counter server (ms) | 1000 |
| Selisih nilai counter antar-read (rata-rata) | |
| Perintah yang dikirim client | ON |
| Jumlah transaksi radio per menit (read + write) | |

> **CHECKPOINT** — Baris `Perintah dari client: ON` muncul di server kira-kira tiap 5 detik, dan **di antara** dua baris itu ada 2–3 baris `READ counter` di client. Urutan inilah bukti dua kanal berjalan independen.

### Verifikasi hardware (log referensi)

Dijalankan pada 2 × **ESP32-H2 DevKitM-1**, capture 25 detik.

```
# Server (ESP32-H2, env server)        # Client (ESP32-H2, env client)
[0.200] GATT Server starting...        [0.401] GATT Client starting...
[0.401] Menunggu client...             [0.401] Server ditemukan
[0.601] Client terhubung               [0.601] Terhubung ke server
[5.409] Perintah dari client: ON       [2.405] READ counter = 2
[10.418] Perintah dari client: ON      [4.408] READ counter = 4
                                       [5.409] WRITE perintah: ON
                                       [6.410] READ counter = 6
```

| Parameter | Hasil terukur |
|---|---|
| Selisih counter antar-read | 2 (read 2000 ms ÷ counter 1000 ms) |
| READ berhasil | 12 / 12 |
| WRITE `ON` sampai ke server | 4 / 4 |
| Transaksi radio per menit | 30 read + 12 write = 42 |

## 7 · Pengukuran

RSSI dibaca dari log client sendiri (`pClient->getRssi()`).

| RSSI (dBm) | Interpretasi |
|---|---|
| > −70 | Kuat — koneksi andal |
| −70 s/d −85 | Baik — masih stabil |
| −85 s/d −95 | Marginal — mulai rawan putus |
| < −95 | Tidak reliable — sering gagal |

| Jarak | RSSI (dBm) | READ berhasil /30 s (harapan 15) | WRITE berhasil /30 s (harapan 6) | Loss read (%) |
|---|---|---|---|---|
| 1 m | | | | |
| 3 m | | | | |
| 5 m | | | | |
| 10 m | | | | |
| 15 m | | | | |

**Metrik turunan yang wajib dihitung:** jumlah transaksi radio per menit pada skema polling ini. Angka ini akan dibandingkan langsung dengan skema notify Modul 04.

## 8 · Analisis

Jawab berdasarkan tabel bagian Pengukuran:

1. Bagaimana pengaruh jarak terhadap RSSI dan terhadap keberhasilan read?
2. Apakah read dan write mulai gagal pada jarak yang sama? Jika tidak, apa dugaan penyebabnya?
3. Berapa transaksi radio per menit yang dihasilkan skema polling ini? Berapa persen di antaranya membawa nilai counter yang **sama** dengan read sebelumnya (data mubazir)?
4. Jika interval read dipercepat jadi 200 ms, berapa transaksi per menit dan apa dampaknya pada konsumsi daya client?
5. Untuk data yang jarang berubah, mana yang lebih efisien: polling atau notify? Dukung dengan angka dari poin 3.

## 9 · Concept Check

1. Apa perbedaan peran GATT Server dan GATT Client? Apakah server selalu yang mengirim data?
2. Mengapa satu service bisa memuat banyak characteristic dengan property berbeda?
3. Apa yang terjadi bila client melakukan read pada characteristic yang tidak punya property `READ`?
4. Mengapa server hanya menaikkan counter saat ada client terhubung, dan apa akibatnya jika aturan itu dihapus?
5. Dalam sistem nyata, mana yang lebih tepat memegang "state" perangkat: server atau client? Mengapa?

## 10 · Challenge (tugas modifikasi)

- **CH-1 — Perintah nyata.** Ubah `CHAR_CMD` agar menerima `"ON"`/`"OFF"` dan menyalakan/mematikan LED bawaan server. Client mengirim keduanya bergantian.

- **CH-2 — Characteristic status.** Tambahkan characteristic ketiga (`READ`) berisi status LED, lalu buktikan dari client bahwa nilainya mengikuti perintah yang barusan dikirim.

- **CH-3 — Ukur biaya polling.** Hitung jumlah read per menit, lalu naikkan interval read ke 200 ms dan turunkan ke 10 detik. Catat untuk tiap kasus: transaksi/menit, jumlah nilai counter yang terlewat, dan jumlah read yang mubazir. Sajikan sebagai tabel.

- **CH-4 — Validasi perintah.** Tolak perintah selain `ON`/`OFF` di `onWrite` dan cetak `Perintah tidak dikenal: <isi>`. Uji dengan mengirim string acak dari client.

## 11 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (GATT server/client, property READ/WRITE, polling)
3. Konfigurasi — `platformio.ini`, environment, UUID service & characteristic
4. Hasil eksperimen — log kedua node (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel bagian Pengukuran + hitungan transaksi/menit
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-3, sertakan tabel biaya polling
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
