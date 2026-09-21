// ============================================================================
// Modul 05 — Multi-Node BLE (Topologi Bintang)
// Sumber: week05_ble_multinode/README.md; listing kode dibaca langsung dari
//         salinan berkas sumber di assets/code/week05_ble_multinode/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 05 — Multi-Node BLE (Topologi Bintang)", l: "bab:modul-05")

#identitas-modul(
  "Modul 05",
  [Connect Multiple Devices --- Multi-Node BLE (Topologi Bintang)],
  [ESP32-H2 · BLE · STAR / 2 koneksi · level Intermediate · 3 × 50 menit ·
   folder kode `week05_ble_multinode`],
)

#pengantar([Gambaran Umum])[
Modul 05 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya menahan dua koneksi sekaligus dari satu central dan membuktikan kedua
aliran data tetap utuh. Percobaan berjalan dalam topologi bintang dengan satu
central dan dua peripheral, diamati melalui tiga terminal Serial Monitor pada
115200 baud.
]

== Pendahuluan

Empat modul pertama hanya pernah menangani *satu* lawan bicara. Di sini jumlah
node menjadi variabel --- dan bersamanya muncul pertanyaan khas WSN: apakah
pusat jaringan sanggup melayani semua node, dan bagaimana cara membedakan
sumber tiap pesan. Jawaban modul ini (satu objek client per node, laju per node
dihitung terpisah) adalah versi sederhana dari binding table Zigbee (M09) dan
mesh Thread (M12).

Prasyaratnya adalah M04: notify sebagai telemetry, mekanisme subscribe, dan
pengukuran loss. Yang dibangun di sini adalah dua objek `NimBLEClient` yang
hidup bersamaan, pemisahan aliran data per sumber, perhitungan laju tiap node
secara terpisah, serta pengamatan ketahanan sistem saat salah satu node hilang.
Semuanya dipakai lagi pada M06 ketika node ketiga berperan sebagai hop alih-alih
cabang, M09 pada satu coordinator dengan banyak end device, M12 pada komunikasi
many-to-many, dan M16 ketika batas skala menjadi bahan pembanding antarprotokol.

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
    [03], [Characteristic mewakili state dan perintah],
    [04], [Telemetry via notify],
    [*05 (ini)*], [*Jumlah node jadi variabel --- satu pusat, banyak sumber*],
    [06], [Node ketiga dipakai sebagai relay, bukan cabang],
  ),
  [Peta modul blok BLE],
  "tbl:m05-peta",
)

*Kontrak data lab ini.* Setiap peripheral memberi *prefiks identitas* pada
payloadnya (`A:n`, `B:n`). Tanpa penanda sumber, pesan dari banyak node tidak
bisa dipisahkan di pusat --- masalah yang persis sama muncul lagi di M09
(`short addr`), M12 (`NODE_ID`), dan M15 (`node2` pada payload MQTT).

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Melayani dua koneksi sekaligus dari satu central])[
  + Membangun satu central BLE yang memelihara dua koneksi aktif bersamaan dan
    menunjukkan objek atau state yang memisahkan keduanya di dalam kode.
  + Menghitung laju pesan tiap node secara terpisah (pesan per menit) dan
    mencocokkannya dengan interval yang diprogram (A: 30 per menit, B: 20 per
    menit).
  + Menghitung packet loss *per node*, bukan gabungan, pada minimal 4 jarak.
  + Menjelaskan perilaku sistem saat salah satu peripheral hilang dan kembali,
    berdasarkan log ketiga board.
]

*Kriteria keberhasilan*

