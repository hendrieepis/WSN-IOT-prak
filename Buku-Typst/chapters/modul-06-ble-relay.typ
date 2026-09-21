// ============================================================================
// Modul 06 — Relay Multi-Hop di atas BLE
// Sumber: week06_ble_mesh/README.md; listing kode dibaca langsung dari
//         assets/code/week06_ble_mesh/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 06 — Relay Multi-Hop di atas BLE", l: "bab:modul-06")

#identitas-modul(
  "Modul 06",
  [Build a BLE Mesh --- Relay Multi-Hop di atas BLE],
  [ESP32-H2 · BLE · relay A→B→C · level Intermediate · 3 × 50 menit ·
   folder kode `week06_ble_mesh`],
)

#pengantar([Gambaran Umum])[
Modul 06 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya memperluas jangkauan lewat hop, sehingga pesan dari A sampai ke C yang
tidak terjangkau langsung. Percobaan berjalan sebagai relay dua hop dengan A
sebagai sumber, B sebagai relay, dan C sebagai penerima, diamati melalui tiga
terminal Serial Monitor pada 115200 baud.
]

== Pendahuluan

Modul 05 menambah node sebagai *cabang* --- semua tetap bicara langsung ke
pusat. Modul ini memakai node ketiga sebagai *jembatan*, sehingga jangkauan
jaringan melampaui jangkauan satu radio. Konsep hop inilah yang membuat Zigbee
(M10) dan Thread (M12) disebut mesh; bedanya, di sana routing dikerjakan stack,
sedangkan di sini routing dituliskan sendiri di lapisan aplikasi --- supaya
mekanismenya terlihat telanjang sebelum disembunyikan protokol.

Prasyaratnya adalah M05: banyak koneksi, penanda sumber, dan pengukuran loss
per node. Yang dibangun di sini adalah node dual-role yang menjadi server dan
client sekaligus, penerusan pesan antar-hop, pengukuran loss per hop, serta
pemetaan mode kegagalan rantai. Keempatnya dipakai lagi pada M10 ketika router
Zigbee melakukan hal serupa secara otomatis, M12 pada mesh Thread yang
self-healing, M13 ketika gateway berperan sebagai hop antar-protokol, dan M16
ketika jangkauan multi-hop menjadi kriteria pemilihan protokol.

*Peta modul blok BLE (penutup blok)*

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
    [05], [Satu pusat, banyak sumber (bintang)],
    [*06 (ini)*], [*Jangkauan diperluas lewat hop --- penutup blok BLE*],
    [07], [Turun ke lapisan MAC 802.15.4 telanjang --- fondasi Zigbee dan Thread],
  ),
  [Peta modul blok BLE],
  "tbl:m06-peta",
)

*Kontrak data lab ini.* Payload `A:n` *tidak diubah* saat melewati relay ---
inilah _transparent forwarding_. Prinsip yang sama dipakai gateway di M13 dan
M15: gateway meneruskan isi apa adanya, tidak mem-parsing ulang, sehingga hop
tambahan tidak merusak data.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Memperluas jangkauan lewat relay dua hop])[
  + Mengimplementasikan node dual-role yang menjalankan GATT server dan GATT
    client bersamaan, dan menunjukkan bagian kode yang menangani masing-masing
    peran.
  + Membuktikan pesan dari A tiba utuh di C dengan mencocokkan nomor pesan pada
    log ketiga node.
  + Menghitung packet loss *per hop* (A ke B dan B ke C) dan menentukan hop
    mana yang menjadi penyebab kehilangan.
  + Menjelaskan mode kegagalan rantai (relay mati, penerima akhir mati)
    berdasarkan log, dan menyebutkan konsekuensinya bagi desain jaringan.
]

*Kriteria keberhasilan*

