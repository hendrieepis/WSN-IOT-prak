// ============================================================================
// Modul 03 — GATT Server & Client Terstruktur
// Sumber: week03_ble_client_server/README.md; listing kode dibaca langsung
//         dari salinan berkas sumber di assets/code/week03_ble_client_server/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 03 — GATT Server dan Client Terstruktur", l: "bab:modul-03")

#identitas-modul(
  "Modul 03",
  [Build a BLE Service --- GATT Server dan Client Terstruktur],
  [ESP32-H2 · BLE GATT · READ/WRITE · level Intermediate · 3 × 50 menit ·
   folder kode `week03_ble_client_server`],
)

#pengantar([Gambaran Umum])[
Modul 03 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya merancang service GATT sendiri, dengan satu characteristic berperan
sebagai data dan satu lagi sebagai kanal perintah. Percobaan berjalan dalam
mode client-server memakai operasi GATT read dan write, diamati melalui dua
terminal Serial Monitor pada 115200 baud, dengan nRF Connect sebagai pembanding
opsional.
]

== Pendahuluan

Modul 02 memindahkan _string_ bebas lewat dua characteristic. Modul ini
menaikkan satu tingkat abstraksi: characteristic tidak lagi sekadar pipa,
tetapi *mewakili keadaan perangkat* --- `CHAR_COUNTER` adalah nilai yang bisa
dibaca kapan saja, `CHAR_CMD` adalah kanal perintah. Inilah pola _sensor dan
aktuator_ yang nanti muncul lagi sebagai atribut Zigbee (M08) dan topic MQTT
(M14).

Prasyaratnya adalah M02: service, characteristic, property, dan pola callback
sudah dikenali. Yang dibangun di sini adalah rancangan service dengan dua
characteristic berbeda peran, akses `READ` on-demand oleh client, kanal
perintah `WRITE`, serta perbandingan biaya antara polling dan push. Rancangan
itu dipakai lagi pada M04 ketika characteristic yang sama diubah menjadi
push/notify, M08 pada perintah ON/OFF versi Zigbee, dan M14 ketika topic data
dipisahkan dari topic perintah pada MQTT.

*Peta modul blok BLE*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [01], [Tautan BLE P2P terbentuk dan stabil],
    [02], [Payload aplikasi mengalir dua arah],
    [*03 (ini)*], [*Characteristic mewakili state dan perintah --- bukan sekadar pipa*],
    [04], [State yang sama didorong berkala (notify), polling dihapus],
    [05], [Lebih dari dua node],
    [06], [Relay A→B→C],
  ),
  [Peta modul blok BLE],
  "tbl:m03-peta",
)

*Kontrak data lab ini.* Pemisahan *kanal data* (`CHAR_COUNTER`) dan *kanal
perintah* (`CHAR_CMD`) adalah pola yang dipertahankan sampai modul terakhir:
Zigbee memisahkannya menjadi cluster/endpoint, MQTT memisahkannya menjadi
`praktikum/h2/telemetri` dan `praktikum/h2/perintah`.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Merancang service GATT berisi data dan perintah])[
  + Merancang satu service GATT berisi dua characteristic dengan property
    berbeda (`READ` untuk data, `WRITE` untuk perintah) dan menjelaskan alasan
    pemisahannya.
  + Membaca nilai characteristic dari sisi client secara berkala
    (`readValue()`) dan membuktikan nilainya berubah mengikuti counter di
    server.
  + Mengirim perintah dari client ke server dan menunjukkan jejaknya di log
    server (`onWrite`).
  + Menghitung jumlah transaksi radio per menit pada skema polling dan
    membandingkannya dengan skema notify Modul 04 memakai angka sendiri.
]

*Kriteria keberhasilan*

#checklist((
  [Client mencetak `READ counter = <n>` tiap 2 detik dengan nilai yang naik.],
  [Selisih counter antar-read konsisten dengan rasio interval read banding
   interval counter.],
  [Server mencetak `Perintah dari client: ON` tiap 5 detik.],
  [Tabel jarak--RSSI--keberhasilan read terisi dari pengukuran sendiri.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (model
atribut GATT, ATT MTU, hubungan dengan Bluetooth SIG profile) berada di buku
teori terpisah. Istilah kerja dirangkum pada @tbl:m03-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [GATT Server], [Pihak yang *memiliki* data; di sini ESP32-H2 dengan counter.],
    [GATT Client], [Pihak yang *meminta* data; melakukan read dan write.],
    [Property READ], [Client boleh membaca nilai kapan saja atas inisiatifnya sendiri.],
    [Property WRITE], [Client boleh mengubah nilai; server bereaksi lewat `onWrite`.],
    [Polling], [Client membaca berulang pada interval tetap --- tiap read adalah satu transaksi radio.],
    [`readValue()`], [Permintaan baca dari client; server menjawab dengan nilai terkini.],
    [Handle / UUID], [Alamat characteristic di dalam service; UUID dipakai untuk mencarinya.],
  ),
  [Istilah kerja Modul 03],
  "tbl:m03-istilah",
)

