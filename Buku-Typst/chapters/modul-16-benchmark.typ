// ============================================================================
// Modul 16 — Proyek: Benchmark Protokol IoT
// Sumber: week16_comparative/README.md; listing kode dibaca langsung dari
//         assets/code/week16_comparative/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 16 — Proyek: Benchmark Protokol IoT", l: "bab:modul-16")

#identitas-modul(
  "Modul 16",
  [Prove Your Protocol --- Proyek Benchmark Protokol IoT],
  [ESP32-H2 + ESP32-C6 · BLE / Zigbee / Thread ke MQTT · level Project ·
   3 × 50 menit · folder kode `week16_comparative`],
)

#pengantar([Gambaran Umum])[
Modul 16 dirancang untuk tiga pertemuan (3 × 50 menit) dan berstatus proyek.
Misinya membuktikan dengan data --- bukan dengan demo --- protokol mana yang
paling sesuai untuk sebuah skenario IoT. Percobaan berjalan sebagai proyek
komparatif, diamati melalui dua Serial Monitor 115200 baud, `mosquitto_sub`,
serta seluruh data pengukuran yang dikumpulkan sejak Modul 05.
]

== Pendahuluan

Ini adalah modul *panen*. Lima belas modul sebelumnya menghasilkan angka; di
sini angka-angka itu dikumpulkan menjadi satu tabel pembanding. Modul ini
membangun pipeline *BLE ke gateway C6 ke MQTT* sebagai pasangan yang setara
dengan pipeline Thread di M15 --- dengan payload, interval, gateway, dan broker
yang *sama persis*, sehingga hanya protokol hop pertama yang menjadi variabel.

Prasyaratnya adalah M04--M06 untuk BLE telemetry dan mesh, M08--M10 untuk
Zigbee, M11--M13 untuk Thread, serta M14--M15 untuk MQTT dan pipeline ---
*beserta seluruh data pengukurannya*. Yang dibangun di sini adalah pipeline BLE
ke MQTT sebagai pembanding pipeline Thread M15, metodologi perbandingan yang
adil melalui variabel kontrol, dan rekomendasi yang berpijak pada data. Modul
ini menutup seluruh seri: dari satu tautan radio pada M01 sampai keputusan
arsitektur yang berbasis bukti.

#penting[
  *Yang dinilai bukan "sistem menyala".* Yang dinilai adalah kemampuan
  membuktikan, dengan angka hasil pengukuran sendiri, protokol mana yang paling
  sesuai untuk sebuah kasus --- dan mempertahankan rekomendasi itu saat ditanya
  balik.
]

*Peta seluruh seri --- dari mana angka hasil pengukuran berasal*

#tbl(
  table(
    columns: (auto, auto, 1.4fr),
    align: (left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Blok], th[Modul], th[Angka yang dipanen di sini]),
    [BLE], [01--06],
    [RSSI terhadap jarak, loss, latency notify, batas multi-node, latency relay],
    [802.15.4], [07], [jangkauan radio telanjang (baseline)],
    [Zigbee], [08--10],
    [waktu join dan binding, latency 1 hop dibanding 2 hop, loss per node],
    [Thread], [11--12], [latency PING/PONG, loss mesh, waktu self-healing],
    [Integrasi], [13--15],
    [latency dan loss per hop, latency end-to-end pipeline Thread],
    [*Proyek*], [*16 (ini)*],
    [*latency dan loss end-to-end pipeline BLE --- pasangan pembanding M15*],
  ),
  [Peta seluruh seri dan asal angka pengukuran],
  "tbl:m16-peta",
)

*Kontrak data lab ini --- inilah yang membuat perbandingan sah.*

#tbl(
  table(
    columns: (1.2fr, auto, 1.4fr),
    align: (left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Variabel], th[Status], th[Nilai]),
    [Payload], [*dikontrol*], [`suhu:XX.X`],
    [Interval kirim], [*dikontrol*], [2000 ms],
    [Gateway], [*dikontrol*], [ESP32-C6],
    [Broker dan topic], [*dikontrol*],
    [`test.mosquitto.org:1883`, `praktikum/h2/telemetri`],
    [Jarak dan penghalang], [*dikontrol*], [1 m, 5 m, 5 m + dinding],
    [*Protokol hop pertama*], [*variabel bebas*],
    [BLE (modul ini) dibanding Thread (M15) dibanding Zigbee (M08--M10)],
  ),
  [Variabel kontrol dan variabel bebas benchmark],
  "tbl:m16-variabel",
)