#checklist((
  [Rantai A ke B ke C terbentuk; C mencetak
   `Pesan tiba (via A -> B -> C)`.],
  [Nomor pesan di A, B, dan C dapat dicocokkan satu per satu.],
  [Tabel loss per hop terisi dari pengukuran sendiri.],
  [Kedua mode kegagalan (C mati, B mati) diuji dan hasilnya dicatat.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (BLE
Mesh standar atau ESP-BLE-MESH, flooding dibanding routing, model
publish-subscribe mesh) berada di buku teori terpisah. Istilah kerja dirangkum
pada @tbl:m06-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Hop], [Satu lompatan radio dari node ke node tetangga.],
    [Relay], [Node yang menerima pesan lalu meneruskannya ke node berikutnya.],
    [Dual role], [Satu board menjalankan GATT server (untuk hop berikutnya) dan GATT client (ke hop sebelumnya) bersamaan.],
    [Transparent forwarding], [Isi pesan diteruskan apa adanya, tanpa diubah relay.],
    [Loss per hop], [Kehilangan dihitung terpisah tiap lompatan, bukan hanya ujung-ke-ujung.],
    [Latency kumulatif], [Waktu total A ke C sama dengan latency hop 1 ditambah waktu proses relay ditambah latency hop 2.],
  ),
  [Istilah kerja Modul 06],
  "tbl:m06-istilah",
)

*Ini bukan BLE Mesh standar.* ESP-BLE-MESH (spesifikasi Bluetooth SIG) memakai
flooding, provisioning, dan model publish-subscribe --- jalur pesan ditentukan
protokol. Di sini rantai A ke B ke C ditentukan *oleh kode aplikasi*.
Keterbatasannya (tidak ada penemuan rute, tidak ada self-healing, arah tunggal)
justru yang perlu dicatat, karena itulah yang dibereskan Thread di M12.

*Sekuens protokol yang diamati*

#diagram(```
 A (server)          B (relay: client ke A + server untuk C)          C (client)
   "A:1" ──notify──►  onNotifyFromA() → pendingForward
                      notify ke C ──────────────────────────────────►  cetak
```.text)

== Topologi

#diagram(```
  BOARD #1                 BOARD #2                 BOARD #3
+-----------+  notify   +-----------+  notify   +-----------+
| ESP32-H2  | --------> | ESP32-H2  | --------> | ESP32-H2  |
|  Node A   |  client B |  Node B   |  client C |  Node C   |
| (sumber)  | <-------- | (relay:   | <-------- | (penerima |
| server    |  konek B  |  server + |  konek B  |  akhir)   |
+-----------+           |  client)  |           +-----------+
 MESH_NODE_A            MESH_NODE_B              MESH_NODE_C
  env: nodea             env: nodeb               env: nodec
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, 1.2fr),
    align: (left, left, left, left, left),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Aksi]),
    [Node A], [ESP32-H2 DevKitM-1], [`nodea`], [Sumber (server)],
    [kirim `A:n` tiap 4 s saat relay terhubung],
    [Node B], [ESP32-H2 DevKitM-1], [`nodeb`], [Relay (server dan client)],
    [terima dari A, teruskan ke C],
    [Node C], [ESP32-H2 DevKitM-1], [`nodec`], [Penerima akhir (client)],
    [cetak pesan yang tiba],
  ),
  [Peran tiap node Modul 06],
  "tbl:m06-topologi",
)

Ketiganya *ESP32-H2 DevKitM-1*. Relay di sini dibuat di lapisan aplikasi di
atas BLE GATT --- bukan BLE Mesh standar --- sehingga tidak butuh board lain.

Susun posisi *A, B, dan C dalam satu garis*; A dan C tidak perlu (dan sebaiknya
tidak) saling terjangkau.

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
    [5], [Power bank atau catu daya USB], [agar A dan C bisa dijauhkan dari meja], [2 (opsional)],
    [6], [Ruang uji], [lorong atau ruang panjang untuk formasi garis A--B--C], [---],
  ),
  [Alat dan bahan Modul 06],
  "tbl:m06-alat",
)

== Kode Program

