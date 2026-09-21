// ============================================================================
// Modul 04 — Telemetry Berkala lewat Notify
// Sumber: week04_ble_telemetry/README.md; listing kode dibaca langsung dari
//         salinan berkas sumber di assets/code/week04_ble_telemetry/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 04 — Telemetry Berkala lewat Notify", l: "bab:modul-04")

#identitas-modul(
  "Modul 04",
  [Stream Telemetry --- Telemetry Berkala lewat Notify],
  [ESP32-H2 · BLE NOTIFY · TELEMETRY · level Intermediate · 3 × 50 menit ·
   folder kode `week04_ble_telemetry`],
)

#pengantar([Gambaran Umum])[
Modul 04 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya mengubah pola tarik (polling) menjadi pola dorong (notify), lalu
membuktikan penghematannya dengan angka. Percobaan berjalan sebagai telemetry
satu arah dari sensor yang berperan sebagai server menuju monitor yang berperan
sebagai client, diamati melalui dua terminal Serial Monitor pada 115200 baud.
]

== Pendahuluan

Modul 03 membuat client *menarik* data berulang-ulang, sebagian besar mubazir.
Modul ini membalik arah inisiatif: sensor mendorong nilai baru begitu tersedia,
monitor hanya menunggu. Pola inilah yang dipakai semua telemetri di sisa lab
--- Zigbee attribute report (M09), Thread UDP periodik (M11--M13), dan MQTT
publish (M14). Angka transaksi per menit yang dihitung pada M03 dipakai lagi di
sini sebagai pembanding.

Prasyaratnya adalah M03: service GATT dan hitungan transaksi radio pada skema
polling. Yang dibangun di sini adalah notify sebagai telemetry berkala,
mekanisme subscribe dari sisi client, pengamatan kontinuitas aliran data, dan
perilaku sistem saat pengirim mati lalu hidup kembali. Keempatnya dipakai lagi
pada M05 ketika satu central menerima notify dari banyak sensor, M06 ketika
notify diteruskan hop demi hop, serta M14 dan M15 ketika telemetri yang sama
berakhir di broker MQTT.

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
    [03], [Characteristic mewakili state dan perintah (polling)],
    [*04 (ini)*], [*Polling dihapus --- sensor mendorong data sendiri (notify)*],
    [05], [Lebih dari dua node],
    [06], [Relay A→B→C],
  ),
  [Peta modul blok BLE],
  "tbl:m04-peta",
)

*Kontrak data lab ini.* Payload telemetri di lab ini selalu berupa *nilai
terukur dalam bentuk string ringkas* (`"26.3"`, nanti `"suhu:26.3"`). Format
itu dipertahankan agar hop terakhir --- publish MQTT di M14/M15 --- tidak perlu
mengubah isinya sama sekali (_transparent forwarding_).

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Mengganti polling dengan telemetry berbasis notify])[
  + Mengimplementasikan characteristic `NOTIFY` yang mengirim nilai sensor tiap
    1000 ms hanya saat ada client yang subscribe.
  + Membuktikan dari log bahwa monitor tidak melakukan satu pun permintaan
    baca, namun tetap menerima seluruh nilai.
  + Menghitung jumlah transaksi radio per menit skema notify dan
    membandingkannya dengan skema polling Modul 03 dalam satu tabel.
  + Menjelaskan perilaku sistem saat sensor mati mendadak, berdasarkan log
    kedua node --- bukan berdasarkan dugaan.
]

*Kriteria keberhasilan*

#checklist((
  [Monitor menerima ± 60 nilai per menit tanpa pernah memanggil
   `readValue()`.],
  [Interval kedatangan terukur ± 1000 ms dan tercatat sebarannya.],
  [Uji gangguan (sensor di-reset) dilakukan dan perilaku kedua node tercatat.],
  [Tabel perbandingan polling (M03) dan notify (M04) terisi dari angka
   sendiri.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (siklus
connection event BLE, hubungan interval notify dengan konsumsi arus) berada di
buku teori terpisah. Istilah kerja dirangkum pada @tbl:m04-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Telemetry], [Pengiriman nilai terukur dari perangkat ke pemantau secara berkala.],
    [Notify], [Server mendorong nilai ke client tanpa diminta, tanpa acknowledgement.],
    [Indication], [Seperti notify tetapi menunggu balasan client --- lebih andal, lebih mahal. Tidak dipakai di sini.],
    [Subscribe / CCCD], [Client mengaktifkan notify; tanpa langkah ini `notify()` di server tidak berefek apa pun.],
    [Push dan pull], [Push berarti pengirim menentukan kapan data dikirim; pull berarti penerima yang meminta (M03).],
    [Sensor simulasi], [Nilai suhu dibangkitkan `random()`, mulai 25,0 °C, fluktuasi ±1,0 °C, reset ke 25,0 bila keluar rentang 20--40 °C.],
  ),
  [Istilah kerja Modul 04],
  "tbl:m04-istilah",
)