*Mengapa counter, bukan sensor?* Counter naik 1 tiap 1000 ms secara pasti, jadi
nilai yang hilang atau read yang gagal langsung terlihat sebagai lompatan
angka. Sensor asli akan menyembunyikan kesalahan di balik fluktuasi nilai.

*Mengapa server hanya menaikkan counter saat ada client?* Agar nilai counter
merepresentasikan *lama koneksi*, bukan lama board menyala. Periksa
`src/server/main.cpp` dan tunjukkan baris yang menegakkan aturan ini.

*Sekuens protokol yang diamati*

#diagram(```
Server                                        Client
 counter++ tiap 1000 ms
        ◄───── READ CHAR_COUNTER (tiap 2000 ms) ─────
 kirim nilai ─────────────────────────────────►  "READ counter = 12"
        ◄───── WRITE "ON" ke CHAR_CMD (tiap 5000 ms) ─
 onWrite() → "Perintah dari client: ON"
```.text)

== Topologi

#diagram(```
      BOARD #1                            BOARD #2
┌──────────────────┐                  ┌──────────────────┐
│     ESP32-H2     │   READ counter   │     ESP32-H2     │
│    DevKitM-1     │ ◄──────────────  │    DevKitM-1     │
│  GATT Server     │                  │  GATT Client     │
│  (CHAR_COUNTER,  │  WRITE "ON"      │                  │
│   CHAR_CMD)      │ ──────────────►  │                  │
└──────────────────┘                  └──────────────────┘
     env: server                          env: client
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, auto, 1.2fr),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Aksi periodik]),
    [Server], [ESP32-H2 DevKitM-1], [`server`], [GATT Server (`GATT_SERVER`)],
    [counter++ tiap 1000 ms],
    [Client], [ESP32-H2 DevKitM-1], [`client`], [GATT Client (`GATT_CLIENT`)],
    [read tiap 2000 ms, write `ON` tiap 5000 ms],
  ),
  [Peran dan aksi periodik tiap node Modul 03],
  "tbl:m03-topologi",
)

Kedua peran berjalan di *ESP32-H2* memakai radio Bluetooth LE; ESP32-C6 baru
dipakai mulai Modul 13 (gateway Wi-Fi).

*Address map*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Objek], th[UUID]),
    [Service], [`4fafc201-1fb5-459e-8fcc-c5c9c331914b`],
    [CHAR_COUNTER (READ)], [`beb5483e-36e1-4688-b7f5-ea07361b26b0`],
    [CHAR_CMD (WRITE)], [`beb5483e-36e1-4688-b7f5-ea07361b26b1`],
  ),
  [Peta UUID Modul 03],
  "tbl:m03-uuid",
)

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan PlatformIO dan
pustaka NimBLE-Arduino.

#tbl(
  table(
    columns: (auto, 1fr, 1.3fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1], [2],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [3], [PC/Laptop], [PlatformIO Core/IDE, 2 port USB bebas], [1],
    [4], [Library NimBLE-Arduino], [`h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps`], [---],
    [5], [nRF Connect (opsional)], [Android/iOS --- untuk melihat struktur GATT dari luar], [1],
  ),
  [Alat dan bahan Modul 03],
  "tbl:m03-alat",
)

== Kode Program

#sumber-kode("week03_ble_client_server",
  ("platformio.ini", "src/server/main.cpp", "src/client/main.cpp"))

*Pin port agar tidak salah flash* (@lst:m03-ini-readme).

#kode(```ini
[env:server]
build_src_filter = +<server/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3  -- board Server
monitor_port = /dev/ttyACM0