#checklist((
  [Central memegang dua koneksi aktif bersamaan
   (`Koneksi ke kedua node selesai`).],
  [Laju tiap node sesuai perhitungan interval (A: 30 per menit, B: 20 per
   menit).],
  [Loss per node terukur terpisah dan tercatat di tabel.],
  [Uji ketahanan (Node B dimatikan lalu dinyalakan) dilakukan dan hasilnya
   dicatat.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam
(penjadwalan connection event multi-link, batas jumlah koneksi NimBLE) berada
di buku teori terpisah. Istilah kerja dirangkum pada @tbl:m05-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Topologi bintang], [Satu pusat berkomunikasi dengan banyak node; semua lalu lintas lewat pusat.],
    [Advertising], [Peripheral menyiarkan nama dan Service UUID agar ditemukan central.],
    [Active scan], [Central mengirim scan-request agar nama device ikut terbaca.],
    [Multi-connection], [Satu central memelihara beberapa objek `NimBLEClient` sekaligus (di sini 2).],
    [Notify], [Peripheral mendorong data ke central setelah di-subscribe.],
    [Time-sharing radio], [Satu radio melayani dua koneksi bergantian --- sumber utama penurunan laju bila node bertambah banyak.],
  ),
  [Istilah kerja Modul 05],
  "tbl:m05-istilah",
)

*Mengapa interval A dan B sengaja dibedakan?* Jika keduanya sama, log central
akan berselang-seling rapi sehingga "central melayani dua node dengan benar"
tidak dapat dibedakan dari "central hanya mencatat bergantian". Interval 2 s
dan 3 s menghasilkan pola tak beraturan yang hanya cocok bila kedua aliran
memang independen.

*Sekuens protokol yang diamati*

#diagram(```
 Peripheral A                 Central                  Peripheral B
 (advertise) ────► scan 5 s ────► (temukan A & B)
                connect A ──────► subscribe notify A
                connect B ──────► subscribe notify B
 "A:1","A:2"… ────notify───►        ◄───notify──── "B:1","B:2"…
```.text)

== Topologi

#diagram(```
                        BOARD #1
                 +---------------------+
                 |      ESP32-H2       |
                 |   MULTI_CENTRAL     |
                 | (client, 2 koneksi) |
                 +----------+----------+
                /                     \
       koneksi 1                       koneksi 2
             /                           \
     BOARD #2                             BOARD #3
  +----------+---------+      +----------+---------+
  |     ESP32-H2       |      |     ESP32-H2       |
  |   MULTI_NODE_A     |      |   MULTI_NODE_B     |
  | notify "A:n" / 2 s |      | notify "B:n" / 3 s |
  +--------------------+      +--------------------+
      env: nodea                    env: nodeb
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Payload / interval]),
    [Central], [ESP32-H2 DevKitM-1], [`central`], [BLE Central, 2 koneksi], [---],
    [Node A], [ESP32-H2 DevKitM-1], [`nodea`], [Peripheral `MULTI_NODE_A`], [`A:n` tiap 2000 ms],
    [Node B], [ESP32-H2 DevKitM-1], [`nodeb`], [Peripheral `MULTI_NODE_B`], [`B:n` tiap 3000 ms],
  ),
  [Peran tiap node Modul 05],
  "tbl:m05-topologi",
)

Ketiga peran memakai board yang sama, *ESP32-H2 DevKitM-1*, dengan radio
Bluetooth LE. ESP32-C6 tidak dipakai pada modul ini.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan PlatformIO dan
pustaka NimBLE-Arduino.

#tbl(
  table(
    columns: (auto, 1fr, 1.4fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1], [3],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [3],
    [3], [PC/Laptop], [PlatformIO Core/IDE, idealnya 3 port USB bebas], [1],
    [4], [Library NimBLE-Arduino], [`h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps`], [---],
    [5], [Ruang uji], [jarak awal ±1 m antar board, bebas logam di dekat antena], [---],
  ),
  [Alat dan bahan Modul 05],
  "tbl:m05-alat",
)

Bila port USB kurang dari tiga, monitor boleh dibuka bergantian --- tetapi
minimal central harus terus termonitor selama pengukuran.

== Kode Program

#sumber-kode("week05_ble_multinode",
  ("platformio.ini", "src/central/main.cpp", "src/nodea/main.cpp",
   "src/nodeb/main.cpp"))

*Pin port agar tidak salah flash* (@lst:m05-ini-readme).

#kode(```ini
[env:central]
build_src_filter = +<central/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3
monitor_port = /dev/ttyACM0