*Mengapa sensornya disimulasi?* Karena yang diuji modul ini adalah *kanal
telemetri*, bukan akurasi sensor. Nilai simulasi menghilangkan variabel
kalibrasi sehingga setiap kelainan pada log pasti berasal dari kanal radio.
Mengganti `readSensor()` dengan sensor asli adalah CH-3.

*Sekuens protokol yang diamati*

#diagram(```
Sensor (Server)                          Monitor (Client)
  advertise TELEM_SENSOR
        ◄──── connect + subscribe(CCCD) ────
  tiap 1000 ms:
    readSensor() → "26.3"
    notify() ────────────────────────────►  onNotify() → cetak
  (tidak ada permintaan baca sama sekali dari monitor)
```.text)

== Topologi

#diagram(```
      BOARD #1                            BOARD #2
┌──────────────────┐   NOTIFY suhu   ┌──────────────────┐
│     ESP32-H2     │ ──────────────► │     ESP32-H2     │
│    DevKitM-1     │   tiap 1 detik  │    DevKitM-1     │
│  Sensor Node     │                 │  Monitor Node    │
│  (TELEM_SENSOR)  │                 │ (TELEM_MONITOR)  │
└──────────────────┘                 └──────────────────┘
     env: sensor                         env: monitor
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, auto, 1.1fr),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Aksi]),
    [Sensor], [ESP32-H2 DevKitM-1], [`sensor`], [GATT Server (`TELEM_SENSOR`)],
    [notify suhu tiap 1000 ms],
    [Monitor], [ESP32-H2 DevKitM-1], [`monitor`], [GATT Client (`TELEM_MONITOR`)],
    [subscribe dan cetak tiap notifikasi],
  ),
  [Peran tiap node Modul 04],
  "tbl:m04-topologi",
)

Keduanya *ESP32-H2* (radio Bluetooth LE). Tidak ada ESP32-C6 pada modul ini.

*Address map*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Objek], th[UUID]),
    [Service], [`4fafc201-1fb5-459e-8fcc-c5c9c331914b`],
    [CHAR telemetry (NOTIFY)], [`beb5483e-36e1-4688-b7f5-ea07361b26b2`],
  ),
  [Peta UUID Modul 04],
  "tbl:m04-uuid",
)

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan PlatformIO dan
pustaka NimBLE-Arduino.

#tbl(
  table(
    columns: (auto, 1fr, 1.5fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1], [2],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [3], [PC/Laptop], [PlatformIO Core/IDE, 2 port USB bebas], [1],
    [4], [Library NimBLE-Arduino], [`h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps`], [---],
    [5], [Data Modul 03], [tabel transaksi per menit skema polling --- dipakai sebagai pembanding], [1],
  ),
  [Alat dan bahan Modul 04],
  "tbl:m04-alat",
)

#catatan[
  Suhu pada kode adalah *simulasi* (`random`), tidak memakai sensor fisik.
]

== Kode Program

#sumber-kode("week04_ble_telemetry",
  ("platformio.ini", "src/sensor/main.cpp", "src/monitor/main.cpp"))

*Pin port agar tidak salah flash* (@lst:m04-ini-readme).

#kode(```ini
[env:sensor]
build_src_filter = +<sensor/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3  -- board Sensor
monitor_port = /dev/ttyACM0