#sumber-kode("week06_ble_mesh",
  ("platformio.ini", "src/nodea/main.cpp", "src/nodeb/main.cpp",
   "src/nodec/main.cpp"))

*Pin port agar tidak salah flash* (@lst:m06-ini-readme).

#kode(```ini
[env:nodea]
build_src_filter = +<nodea/*.cpp>
upload_port  = /dev/ttyACM0
monitor_port = /dev/ttyACM0

[env:nodeb]
build_src_filter = +<nodeb/*.cpp>
upload_port  = /dev/ttyACM2
monitor_port = /dev/ttyACM2

[env:nodec]
build_src_filter = +<nodec/*.cpp>
upload_port  = /dev/ttyACM4
monitor_port = /dev/ttyACM4
```.text,
  [Potongan `platformio.ini` dengan port yang dipin per environment],
  "lst:m06-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week06_ble_mesh/platformio.ini",
  [`platformio.ini` Modul 06 pada repositori],
  "lst:m06-ini",
)

#kode-berkas("week06_ble_mesh/src/nodea/main.cpp",
  [`src/nodea/main.cpp` --- sumber pesan],
  "lst:m06-nodea",
  pecah: true,
)

#kode-berkas("week06_ble_mesh/src/nodeb/main.cpp",
  [`src/nodeb/main.cpp` --- relay dual-role (server dan client)],
  "lst:m06-nodeb",
  pecah: true,
)

#kode-berkas("week06_ble_mesh/src/nodec/main.cpp",
  [`src/nodec/main.cpp` --- penerima akhir],
  "lst:m06-nodec",
  pecah: true,
)

== Build dan Flash

Urutan penting: relay dulu, baru ujung-ujungnya.

#keluaran("pio run -d week06_ble_mesh -e nodeb -t upload
pio run -d week06_ble_mesh -e nodea -t upload
pio run -d week06_ble_mesh -e nodec -t upload -t monitor")

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
  [Environment `nodea`, `nodeb`, dan `nodec` dikenali PlatformIO.],
  [Serial Monitor 115200 baud siap (3 terminal).],
  [Formasi garis A, B, C sudah disiapkan.],
))

== Percobaan

=== EXP-01 --- Menyalakan Relay (Node B)

Unggah environment `nodeb` lebih dulu, lalu verifikasi dual-role: server
(advertise `MESH_NODE_B` untuk C) sekaligus client (scan `MESH_NODE_A`).

#diagram(```
        server (untuk C)         client (ke A)
   advertise MESH_NODE_B       scan MESH_NODE_A
             \                   /
              +---- Node B -----+
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Pesan awal relay (`Node B (relay) starting...`)], [#isian],
    [Nama BLE relay], [#isian],
    [Characteristic yang dipakai (UUID akhir)], [#isian],
    [Berapa peran radio yang dijalankan Node B?], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m06-exp01",
)

#buka-abstraksi[
  Di `src/nodeb/main.cpp`, tunjukkan *dua blok kode terpisah*: satu yang
  membuat `NimBLEServer` (untuk C) dan satu yang membuat `NimBLEClient` (ke A).
  Keduanya hidup di board yang sama dengan satu radio. Pertanyaan yang harus
  dijawab sebelum lanjut: saat B sedang mengirim notify ke C, apakah B masih
  bisa menerima notify dari A pada saat yang sama?
]

#checkpoint[
  Node B mencetak baris start-nya dan tidak crash. Jika board reboot berulang
  (boot loop), kemungkinan besar radio kehabisan resource --- periksa jumlah
  koneksi maksimum di konfigurasi NimBLE.
]

=== EXP-02 --- Menutup Rantai (Node A dan Node C)

Unggah `nodea` (server, kirim `A:n` tiap 4 s saat relay terhubung) dan `nodec`
(client yang scan `MESH_NODE_B` lalu subscribe). Amati Serial Monitor ketiga
node dan verifikasi jejak pesan per hop.

#diagram(```
 A: setup ──► advertise ──► B konek ke A ──► A kirim "A:n" / 4 s
 B: onNotifyFromA() ──► pendingForward ──► notify ke C
 C: onNotifyFromB() ──► cetak "Pesan tiba (via A -> B -> C)"
```.text)

*Expected output*

/ Node A: `Node A (sumber pesan) starting...`,
  `Menunggu relay (Node B)...`, `Node B terhubung`, `Kirim ke B: A:1`, dan
  seterusnya.

/ Node B: `Node B (relay) starting...`, `Node A ditemukan`,
  `Terhubung ke Node A`, `Koneksi ke A berhasil`, `Node C terhubung`,
  `Terima dari A: A:1 (diteruskan)`, `Teruskan ke C: A:1`, dan seterusnya.

/ Node C: `Node C (penerima akhir) starting...`, `Scanning Node B...`,
  `Node B ditemukan`, `Terhubung ke Node B`, `Koneksi ke B berhasil`,
  `Pesan tiba (via A -> B -> C): A:1`, dan seterusnya.

#checkpoint[
  Cocokkan *nomor pesan yang sama* di tiga Serial Monitor: `Kirim ke B: A:5` di
  A, `Teruskan ke C: A:5` di B, dan `Pesan tiba ...: A:5` di C. Jika nomor di C
  tertinggal jauh atau melompat, hentikan dan catat --- itu loss per hop yang
  akan diukur pada bagian Pengukuran.
]

=== EXP-03 --- Mode Kegagalan Rantai

+ *Matikan Node C* --- verifikasi B tetap menerima dari A dan tetap memanggil
  notify, tetapi tidak ada penerima akhir.
+ *Matikan Node B* --- amati Node A berhenti mengirim (syarat `relayConnected`
  tidak terpenuhi lagi).
+ Ukur dan bandingkan jumlah pesan di A dan di C selama 2 menit.

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Pesan terkirim A per 2 menit (harapan 30)], [#isian],
    [Pesan tiba di C per 2 menit], [#isian],
    [Perilaku saat Node C dimatikan], [#isian],
    [Perilaku saat Node B dimatikan], [#isian],
    [Apakah rantai pulih sendiri setelah B dinyalakan lagi?], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m06-exp03",
)

#checkpoint[
  Praktikan dapat menjelaskan mengapa matinya B menghentikan A (bukan sekadar
  "pesannya tidak sampai"), dengan menunjuk baris kode di
  `src/nodea/main.cpp`.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 3 × *ESP32-H2 DevKitM-1* dalam satu garis, capture 40 detik.

#keluaran("# Node A (ESP32-H2)          # Node B (ESP32-H2, relay)        # Node C (ESP32-H2)
[0.601] Node B terhubung     [0.602] Node C terhubung          [0.602] Terhubung ke Node B
[4.210] Kirim ke B: A:1      [4.207] Terima dari A: A:1        [4.410] Pesan tiba
[8.217] Kirim ke B: A:2      [4.207] Teruskan ke C: A:1                (via A -> B -> C): A:1")

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Rantai A ke B ke C terbentuk], [1,4 s setelah boot],
    [Pesan dikirim A], [9],
    [Pesan diteruskan B], [9],
    [Pesan tiba di C], [9 (0 % loss ujung-ke-ujung)],
    [Latency relay (B terima sampai C cetak)], [< 200 ms],
  ),
  [Hasil verifikasi hardware Modul 06],
  "tbl:m06-verifikasi",
)

== Pengukuran

Geser jarak hop A--B dan B--C (ukur dari posisi Node B); catat RSSI dan success
rate.

#tbl(
  table(
    columns: (auto, 1fr, 1.2fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak (per hop)], th[RSSI (dBm)], th[Latency A ke C (kasar)],
      th[Success (%)],
    ),
    [1 m], [#isian], [], [],
    [3 m], [#isian], [], [],
    [5 m], [#isian], [], [],
    [10 m], [#isian], [], [],
    [15 m], [#isian], [], [],
  ),
  [Lembar pengukuran jarak per hop Modul 06],
  "tbl:m06-ukur",
)

*Pengukuran per-hop* (pengamatan 2 menit) --- inti modul ini.

#tbl(
  table(
    columns: (1.2fr, 1fr, 1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Hop], th[Pesan dikirim], th[Pesan diterima], th[Loss (%)]),
    [A ke B], [#isian], [], [],
    [B ke C], [#isian], [], [],
    [A ke C (ujung-ke-ujung)], [#isian], [], [],
  ),
  [Lembar pengukuran loss per hop],
  "tbl:m06-perhop",
)

Periksa: apakah loss A ke C kira-kira sama dengan loss A ke B ditambah loss B
ke C? Jelaskan jika tidak.

*Uji jangkauan (wajib)* --- jauhkan A dan C sampai *tidak saling terjangkau
langsung*, buktikan dengan mematikan B (pesan berhenti), lalu nyalakan B lagi
(pesan kembali). Inilah bukti hop benar-benar menambah jangkauan.

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Apakah setiap pesan `A:n` yang dikirim Node A juga tiba di Node C? Hitung
  persentase kedatangan.
+ Bagaimana pengaruh jarak tiap hop terhadap RSSI dan keberhasilan relay?
+ Berapa tambahan latency karena melewati dua hop dibanding koneksi langsung
  satu hop? Bandingkan dengan data M04.
+ Pada hop mana loss lebih besar, dan apa penyebab yang mungkin?
+ Bandingkan relay multi-hop dengan topologi bintang M05: kapan relay lebih
  menguntungkan, dan apa harganya?

== Concept Check

+ Apa yang dimaksud relay pada jaringan mesh?
+ Mengapa Node B harus menjalankan peran server dan client sekaligus?
+ Apa keuntungan multi-hop dibanding komunikasi langsung dari sisi jangkauan
  dan daya pancar?
+ Apa keterbatasan simulasi mesh ini dibanding BLE Mesh (ESP-BLE-MESH)
  sebenarnya? Sebut minimal tiga.
+ Apa yang terjadi pada aliran pesan bila relay mati --- dan apa yang
  *seharusnya* terjadi pada mesh sungguhan?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Menambah hop dan mengukur loss tiap lompatan])[
  / CH-1 --- Tiga hop: Tambahkan Node D setelah C (A ke B ke C ke D): ubah C
    menjadi dual-role seperti B. Amati apakah pesan tetap utuh sampai D dan
    berapa tambahan latency per hop.

  / CH-2 --- Loss per hop otomatis: Beri nomor urut pada payload dan hitung
    loss di B dan di C secara otomatis. Contoh: B menerima 30 pesan, C hanya
    27, sehingga loss hop 2 = (30 − 27)/30 × 100 % = 10 %. Bandingkan dengan
    loss kumulatif A ke D pada CH-1.
]

#tujuan-prak(3, [Jejak hop dan pemulihan rantai])[
  / CH-3 --- Jejak hop: Ubah relay agar menambahkan penanda pada payload
    (`A:5|B`) sehingga jalur yang dilalui terbaca di penerima akhir. Diskusikan:
    apa yang hilang dari sifat _transparent forwarding_ akibat perubahan ini?

  / CH-4 --- Self-healing sederhana: Buat Node C melakukan scan ulang otomatis
    saat relay hilang, dan Node A menunggu relay kembali tanpa perlu reset.
    Ukur waktu pemulihan rantai, 5 percobaan.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (hop, relay, dual role, transparent forwarding).
+ Konfigurasi --- environment `nodea`, `nodeb`, `nodec`, UUID, dan interval
  4 s.
+ Hasil eksperimen --- log serial tiga node (EXP-01 sampai EXP-03 beserta
  checkpoint), termasuk pencocokan nomor pesan.
+ Data pengukuran --- tabel jarak *dan* tabel per-hop, beserta hasil uji
  jangkauan.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-2.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