Angka yang diukur pada kondisi berbeda *tidak boleh* dimasukkan ke tabel
pembanding. Jika data M15 diambil pada interval 3 detik sementara modul ini
2 detik, ulangi salah satunya --- atau nyatakan perbedaan itu secara eksplisit
sebagai keterbatasan.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membandingkan protokol dengan data yang dapat diaudit])[
  + Membangun pipeline BLE ke gateway C6 ke MQTT dengan variabel kontrol yang
    identik dengan pipeline Thread M15.
  + Mengukur RSSI, latency end-to-end, packet loss, dan throughput untuk
    pipeline BLE, lalu menempatkannya dalam satu tabel bersama data Thread dan
    Zigbee dari modul sebelumnya.
  + Menunjukkan asal setiap angka dalam tabel perbandingan (modul, tanggal,
    kondisi pengukuran) sehingga hasilnya dapat diaudit.
  + Merumuskan rekomendasi protokol untuk minimal tiga kasus nyata, dengan
    justifikasi yang menunjuk baris tertentu pada tabel --- dan menyebutkan
    keterbatasan datanya.
]

*Kriteria keberhasilan*

#checklist((
  [Tabel perbandingan protokol terisi metrik terukur (RSSI, latency, packet
   loss, throughput).],
  [Setiap angka dapat ditunjukkan asal pengukurannya (modul beserta kondisi).],
  [Rekomendasi protokol dapat dipertanggungjawabkan dengan data, bukan opini.],
  [Keterbatasan metodologi dinyatakan secara eksplisit.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (model
konsumsi daya, analisis kapasitas kanal, metodologi benchmark jaringan) berada
di buku teori terpisah. Karakteristik kerja tiap protokol dirangkum pada
@tbl:m16-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Protokol atau istilah], th[Karakteristik kerja]),
    [BLE], [Jaringan bintang, koneksi GATT, notify untuk push --- daya sangat rendah, jangkauan pendek, tanpa mesh pada mode ini.],
    [Zigbee], [Mesh 802.15.4 dengan ZC, ZR, dan ZED --- jangkauan luas via multi-hop, perintah baku antar-vendor.],
    [Thread], [Mesh 802.15.4 berbasis IPv6 --- self-healing, role dipilih otomatis, langsung nyambung ke dunia IP.],
    [MQTT pub/sub], [Muara bersama semua protokol; QoS 0 pada lab ini.],
    [Variabel kontrol], [Faktor yang sengaja disamakan agar perbandingan adil.],
    [Variabel bebas], [Faktor yang sengaja diubah --- di sini protokol hop pertama.],
    [Metrik], [RSSI, latency end-to-end, packet loss, throughput (pesan per menit).],
  ),
  [Istilah kerja Modul 16],
  "tbl:m16-istilah",
)

*Empat metrik, empat pertanyaan berbeda.* Jangan dicampur.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Metrik], th[Menjawab pertanyaan]),
    [RSSI], [Seberapa kuat sinyalnya di titik ini?],
    [Latency], [Berapa lama data sampai?],
    [Packet loss], [Berapa banyak yang tidak sampai sama sekali?],
    [Throughput], [Berapa banyak yang bisa lewat per satuan waktu?],
  ),
  [Empat metrik dan pertanyaan yang dijawabnya],
  "tbl:m16-metrik",
)

Protokol bisa unggul di satu metrik dan kalah di lainnya --- itu justru inti
pekerjaan modul ini. Rekomendasi yang baik menyebut *metrik mana* yang
menentukan untuk kasus yang dibahas.

*Sekuens protokol yang diamati*

#diagram(```
[H2 sensor] NimBLE server ──► characteristic NOTIFY
[C6] scan "CMP_SENSOR" ──► connect ──► subscribe
[C6] onTelemetry() ──► mqtt.publish("praktikum/h2/telemetri", "suhu:25.3")
[Broker] ──► [Subscriber di PC]
```.text)

== Topologi

#diagram(```
   BOARD #1 (H2)               BOARD #2 (C6)                    INTERNET