[env:monitor]
build_src_filter = +<monitor/*.cpp>
upload_port  = /dev/ttyACM2     ; Windows: COM4  -- board Monitor
monitor_port = /dev/ttyACM2
```.text,
  [Potongan `platformio.ini` dengan port yang dipin per environment],
  "lst:m04-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week04_ble_telemetry/platformio.ini",
  [`platformio.ini` Modul 04 pada repositori],
  "lst:m04-ini",
)

#kode-berkas("week04_ble_telemetry/src/sensor/main.cpp",
  [`src/sensor/main.cpp` --- sensor node yang mendorong telemetri],
  "lst:m04-sensor",
  pecah: true,
)

#kode-berkas("week04_ble_telemetry/src/monitor/main.cpp",
  [`src/monitor/main.cpp` --- monitor node yang hanya subscribe],
  "lst:m04-monitor",
  pecah: true,
)

== Build dan Flash

#keluaran("pio device list
pio run -d week04_ble_telemetry -e sensor  -t upload
pio run -d week04_ble_telemetry -e monitor -t upload -t monitor")

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
  [Board pertama terhubung (env `sensor`), board kedua terhubung (env
   `monitor`).],
  [Firmware `sensor` dan `monitor` berhasil build tanpa galat.],
  [Dua Serial Monitor 115200 baud dibuka lebih dulu, lalu RESET kedua board.],
  [Angka transaksi per menit dari Modul 03 sudah di tangan.],
))

== Percobaan

=== EXP-01 --- Subscribe dan Stream Start

Monitor scan, connect, lalu subscribe. Aliran data baru dimulai *setelah*
subscribe berhasil --- bukan setelah connect.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama device sensor], [#isian],
    [Waktu scan sampai `Koneksi berhasil` (s)], [#isian],
    [Waktu connect sampai nilai pertama tiba (s)], [#isian],
    [Apakah ada `readValue()` di kode monitor? (ya/tidak)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m04-exp01",
)

#buka-abstraksi[
  Sebelum lanjut, komentari baris `pTx->subscribe(...)` di
  `src/monitor/main.cpp`, flash ulang, dan amati: koneksi tetap terbentuk,
  sensor tetap memanggil `notify()`, tetapi monitor *tidak menerima apa pun*.
  Kembalikan kodenya. Ini membuktikan notify bukan sekadar "server mengirim",
  melainkan kontrak dua pihak yang dicatat di CCCD.
]

#checkpoint[
  Monitor mencetak `Koneksi berhasil, menunggu telemetry...` lalu baris
  `Telemetry diterima` pertama muncul kurang dari 1,5 detik kemudian. Jika
  baris kedua tidak pernah muncul, subscribe gagal --- periksa dulu.
]

=== EXP-02 --- Aliran Telemetri

Sensor mengirim nilai tiap 1000 ms selama monitor terhubung.

*Expected output --- Sensor*

#keluaran("Sensor Node starting...
Menunggu monitor...
Monitor terhubung
Notify: suhu = 25.3 C
Notify: suhu = 26.1 C")

*Expected output --- Monitor*

#keluaran("Monitor Node starting...
Scanning sensor...
Sensor ditemukan
Terhubung ke sensor
Koneksi berhasil, menunggu telemetry...
Telemetry diterima: suhu = 25.3 C
Telemetry diterima: suhu = 26.1 C")

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Interval notify (ms)], [1000],
    [Format payload], [`s.d` (contoh: 26.3)],
    [Rentang nilai suhu teramati (°C)], [#isian],
    [Jumlah telemetry diterima per 60 detik], [#isian],
    [Interval kedatangan terkecil dan terbesar (ms)], [#isian],
  ),
  [Lembar pengamatan EXP-02],
  "tbl:m04-exp02",
)

#checkpoint[
  Tiap nilai `Notify:` di sensor punya pasangan `Telemetry diterima:` di
  monitor dengan angka yang sama persis. Cocokkan minimal 10 baris
  berturut-turut sebelum masuk EXP-03.
]

=== EXP-03 --- Kontinuitas dan Pemulihan

+ Reset sensor selama ± 5 detik lalu nyalakan lagi. Amati
  `Monitor terputus, advertise ulang` di sensor dan apa yang dilakukan monitor.
+ Catat apakah aliran pulih sendiri atau monitor perlu di-reset, dan
  *jelaskan dari kode* mengapa demikian.
+ Jauhkan sensor perlahan sampai ada nilai yang hilang; catat interval
  kedatangan saat mulai tidak teratur.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Pesan di sensor saat monitor hilang], [#isian],
    [Pesan di monitor saat sensor hilang], [#isian],
    [Aliran pulih otomatis? (ya/tidak)], [#isian],
    [Alasan berdasarkan kode], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m04-exp03",
)

#checkpoint[
  Praktikan dapat menunjukkan baris kode yang menentukan apakah monitor
  melakukan scan ulang atau tidak. Jika belum bisa, jangan lanjut ke analisis
  --- jawabannya ada di `setup()` monitor.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 2 × *ESP32-H2 DevKitM-1*, capture 25 detik.

#keluaran("# Sensor (ESP32-H2, env sensor)        # Monitor (ESP32-H2, env monitor)
[1.404] Notify: suhu = 24.3 C          [1.405] Telemetry diterima: suhu = 24.3 C
[2.406] Notify: suhu = 23.4 C          [2.407] Telemetry diterima: suhu = 23.4 C
[3.407] Notify: suhu = 23.8 C          [3.409] Telemetry diterima: suhu = 23.8 C")

#tbl(
  table(
    columns: (1.3fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Notify dikirim sensor], [24],
    [Telemetry diterima monitor], [24 (0 % loss)],
    [Interval kedatangan], [1001 ± 2 ms],
    [Rentang suhu teramati], [21,3 -- 24,3 °C],
    [Selisih waktu sensor ke monitor], [1--2 ms],
  ),
  [Hasil verifikasi hardware Modul 04],
  "tbl:m04-verifikasi",
)

== Pengukuran

#tbl(
  table(
    columns: (auto, 0.95fr, 1.5fr, 0.8fr, 1.1fr),
    align: (left, left, left, left, left),
    inset: (x: 0.4em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak], th[RSSI (dBm)], th[Telemetry /60 s (harapan 60)],
      th[Loss (%)], th[Interval terbesar (ms)],
    ),
    [1 m], [#isian], [], [], [],
    [3 m], [#isian], [], [], [],
    [5 m], [#isian], [], [], [],
    [10 m], [#isian], [], [], [],
    [15 m], [#isian], [], [], [],
  ),
  [Lembar pengukuran aliran telemetri Modul 04],
  "tbl:m04-ukur",
)

*Tabel pembanding wajib --- polling (M03) dan notify (M04).* Isi kolom kiri
dari data Modul 03 dan kolom kanan dari modul ini.

#tbl(
  table(
    columns: (1.5fr, 1fr, 1fr),
    align: (left, left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Aspek], th[Polling (M03)], th[Notify (M04)]),
    [Transaksi radio per menit], [#isian], [],
    [Nilai baru yang benar-benar terbawa per menit], [#isian], [],
    [Transaksi mubazir (nilai tak berubah) per menit], [#isian], [],
    [Siapa yang menentukan waktu kirim], [client], [sensor],
    [Konsekuensi bila data jarang berubah], [#isian], [],
  ),
  [Tabel pembanding polling dan notify],
  "tbl:m04-banding",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Berapa jumlah telemetry yang diterima per menit, dan berapa persen dari nilai
  yang dikirim sensor?
+ Bandingkan transaksi radio per menit skema polling dan notify dari tabel
  pembanding. Berapa persen penghematannya?
+ Pada jarak berapa interval kedatangan mulai tidak teratur, dan bagaimana
  bentuk ketidakteraturannya (melar atau melompat)?
+ Jika data hanya berubah tiap 10 detik, skema mana yang lebih boros? Tunjukkan
  dengan angka.
+ Apa risiko notify dibanding indication untuk data yang tidak boleh hilang,
  misalnya alarm?

== Concept Check

+ Apa beda notify dan indication, dan kapan masing-masing dipakai?
+ Mengapa `notify()` tidak berefek apa pun sebelum client subscribe?
+ Apa yang disimpan di CCCD dan siapa yang menulisnya?
+ Mengapa sensor sebaiknya berhenti mengirim saat tidak ada client terhubung?
+ Bagaimana pola push ini nanti diterjemahkan ke MQTT pada Modul 14?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Telemetri berpenanda dan hemat transaksi])[
  / CH-1 --- Telemetri berpenanda (wajib): Ubah payload menjadi
    `suhu:26.3,#<seq>` dengan nomor urut naik. Monitor menghitung loss dari
    lompatan nomor. Format ini dipakai lagi di M13--M16, lihat @lst:m04-ch1.

  / CH-2 --- Interval adaptif: Kirim notify hanya bila nilai berubah lebih dari
    0,5 °C dari nilai terakhir yang dikirim, dengan batas maksimal 10 detik
    tanpa kirim (_heartbeat_). Ukur berapa banyak transaksi yang dihemat dalam
    2 menit.
]

#kode(```cpp
// Sensor - loop()
static uint32_t seq = 0;
char msg[32];
snprintf(msg, sizeof(msg), "suhu:%.1f,#%lu", readSensor(), (unsigned long)++seq);
```.text,
  [Kerangka CH-1 --- telemetri dengan nomor urut],
  "lst:m04-ch1",
)

#tujuan-prak(3, [Sensor nyata dan pemulihan otomatis])[
  / CH-3 --- Sensor asli: Ganti `readSensor()` dengan pembacaan sensor nyata
    (DHT22 atau DS18B20 bila tersedia). Bandingkan sebaran nilainya dengan
    versi simulasi dan catat berapa lama satu pembacaan memblokir `loop()`.

  / CH-4 --- Self-healing: Buat monitor melakukan scan ulang otomatis pada
    `onDisconnect` sehingga aliran pulih tanpa reset manual. Ukur waktu
    pemulihannya, 5 percobaan, lalu hitung rata-ratanya.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (telemetry, notify dibanding indication, push dibanding
  pull).
+ Konfigurasi --- `platformio.ini`, environment, UUID characteristic telemetri.
+ Hasil eksperimen --- log kedua node (EXP-01 sampai EXP-03 beserta
  checkpoint), termasuk hasil uji ketika subscribe dikomentari.
+ Data pengukuran --- tabel bagian Pengukuran *dan* tabel pembanding polling
  dengan notify.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-2, sertakan angka penghematan transaksi.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