[env:client]
build_src_filter = +<client/*.cpp>
upload_port  = /dev/ttyACM2     ; Windows: COM4  -- board Client
monitor_port = /dev/ttyACM2
```.text,
  [Potongan `platformio.ini` dengan port yang dipin per environment],
  "lst:m03-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week03_ble_client_server/platformio.ini",
  [`platformio.ini` Modul 03 pada repositori],
  "lst:m03-ini",
)

#kode-berkas("week03_ble_client_server/src/server/main.cpp",
  [`src/server/main.cpp` --- GATT Server dengan counter dan kanal perintah],
  "lst:m03-server",
  pecah: true,
)

#kode-berkas("week03_ble_client_server/src/client/main.cpp",
  [`src/client/main.cpp` --- GATT Client yang melakukan read dan write],
  "lst:m03-client",
  pecah: true,
)

== Build dan Flash

#keluaran("pio device list
pio run -d week03_ble_client_server -e server -t upload
pio run -d week03_ble_client_server -e client -t upload -t monitor")

#penting[
  *Pilih port USB-to-UART, bukan USB native.* Setiap board ESP32-H2 muncul
  sebagai *dua* port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan
  USB-Serial/JTAG bawaan chip (`303a:1001`). Proses flash pada lab ini memakai
  *jembatan UART*, karena jalur itulah yang tersambung ke rangkaian _auto
  program_ (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan
  tombol. Pada Linux keduanya berselang-seling: port *genap* adalah UART, port
  *ganjil* adalah USB native. Verifikasi dengan `pio device list` dan pilih
  port ber-Hardware ID `1A86:55D3`.
]

*Pre-flight checklist*

#checklist((
  [`pio device list` dijalankan, port tiap board dicatat dan diisikan di atas.],
  [Board pertama terhubung (env `server`), board kedua terhubung (env
   `client`).],
  [Firmware `server` dan `client` berhasil build tanpa galat.],
  [Dua Serial Monitor 115200 baud dibuka lebih dulu, lalu RESET kedua board.],
))

== Percobaan

=== EXP-01 --- Service Discovery

Client scan, connect, lalu mencari service dan kedua characteristic berdasarkan
UUID. Catat apa yang terjadi jika UUID tidak ditemukan (lihat penanganan
`nullptr` di `src/client/main.cpp`).

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama device server], [#isian],
    [Service UUID ditemukan], [#isian],
    [Characteristic ditemukan (jumlah dan UUID)], [#isian],
    [Waktu scan sampai `Koneksi berhasil` (s)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m03-exp01",
)

#buka-abstraksi[
  Buka `GATT_SERVER` dengan nRF Connect dan lihat daftar characteristic beserta
  property-nya (`READ`, `WRITE`). Cocokkan tiap baris di aplikasi dengan baris
  `createCharacteristic(...)` di `src/server/main.cpp`. Property yang muncul di
  aplikasi *berasal dari argumen kedua* fungsi itu --- ubah salah satunya
  menjadi `NIMBLE_PROPERTY::READ` saja lalu amati apa yang hilang di aplikasi.
]

#checkpoint[
  Client mencetak `Koneksi berhasil`. Jika muncul
  `Characteristic tidak ditemukan`, berarti UUID di client dan server berbeda
  --- samakan dulu sebelum lanjut.
]

=== EXP-02 --- Read: Client Menarik Data

Server menaikkan counter tiap 1000 ms *hanya saat ada client terhubung*. Client
membaca tiap 2000 ms.

*Expected output --- Server*

#keluaran("GATT Server starting...
Menunggu client...
Client terhubung")

*Expected output --- Client*

#keluaran("GATT Client starting...
Scanning server...
Server ditemukan
Terhubung ke server
Koneksi berhasil
READ counter = 2
READ counter = 4
READ counter = 6")

#checkpoint[
  Selisih dua `READ counter` berturut-turut adalah *2* (interval read 2000 ms
  dibagi interval counter 1000 ms). Jika selisihnya tidak konsisten, ada read
  yang gagal --- catat kejadiannya sebagai data pengukuran.
]

=== EXP-03 --- Write: Client Mengirim Perintah

Client menulis `"ON"` ke `CHAR_CMD` tiap 5000 ms; server mencetak
penerimaannya.

#diagram(```
Server: counter++ tiap 1000 ms
Client: READ  ─────────────► "READ counter = 12"
Client: WRITE "ON" ────────► Server: "Perintah dari client: ON"
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Interval read client (ms)], [2000],
    [Interval write client (ms)], [5000],
    [Interval update counter server (ms)], [1000],
    [Selisih nilai counter antar-read (rata-rata)], [#isian],
    [Perintah yang dikirim client], [ON],
    [Jumlah transaksi radio per menit (read dan write)], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m03-exp03",
)

#checkpoint[
  Baris `Perintah dari client: ON` muncul di server kira-kira tiap 5 detik, dan
  *di antara* dua baris itu ada 2--3 baris `READ counter` di client. Urutan
  inilah bukti dua kanal berjalan independen.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 2 × *ESP32-H2 DevKitM-1*, capture 25 detik.

#keluaran("# Server (ESP32-H2, env server)        # Client (ESP32-H2, env client)
[0.200] GATT Server starting...        [0.401] GATT Client starting...
[0.401] Menunggu client...             [0.401] Server ditemukan
[0.601] Client terhubung               [0.601] Terhubung ke server
[5.409] Perintah dari client: ON       [2.405] READ counter = 2
[10.418] Perintah dari client: ON      [4.408] READ counter = 4
                                       [5.409] WRITE perintah: ON
                                       [6.410] READ counter = 6")

#tbl(
  table(
    columns: (1.3fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Selisih counter antar-read], [2 (read 2000 ms dibagi counter 1000 ms)],
    [READ berhasil], [12 / 12],
    [WRITE `ON` sampai ke server], [4 / 4],
    [Transaksi radio per menit], [30 read + 12 write = 42],
  ),
  [Hasil verifikasi hardware Modul 03],
  "tbl:m03-verifikasi",
)

== Pengukuran

RSSI dibaca dari log client sendiri (`pClient->getRssi()`).

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[RSSI (dBm)], th[Interpretasi]),
    [> −70], [Kuat --- koneksi andal],
    [−70 s.d. −85], [Baik --- masih stabil],
    [−85 s.d. −95], [Marginal --- mulai rawan putus],
    [< −95], [Tidak reliable --- sering gagal],
  ),
  [Referensi interpretasi RSSI],
  "tbl:m03-referensi-rssi",
)

#tbl(
  table(
    columns: (auto, 0.95fr, 1.25fr, 1.25fr, 0.95fr),
    align: (left, left, left, left, left),
    inset: (x: 0.4em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak], th[RSSI (dBm)], th[READ /30 s (harapan 15)],
      th[WRITE /30 s (harapan 6)], th[Loss read (%)],
    ),
    [1 m], [#isian], [], [], [],
    [3 m], [#isian], [], [], [],
    [5 m], [#isian], [], [], [],
    [10 m], [#isian], [], [], [],
    [15 m], [#isian], [], [], [],
  ),
  [Lembar pengukuran keberhasilan read dan write Modul 03],
  "tbl:m03-ukur",
)

*Metrik turunan yang wajib dihitung:* jumlah transaksi radio per menit pada
skema polling ini. Angka ini akan dibandingkan langsung dengan skema notify
Modul 04.

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Bagaimana pengaruh jarak terhadap RSSI dan terhadap keberhasilan read?
+ Apakah read dan write mulai gagal pada jarak yang sama? Jika tidak, apa
  dugaan penyebabnya?
+ Berapa transaksi radio per menit yang dihasilkan skema polling ini? Berapa
  persen di antaranya membawa nilai counter yang *sama* dengan read sebelumnya
  (data mubazir)?
+ Jika interval read dipercepat menjadi 200 ms, berapa transaksi per menit dan
  apa dampaknya pada konsumsi daya client?
+ Untuk data yang jarang berubah, mana yang lebih efisien: polling atau notify?
  Dukung dengan angka dari poin sebelumnya.

== Concept Check

+ Apa perbedaan peran GATT Server dan GATT Client? Apakah server selalu yang
  mengirim data?
+ Mengapa satu service bisa memuat banyak characteristic dengan property
  berbeda?
+ Apa yang terjadi bila client melakukan read pada characteristic yang tidak
  punya property `READ`?
+ Mengapa server hanya menaikkan counter saat ada client terhubung, dan apa
  akibatnya jika aturan itu dihapus?
+ Dalam sistem nyata, mana yang lebih tepat memegang "state" perangkat: server
  atau client? Mengapa?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Perintah nyata dan status yang terbaca])[
  / CH-1 --- Perintah nyata: Ubah `CHAR_CMD` agar menerima `"ON"` dan `"OFF"`
    serta menyalakan atau mematikan LED bawaan server. Client mengirim keduanya
    bergantian.

  / CH-2 --- Characteristic status: Tambahkan characteristic ketiga (`READ`)
    berisi status LED, lalu buktikan dari client bahwa nilainya mengikuti
    perintah yang barusan dikirim.
]

#tujuan-prak(3, [Mengukur biaya polling dan memvalidasi masukan])[
  / CH-3 --- Ukur biaya polling: Hitung jumlah read per menit, lalu naikkan
    interval read ke 200 ms dan turunkan ke 10 detik. Catat untuk tiap kasus:
    transaksi per menit, jumlah nilai counter yang terlewat, dan jumlah read
    yang mubazir. Sajikan sebagai tabel.

  / CH-4 --- Validasi perintah: Tolak perintah selain `ON` dan `OFF` di
    `onWrite`, lalu cetak `Perintah tidak dikenal: <isi>`. Uji dengan mengirim
    string acak dari client.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (GATT server/client, property READ/WRITE, polling).
+ Konfigurasi --- `platformio.ini`, environment, UUID service dan
  characteristic.
+ Hasil eksperimen --- log kedua node (EXP-01 sampai EXP-03 beserta
  checkpoint).
+ Data pengukuran --- tabel bagian Pengukuran beserta hitungan transaksi per
  menit.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-3, sertakan tabel biaya polling.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