+---------------+  BLE GATT  +--------------------+  Wi-Fi   +--------------------+
|   ESP32-H2    | ─────────► |     ESP32-C6       | ───────► |   Broker MQTT      |
|  DevKitM-1    |  notify    |    DevKitC-1       |  MQTT    | test.mosquitto.org |
|  CMP_SENSOR   | "suhu:XX.X"| CMP_GATEWAY        |  publish |       :1883        |
|  env: sensor  |  / 2 s     | BLE client + Wi-Fi |          +---------+----------+
+---------------+            | env: gateway       |                    │
 radio: BLE                  +--------------------+          +---------v----------+
                              radio: BLE + Wi-Fi             |  PC: mosquitto_sub |
                                                             +--------------------+
```.text, rapat: true)

#tbl(
  table(
    columns: (auto, auto, auto, 1.4fr),
    align: (left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran]),
    [Sensor], [*ESP32-H2* DevKitM-1], [`sensor`],
    [BLE server `CMP_SENSOR`, notify tiap 2 s],
    [Gateway], [*ESP32-C6* DevKitC-1], [`gateway`],
    [BLE client `CMP_GATEWAY` dan Wi-Fi/MQTT publisher],
    [Konsumen], [PC/laptop], [---], [`mosquitto_sub`, verifikasi independen],
  ),
  [Peran tiap elemen Modul 16],
  "tbl:m16-topologi",
)

Perhatikan: *gateway-nya sama* dengan M15 (ESP32-C6), *broker dan topic-nya
sama*, yang berbeda hanya hop pertama --- BLE di sini, Thread di M15. Itulah
sebabnya kedua hasil bisa diletakkan berdampingan.

UUID penting: service `4fafc201-1fb5-459e-8fcc-c5c9c331914b`, characteristic
telemetri `beb5483e-36e1-4688-b7f5-ea07361b26b2` --- sama dengan characteristic
telemetri Modul 04, jadi sensor M04 bisa dipakai ulang di sini bila perlu.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (sensor) dan ESP32-C6 (gateway BLE,
Wi-Fi, dan MQTT).

#tbl(
  table(
    columns: (auto, 1fr, 1.7fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1 --- sensor BLE `CMP_SENSOR`], [1],
    [2], [Board ESP32-C6], [DevKitC-1 --- gateway `CMP_GATEWAY`], [1],
    [3], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [4], [PC/Laptop], [PlatformIO Core/IDE dan `mosquitto-clients`], [1],
    [5], [Wi-Fi atau hotspot], [*2,4 GHz*, ada akses internet], [1],
    [6], [Broker MQTT], [`test.mosquitto.org:1883` atau lokal], [1],
    [7], [*Data Modul 05--15*], [tabel pengukuran BLE, Zigbee, Thread, dan pipeline M15], [wajib],
    [8], [Meteran atau penanda jarak], [agar posisi 1 m dan 5 m benar-benar sama dengan pengukuran modul lain], [1],
  ),
  [Alat dan bahan Modul 16],
  "tbl:m16-alat",
)

== Kode Program

#sumber-kode("week16_comparative",
  ("platformio.ini", "src/sensor/main.cpp", "src/gateway/main.cpp"))

#kode-berkas("week16_comparative/platformio.ini",
  [`platformio.ini` Modul 16 pada repositori],
  "lst:m16-ini",
)

#kode-berkas("week16_comparative/src/sensor/main.cpp",
  [`src/sensor/main.cpp` --- sensor BLE `CMP_SENSOR` di ESP32-H2],
  "lst:m16-sensor",
  pecah: true,
)

#kode-berkas("week16_comparative/src/gateway/main.cpp",
  [`src/gateway/main.cpp` --- gateway BLE ke MQTT di ESP32-C6],
  "lst:m16-gateway",
  pecah: true,
)

== Build dan Flash

#keluaran("mosquitto_sub -h test.mosquitto.org -t \"praktikum/h2/telemetri\" -v   # terminal 1
pio run -d week16_comparative -e sensor  -t upload -t monitor        # terminal 2
pio run -d week16_comparative -e gateway -t upload -t monitor        # terminal 3")

*Pre-flight checklist*

#checklist((
  [ESP32-H2 dan ESP32-C6 terhubung ke PC via kabel USB, port dicatat.],
  [`WIFI_SSID` dan `WIFI_PASS` pada `src/gateway/main.cpp` sudah disesuaikan
   (hotspot *2,4 GHz*).],
  [Env `gateway` memakai `board_build.partitions = huge_app.csv` (firmware BLE,
   Wi-Fi, dan MQTT lebih dari 1,25 MB).],
  [Broker dapat dijangkau
   (`mosquitto_sub -h test.mosquitto.org -t "praktikum/#" -v`).],
  [Firmware `sensor` dan `gateway` berhasil di-build.],
  [Dua Serial Monitor (115200) dibuka, satu untuk tiap board.],
  [*Data Thread M15 tersedia* sebagai pembanding, beserta catatan kondisi
   pengukurannya.],
  [Posisi uji (1 m, 5 m, 5 m + dinding) ditandai fisik agar bisa diulang
   identik.],
))

== Percobaan

=== EXP-01 --- Sensor BLE dan Advertising

Deploy firmware `sensor` ke H2. NimBLE membuat server GATT dengan
characteristic NOTIFY lalu mengadvertise nama `CMP_SENSOR`. Gateway belum
dinyalakan.

#diagram(```
[H2] NimBLE init "CMP_SENSOR" ──► createService ──► characteristic NOTIFY
     ──► startAdvertising
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama perangkat BLE], [#isian],
    [Service dan Characteristic UUID], [#isian],
    [Interval kirim data (s)], [#isian],
    [Properti characteristic], [#isian],
    [Status serial saat advertising], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m16-exp01",
)

#checkpoint[
  H2 mencetak `Menunggu gateway...` dan belum mengirim notify apa pun. Ini
  kondisi awal yang benar sebelum gateway dinyalakan.
]

=== EXP-02 --- Gateway: Scan, Connect, Subscribe

Deploy firmware `gateway` ke C6. Gateway konek Wi-Fi, inisialisasi BLE sebagai
`CMP_GATEWAY`, active scan 5 detik, berhenti saat menemukan `CMP_SENSOR`, lalu
connect dan subscribe notify.

#diagram(```
[C6] WiFi.begin ──► NimBLE init ──► scan(5s) ──► "Sensor BLE ditemukan"
     ──► connect ──► subscribe(notify)
[H2] onConnect ──► "Gateway terhubung" ──► notify "suhu:XX.X" tiap 2 s
```.text)

*Expected output --- H2*

#keluaran("Sensor (BLE telemetry) starting...
Menunggu gateway...
Gateway terhubung
Notify: suhu:25.1
Notify: suhu:25.9")

*Expected output --- C6*

#keluaran("Gateway (BLE -> MQTT) starting...
Konek Wi-Fi NAMA_WIFI....
Wi-Fi OK, IP: 192.168.x.x
Scanning sensor BLE...
Sensor BLE ditemukan
BLE: terhubung ke sensor
BLE: koneksi berhasil
RX BLE: suhu:25.1
Publish MQTT [praktikum/h2/telemetri]: suhu:25.1")

#buka-abstraksi[
  Perhatikan bahwa gateway C6 di modul ini menjalankan *BLE dan Wi-Fi*,
  sedangkan gateway C6 di M15 menjalankan *Thread dan Wi-Fi*. Bandingkan ukuran
  firmware keduanya dari ringkasan `pio run`. Lalu jawab: mana yang lebih
  besar, dan apa artinya untuk perangkat gateway dengan flash terbatas? Ini
  adalah metrik kelima yang jarang diukur orang, tetapi nyata biayanya.
]

#checkpoint[
  Untuk *satu* nilai suhu yang sama, tiga baris berikut harus dapat ditunjuk:
  `Notify:` di H2, `RX BLE:` di C6, dan `Publish MQTT` di C6. Persis seperti
  M15 --- struktur pengamatannya sengaja dibuat identik.
]

=== EXP-03 --- Verifikasi End-to-End dan Variasi

Jalankan
`mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v` dan
pastikan tiap ± 2 detik muncul `praktikum/h2/telemetri suhu:25.1`.

Variasi wajib:

+ *Jarak H2 ke C6*: 1 m, 5 m, lalu di balik dinding --- posisi harus sama
  persis dengan pengukuran M15. Catat apakah koneksi BLE bertahan dan pesan
  tetap sampai.
+ *Putus koneksi*: reset H2, amati `onDisconnect` sehingga H2 advertise ulang;
  catat apakah gateway menyambung kembali sendiri atau perlu di-reset.
+ *Ulangi pengukuran pipeline Thread M15* pada kondisi jarak yang sama bila
  sempat --- ini menghilangkan keraguan terbesar pada tabel pembanding.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Interval pesan di subscriber (s)], [#isian],
    [Pesan per 2 menit], [#isian],
    [RSSI Wi-Fi gateway], [#isian],
    [RSSI BLE (dari `getRssi()` di C6)], [#isian],
    [Perilaku saat sensor reset], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m16-exp03",
)

#checkpoint[
  Tersedia *tiga baris data BLE* (1 m, 5 m, 5 m + dinding) dengan kondisi yang
  dapat dibuktikan sama dengan data M15. Tanpa itu, tabel perbandingan di
  bagian Pengukuran tidak sah --- dan itulah yang paling sering membuat laporan
  modul ini gugur.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada *ESP32-H2 DevKitM-1* dan *ESP32-C6 DevKitC-1* asli, broker
lokal (`tools/mqtt_broker.py`), jarak ±20 cm, capture 60 detik.

#keluaran("# H2 (env sensor)              # C6 (env gateway)               # Broker
[..] Gateway terhubung         [2.004] Wi-Fi OK, IP: ...197     CONNECT id=esp32c6-gateway
[..] Notify: suhu:24.7                 | RSSI: -84 dBm          PUBLISH praktikum/h2/telemetri
[..] Notify: suhu:23.9         [2.204] Sensor BLE ditemukan              suhu:23.7
                               [3.606] BLE: koneksi berhasil    PUBLISH praktikum/h2/telemetri
                               [4.608] RX BLE: suhu:24.7                suhu:22.7
                               [20.434] MQTT terhubung
                               [20.434] Publish MQTT [...]: suhu:23.7")

#tbl(
  table(
    columns: (1.5fr, 1.3fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu boot sampai Wi-Fi OK (C6)], [2,0 s (RSSI −84 dBm)],
    [Waktu boot sampai BLE tersambung ke sensor], [3,6 s],
    [Notify BLE dikirim H2 / diterima C6], [28 / 28 (0 % loss)],
    [Publish MQTT tiba di broker], [47/47 --- diverifikasi dari log broker, bukan dari log gateway],
    [BLE, Wi-Fi, dan MQTT jalan bersamaan di satu C6], [stabil],
  ),
  [Hasil verifikasi hardware Modul 16],
  "tbl:m16-verifikasi",
)

*Pengukuran pembanding langsung BLE dan Thread* --- pipeline M16 dan M15
diukur pada AP, jarak, dan broker yang sama persis, masing-masing 100 detik
(@tbl:m16-banding).

#tbl(
  table(
    columns: (1.3fr, auto, 1.1fr, 1.1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.45em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Pipeline], th[Modul], th[Hop sensor], th[Hop Wi-Fi/MQTT],
      th[End-to-end],
    ),
    [BLE ke C6 ke MQTT], [M16 (ini)], [47/48 (98 %)], [47/47 (100 %)], [*98 %*],
    [Thread ke C6 ke MQTT], [M15], [30/39 (77 %)], [2/7 (29 %)], [*5 %*],
  ),
  [Pembanding langsung pipeline BLE dan Thread],
  "tbl:m16-banding",
)

Pada jaringan lain (AP kanal 12) M15 mencapai 36 % dan M16 mencapai 82 % ---
urutannya tetap sama, selisihnya tetap besar.

Yang membedakan bukan protokol di atas kertas, melainkan *biaya koeksistensi
radio pada satu chip satu antena*: BLE duty-cycled sehingga berbagi antena
dengan Wi-Fi nyaris gratis; 802.15.4 pada peran Router selalu RX sehingga
menekan airtime Wi-Fi sampai TCP tidak lewat.

#catatan[
  Masukkan temuan ini ke analisis nomor 4 dan ke kolom "kondisi ukur" tabel
  perbandingan. Kesimpulan yang tepat bukan "Thread lebih buruk dari BLE",
  melainkan "pada gateway satu-chip, Thread dengan Wi-Fi berbagi radio jauh
  lebih mahal daripada BLE dengan Wi-Fi" --- gateway dua-chip atau border
  router khusus akan mengubah angka ini sepenuhnya.
]

#penting[
  *Jangan percaya `publish()` yang mengembalikan `true`.* Pada run M15 di atas,
  gateway mencetak 7 baris `Publish MQTT [...]` sementara broker hanya menerima
  2. Pada QoS 0 itu wajar: `publish()` hanya menulis ke buffer socket. Kolom
  "Broker menerima" pada tabel hasil pengukuran *wajib* diisi dari log broker
  atau subscriber.
]

*Perbaikan kode yang lahir dari uji ini*

#tbl(
  table(
    columns: (1.3fr, 1.2fr),
    align: (left, left),
    inset: (x: 0.55em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Masalah di perangkat nyata], th[Perbaikan]),
    [`mqtt.connect()` dipanggil tiap iterasi `loop()` tanpa jeda, sehingga ribuan baris `DNS Failed` membanjiri Serial dan menenggelamkan log BLE],
    [`maintainNetwork()` dengan jeda dan pengecekan status Wi-Fi lebih dulu],
    [`while (WiFi.status() != WL_CONNECTED)` menggantung selamanya],
    [dibatasi `WIFI_TIMEOUT_MS`, lalu lanjut; kaki BLE tetap bisa diamati],
  ),
  [Perbaikan kode hasil pengujian perangkat nyata Modul 16],
  "tbl:m16-perbaikan",
)

== Pengukuran

*Pengukuran BLE (proyek ini)*

#tbl(
  table(
    columns: (1.1fr, 1fr, 1.7fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.45em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Skenario / Jarak], th[RSSI BLE],
      th[Latency end-to-end (Notify ke subscriber, ms)], th[Success / 40],
    ),
    [1 m], [#isian], [], [],
    [5 m], [#isian], [], [],
    [5 m + dinding], [#isian], [], [],
  ),
  [Lembar pengukuran pipeline BLE Modul 16],
  "tbl:m16-ukur",
)

*Tabel perbandingan protokol --- deliverable utama modul ini.* Setiap sel wajib
disertai asal datanya.

#tbl(
  table(
    columns: (1.05fr, 0.85fr, 1fr, 0.7fr, 0.85fr, 0.9fr, 1.05fr),
    align: (left, left, left, left, left, left, left),
    inset: (x: 0.3em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Protokol], th[Sumber], th[Kondisi ukur], th[RSSI (dBm)],
      th[Latency (ms)], th[Loss (%)], th[Throughput (pesan/mnt)],
    ),
    [BLE ke MQTT], [M16 (ini)], [#isian], [], [], [], [],
    [Thread ke MQTT], [M15], [#isian], [], [], [], [],
    [Zigbee (hop sensor)], [M08--M10], [#isian], [], [], [], [],
    [802.15.4 raw (baseline)], [M07], [#isian], [], [], [], [],
  ),
  [Tabel perbandingan protokol --- deliverable utama Modul 16],
  "tbl:m16-perbandingan",
)

#penting[
  Kolom *"Kondisi ukur"* wajib diisi (jarak, interval, ada atau tidaknya
  penghalang, serta tanggal). Sel yang kondisinya berbeda dari baris lain harus
  ditandai dan disebut sebagai keterbatasan di bagian Analisis --- bukan
  disembunyikan.

  Zigbee tidak punya pipeline MQTT di lab ini, jadi angkanya adalah *latency
  hop sensor saja*, bukan end-to-end. Menuliskannya sebagai end-to-end adalah
  kesalahan yang akan langsung terlihat saat sidang.
]

*Metrik pendukung (opsional tetapi bernilai)*

#tbl(
  table(
    columns: (1.5fr, 1fr, 1fr),
    align: (left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Aspek], th[BLE (M16)], th[Thread (M15)]),
    [Ukuran firmware gateway], [#isian], [],
    [Waktu dari boot sampai data pertama sampai], [#isian], [],
    [Pemulihan setelah sensor di-reset], [#isian], [],
  ),
  [Metrik pendukung pembanding BLE dan Thread],
  "tbl:m16-pendukung",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran, dan *tunjuk barisnya*.

+ Berdasarkan data, protokol mana yang paling andal (packet loss terkecil) pada
  jarak terjauh, dan mengapa?
+ Bagaimana latency end-to-end BLE ke MQTT dibandingkan Thread ke MQTT untuk
  payload yang sama? Berapa selisihnya, dan dari hop mana selisih itu berasal?
+ Mengapa BLE connection-based lebih sensitif terhadap jarak atau penghalang
  dibanding mesh Thread? Kaitkan dengan data M06 (relay BLE) dan M12 (mesh
  Thread).
+ Protokol mana yang paling efisien untuk node baterai dengan interval kirim
  jarang? Jelaskan dengan data, termasuk konsekuensi peran router (M10).
+ Untuk kasus (a) rumah pintar 15 node, (b) sensor tunggal dekat gateway, dan
  (c) gedung bertingkat --- protokol apa yang direkomendasikan? Dasarkan tiap
  jawaban pada baris tabel tertentu.
+ *Apa keterbatasan terbesar dari perbandingan ini?* Sebutkan minimal dua, dan
  jelaskan apa yang perlu diukur untuk mengatasinya.

== Concept Check

+ Jelaskan perbedaan topologi BLE (star atau connection), Zigbee (mesh), dan
  Thread (mesh IPv6).
+ Apa itu GATT notify dan mengapa dipakai, bukan indication atau polling read?
+ Bagaimana gateway menemukan dan memilih sensor yang tepat saat scanning?
  Perhatikan `onResult`.
+ Apa peran MQTT dalam proyek ini, dan mengapa perbandingan protokol dilakukan
  di hop sensor ke gateway, bukan di hop MQTT?
+ Jika throughput naik 10 kali (interval 200 ms), protokol mana yang paling
  mungkin bermasalah lebih dulu? Mengapa, dan data modul mana yang mendukung
  dugaan awal?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Rekomendasi berbasis data dan loss per hop])[
  / CH-1 --- Rekomendasi berbasis data (wajib): Tulis mini-laporan satu halaman
    yang memilih protokol untuk *satu* kasus nyata, dengan tabel bagian
    Pengukuran sebagai justifikasi. Sertakan satu paragraf "kapan rekomendasi
    ini salah" --- kondisi yang akan membalikkan kesimpulan yang diambil.

  / CH-3 --- Packet loss (wajib): Hitung packet loss dengan sequence number
    pada payload (`suhu:25.3,#21`). Contoh: 60 notify terkirim, 57 sampai di
    subscriber, sehingga loss = (60 − 57)/60 × 100 % = 5 %. Pisahkan loss hop
    BLE dan hop MQTT.
]

#tujuan-prak(3, [Menambah sumber dan melengkapi baris Zigbee])[
  / CH-2 --- Dua sensor BLE: Tambahkan sensor BLE kedua (`CMP_SENSOR2`, UUID
    berbeda) dan buat gateway mem-forward keduanya ke topic berbeda. Ukur
    apakah latency berubah saat gateway melayani dua koneksi --- bandingkan
    dengan temuan M05.

  / CH-4 --- Pipeline Zigbee: Lengkapi baris Zigbee pada tabel perbandingan
    dengan pipeline yang setara (Zigbee ke gateway ke MQTT), sehingga ketiga
    protokol diukur end-to-end pada kondisi yang sama. Ini pekerjaan terbesar
    --- dan yang membuat tabel hasil pengukuran benar-benar utuh.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (BLE/GATT, Zigbee, Thread, MQTT, serta metodologi
  perbandingan: variabel kontrol dibanding variabel bebas).
+ Konfigurasi --- UUID, nama perangkat, SSID, broker, topic, NimBLE-Arduino,
  dan `huge_app.csv`.
+ Hasil eksperimen --- log H2, C6, dan `mosquitto_sub` (EXP-01 sampai EXP-03
  beserta checkpoint).
+ Data pengukuran --- tabel BLE *dan tabel perbandingan protokol lengkap dengan
  kolom "kondisi ukur"*.
+ Analisis dan concept check, termasuk pernyataan keterbatasan.
+ Challenge --- CH-1 dan CH-3 wajib.
+ *Kesimpulan dan rekomendasi protokol* --- ditulis sendiri, dengan setiap
  klaim menunjuk baris data.