[env:nodea]
build_src_filter = +<nodea/*.cpp>
upload_port  = /dev/ttyACM2     ; Windows: COM4
monitor_port = /dev/ttyACM2

[env:nodeb]
build_src_filter = +<nodeb/*.cpp>
upload_port  = /dev/ttyACM4     ; Windows: COM5
monitor_port = /dev/ttyACM4
```.text,
  [Potongan `platformio.ini` dengan port yang dipin per environment],
  "lst:m05-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week05_ble_multinode/platformio.ini",
  [`platformio.ini` Modul 05 pada repositori],
  "lst:m05-ini",
)

#kode-berkas("week05_ble_multinode/src/central/main.cpp",
  [`src/central/main.cpp` --- central dengan dua objek client],
  "lst:m05-central",
  pecah: true,
)

#kode-berkas("week05_ble_multinode/src/nodea/main.cpp",
  [`src/nodea/main.cpp` --- peripheral `MULTI_NODE_A`],
  "lst:m05-nodea",
  pecah: true,
)

#kode-berkas("week05_ble_multinode/src/nodeb/main.cpp",
  [`src/nodeb/main.cpp` --- peripheral `MULTI_NODE_B`],
  "lst:m05-nodeb",
  pecah: true,
)

== Build dan Flash

Flash *peripheral dulu*, central belakangan, agar saat central melakukan scan
5 detik keduanya sudah mengudara.

#keluaran("pio run -d week05_ble_multinode -e nodea   -t upload
pio run -d week05_ble_multinode -e nodeb   -t upload
pio run -d week05_ble_multinode -e central -t upload -t monitor")

#penting[
  *Pilih port USB-to-UART, bukan USB native.* Setiap board ESP32-H2 muncul
  sebagai *dua* port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan
  USB-Serial/JTAG bawaan chip (`303a:1001`). Proses flash pada lab ini memakai
  *jembatan UART*, karena jalur itulah yang tersambung ke rangkaian _auto
  program_ (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan
  tombol. Pada Linux keduanya berselang-seling: port *genap* adalah UART, port
  *ganjil* adalah USB native. Satu board memakai `/dev/ttyACM0`, dua board
  `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board `/dev/ttyACM0`, `/dev/ttyACM2`,
  dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port
  ber-Hardware ID `1A86:55D3`.
]

*Pre-flight checklist*

#checklist((
  [`pio device list` dijalankan, tiga port dicatat dan diisikan di atas.],
  [Ketiga ESP32-H2 terpasang dan terdeteksi.],
  [Environment `central`, `nodea`, dan `nodeb` dikenali PlatformIO.],
  [Serial Monitor 115200 baud siap (3 terminal).],
  [Penempatan tiga perangkat direncanakan (jarak awal ±1 m).],
))

== Percobaan

=== EXP-01 --- Menyalakan Dua Peripheral

Unggah firmware peripheral ke dua board, verifikasi keduanya advertise dan
menunggu central.

#diagram(```
 +-----+  advertise    (udara)   advertise  +-----+
 |  A  | ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~> |  B  |
 +-----+ <~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ +-----+
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama BLE Node A], [#isian],
    [Nama BLE Node B], [#isian],
    [Pesan `Menunggu central...` muncul di keduanya?], [#isian],
    [Interval kirim A (ms)], [#isian],
    [Interval kirim B (ms)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m05-exp01",
)

#checkpoint[
  Kedua peripheral mencetak `Menunggu central...` dan belum mencetak `Notify:`
  sama sekali. Jika sudah ada `Notify:` padahal central belum menyala, berarti
  node mengirim tanpa penerima --- periksa syarat `deviceConnected` di
  kodenya.
]

=== EXP-02 --- Dua Koneksi dan Subscribe

Unggah environment `central` ke board ketiga. Central melakukan active scan
5 detik, menemukan `MULTI_NODE_A` dan `MULTI_NODE_B`, lalu membuka dua koneksi
dan subscribe notify pada masing-masing.

#diagram(```
 scan 5 s ──► temukan A ──► connect A ──► subscribe A
          ──► temukan B ──► connect B ──► subscribe B
                          (loop: cetak setiap notify)
```.text)

*Expected output --- Central*

#keluaran("Central (multi-node) starting...
Scanning node A dan B...
Node A ditemukan
Node B ditemukan
NodeA terhubung
NodeB terhubung
Koneksi ke kedua node selesai
[NodeA] RX: A:1
[NodeB] RX: B:1
[NodeA] RX: A:2
[NodeA] RX: A:3
[NodeB] RX: B:2")

*Expected output --- Peripheral (contoh Node A)*

#keluaran("Node A (peripheral) starting...
Menunggu central...
Central terhubung
Notify: A:1
Notify: A:2")

#buka-abstraksi[
  Di `src/central/main.cpp`, cari *berapa objek `NimBLEClient` yang dibuat* dan
  bagaimana callback notify tahu pesan ini datang dari A atau dari B.
  Jawabannya bukan dari isi payload --- payload hanya kebetulan diberi prefiks.
  Telusuri hingga menemukan mekanisme sebenarnya, lalu jawab: jika kedua node
  mengirim payload identik `"data"`, apakah central masih bisa membedakannya?
]

#checkpoint[
  Central mencetak `Koneksi ke kedua node selesai` dan setelah itu muncul baris
  `[NodeA]` *dan* `[NodeB]` bergantian tak beraturan. Jika hanya satu label
  yang pernah muncul, koneksi kedua gagal --- ulangi scan dengan mereset
  central (peripheral tetap menyala).
]

=== EXP-03 --- Laju dan Ketahanan

Biarkan sistem berjalan 2--3 menit, ukur laju pesan tiap node, lalu uji
ketahanan: reset (atau cabut USB) Node B, amati `NodeB terputus` di central dan
`Central terputus, advertise ulang` di Node B, lalu nyalakan kembali dan
verifikasi pemulihan.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Jumlah pesan A per menit (harapan 30)], [#isian],
    [Jumlah pesan B per menit (harapan 20)], [#isian],
    [Apakah laju A berubah saat B mati?], [#isian],
    [Perilaku central saat Node B reset], [#isian],
    [Apakah koneksi B pulih otomatis?], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m05-exp03",
)

#checkpoint[
  Saat Node B dimatikan, aliran `[NodeA]` *tidak boleh* ikut berhenti. Jika
  ikut berhenti, central kehilangan kedua koneksi --- itu temuan penting, catat
  dan jelaskan di analisis.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 3 × *ESP32-H2 DevKitM-1* (jarak ±20 cm), capture 30 detik.

#keluaran("# Central (ESP32-H2, env central)
[0.401] Node B ditemukan
[0.401] Node A ditemukan
[0.802] NodeA terhubung
[1.604] NodeB terhubung
[2.205] Koneksi ke kedua node selesai
[2.406] [NodeA] RX: A:1
[3.408] [NodeB] RX: B:1
[4.409] [NodeA] RX: A:2
[6.413] [NodeA] RX: A:3
[6.413] [NodeB] RX: B:2")

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu scan sampai dua koneksi aktif], [2,2 s],
    [Node A: notify dikirim / diterima central], [14 / 14 (0 % loss)],
    [Node B: notify dikirim / diterima central], [9 / 9 (0 % loss)],
    [Laju Node A], [2,00 s per pesan, yaitu 30 pesan per menit],
    [Laju Node B], [3,00 s per pesan, yaitu 20 pesan per menit],
  ),
  [Hasil verifikasi hardware Modul 05],
  "tbl:m05-verifikasi",
)

Dua koneksi simultan tidak menggeser interval kedua node --- pada beban ringan
ini central masih mampu melayani keduanya tanpa kehilangan pesan.

== Pengukuran

Ukur *per node*, jangan digabung. Ini inti modul: dua node pada satu central
tidak selalu terdegradasi bersamaan.

#tbl(
  table(
    columns: (auto, auto, auto, 1.1fr, 1.1fr, auto, auto),
    align: (left, left, left, left, left, left, left),
    inset: (x: 0.3em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak], th[RSSI A], th[RSSI B], th[Pesan A /60 s (30)],
      th[Pesan B /60 s (20)], th[Loss A (%)], th[Loss B (%)],
    ),
    [1 m], [#isian], [], [], [], [], [],
    [3 m], [#isian], [], [], [], [], [],
    [5 m], [#isian], [], [], [], [], [],
    [10 m], [#isian], [], [], [], [], [],
  ),
  [Lembar pengukuran per node Modul 05],
  "tbl:m05-ukur",
)

*Skenario asimetris* (wajib, minimal satu baris) --- dekatkan A, jauhkan B.

#tbl(
  table(
    columns: (auto, auto, auto, auto, 1.4fr),
    align: (left, left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Posisi A], th[Posisi B], th[Loss A (%)], th[Loss B (%)], th[Kesimpulan]),
    [1 m], [10 m], [#isian], [], [],
  ),
  [Lembar pengukuran skenario asimetris],
  "tbl:m05-asimetris",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Bagaimana hubungan jarak terhadap RSSI dan keberhasilan penerimaan dari kedua
  node?
+ Apakah jumlah pesan per menit sesuai perhitungan dari interval tiap node?
  Jelaskan bila ada selisih.
+ Berapa latency dari `Notify` di peripheral hingga `RX` di central? Apakah
  bertambah pada jarak jauh?
+ Pada skenario asimetris, apakah node yang jauh menurunkan kualitas node yang
  dekat? Apa artinya bagi desain WSN?
+ Apakah topologi bintang BLE cocok untuk WSN banyak node? Bandingkan dengan
  koneksi P2P modul sebelumnya, dan perkirakan apa yang terjadi pada 10 node.

== Concept Check

+ Apa perbedaan peran central dan peripheral dalam BLE?
+ Mengapa central perlu subscribe pada tiap characteristic notify secara
  terpisah?
+ Bagaimana central membedakan pesan dari Node A dan Node B --- dari payload
  atau dari sesuatu yang lain?
+ Apa yang terjadi pada peripheral saat koneksi terputus, dan bagaimana
  pemulihannya?
+ Apa yang membatasi jumlah koneksi pada topologi bintang BLE, dari sisi stack
  dan dari sisi radio?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Menambah node dan menghitung loss per sumber])[
  / CH-1 --- Node ketiga: Tambahkan Node C (peripheral ketiga, interval 5 s,
    pesan `C:n`). Hitung persentase pesan tiap node terhadap total di central
    dan periksa apakah laju A dan B berubah setelah C bergabung.

  / CH-2 --- Loss otomatis per node: Hitung packet loss dari nomor urut,
    terpisah untuk tiap node, seperti @lst:m05-ch2. Contoh: counter Node A
    mencapai 120 dalam 4 menit tetapi central menerima 116, sehingga
    loss = (120 − 116)/120 × 100 % = 3,33 %.
]

#kode(```cpp
// Central - di callback notify, simpan last[] per node
static uint32_t last[2] = {0, 0};
uint32_t n = atoi(strchr(buf, ':') + 1);
if (last[idx] && n != last[idx] + 1)
    Serial.printf("LOSS %c: %lu paket\n", 'A' + idx, n - last[idx] - 1);
last[idx] = n;
```.text,
  [Kerangka CH-2 --- penghitung loss per node],
  "lst:m05-ch2",
)

#tujuan-prak(3, [Mencari batas skala dan memulihkan koneksi])[
  / CH-3 --- Cari batas skala: Turunkan interval kedua node ke 100 ms. Catat
    pada interval berapa central mulai kehilangan pesan, dan node mana yang
    lebih dulu terdampak. Kaitkan dengan konsep _time-sharing radio_.

  / CH-4 --- Reconnect otomatis: Buat central melakukan scan ulang dan
    menyambung kembali node yang hilang tanpa perlu reset. Ukur waktu
    pemulihannya, 5 percobaan.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (central/peripheral, multi-connection, topologi bintang).
+ Konfigurasi --- environment `central`, `nodea`, `nodeb`, UUID, dan interval.
+ Hasil eksperimen --- log serial tiga perangkat (EXP-01 sampai EXP-03 beserta
  checkpoint).
+ Data pengukuran --- tabel per node *dan* tabel skenario asimetris.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-2.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
