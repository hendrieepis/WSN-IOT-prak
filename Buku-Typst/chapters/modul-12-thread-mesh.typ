// ============================================================================
// Modul 12 — Mesh Thread IPv6 (Many-to-Many)
// Sumber: week12_thread_mesh/README.md; listing kode dibaca langsung dari
//         assets/code/week12_thread_mesh/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 12 — Mesh Thread IPv6 (Many-to-Many)", l: "bab:modul-12")

#identitas-modul(
  "Modul 12",
  [Mesh the Internet --- Mesh Thread IPv6 (Many-to-Many)],
  [ESP32-H2 · Thread · mesh IPv6 · level Advanced · 3 × 50 menit ·
   folder kode `week12_thread_mesh`],
)

#pengantar([Gambaran Umum])[
Modul 12 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut.
Misinya membangun mesh IPv6 yang mengatur dirinya sendiri, lalu merusaknya
dengan sengaja untuk melihat apakah ia pulih. Percobaan berjalan sebagai mesh
IPv6 tiga node dengan komunikasi many-to-many melalui multicast, diamati
melalui tiga terminal Serial Monitor pada 115200 baud.
]

== Pendahuluan

M11 membuktikan dua node Thread bisa saling kirim datagram. Di sini jumlahnya
tiga, dan *tidak ada peran yang ditentukan manusia* --- firmware ketiga node
identik kecuali `NODE_ID`. Bandingkan dengan Zigbee M10, tempat peran ZC, ZR,
dan ZED dipilih saat kompilasi: perbedaan ini adalah salah satu argumen
terkuat Thread, dan angka pemulihannya menjadi bahan M16.

Prasyaratnya ada dua: M11 untuk Active Dataset, mesh-local prefix, dan socket
UDP IPv6; serta M10 untuk konsep routing multi-hop. Yang dibangun di sini
adalah role election otomatis, komunikasi many-to-many melalui multicast,
deteksi loss berbasis counter, serta uji kegagalan node perantara beserta
pemulihannya. Semuanya dipakai lagi pada M13 ketika mesh ini disambungkan ke
Wi-Fi lewat gateway, M15 pada pipeline end-to-end, dan M16 ketika keandalan
mesh menjadi kriteria pemilihan protokol.

*Peta modul blok Thread*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [11], [Thread P2P: alamat IPv6, datagram UDP],
    [*12 (ini)*], [*Mesh many-to-many, role dipilih sendiri, self-healing*],
    [13], [Mesh Thread bertemu Wi-Fi lewat gateway ESP32-C6],
  ),
  [Peta modul blok Thread],
  "tbl:m12-peta",
)

*Kontrak data lab ini.* Payload `NODE<n>:<counter>` membawa *identitas sumber
dan nomor urut* sekaligus. Format ini yang membuat loss bisa dihitung tanpa
alat bantu apa pun --- cukup mencari lompatan angka di log. Pola yang sama
dipakai di M13 dan M15 sebagai `suhu:XX.X,#<seq>`.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membangun mesh IPv6 yang mengatur dan memulihkan dirinya])[
  + Membangun mesh Thread tiga node dengan dataset identik dan mencatat role
    yang dipilih stack untuk masing-masing (Leader, Router, atau Child).
  + Membuktikan komunikasi many-to-many: setiap node menerima pesan dari dua
    node lainnya, dicocokkan lewat alamat sumber dan counter.
  + Menghitung packet loss per node dari lompatan counter, dan mengukur latency
    1 hop dibanding 2 hop pada formasi garis.
  + Mengevaluasi self-healing: mengukur berapa lama mesh pulih setelah node
    relayer dimatikan, dan membandingkannya dengan relay manual M06 serta
    Zigbee M10.
]

*Kriteria keberhasilan*

#checklist((
  [Ketiga node saling menerima pesan (many-to-many).],
  [Role tiap node teridentifikasi dan tercatat, termasuk perubahannya setelah
   node dimatikan.],
  [Perilaku mesh saat relayer mati terdokumentasi dengan counter, bukan dengan
   kesan.],
  [Awalan Mesh-Local EID ketiga node sama.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (MLE,
Router ID assignment, partition merge, MPL) berada di buku teori terpisah.
Istilah kerja dirangkum pada @tbl:m12-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Thread mesh], [Setiap node Router dapat meneruskan paket node lain; jalur dibentuk otomatis.],
    [Leader], [Satu node terpilih mengelola jaringan; lainnya Router atau Child (`otGetDeviceRole()`).],
    [Mesh-Local EID (`fd..`)], [Alamat IPv6 unik per node dalam domain mesh (`fdde:ad00:beef:0:...`).],
    [Mesh-Local prefix], [Prefix `/64` milik jaringan; wajib identik di ketiga node, jika tidak multicast `ff03::` tidak diteruskan.],
    [Link-local (`fe80::`)], [Alamat per-interface antar tetangga 1 hop.],
    [Multicast `ff03::abcd`], [Realm-local; paket diteruskan ke seluruh mesh, semua anggota grup menerimanya.],
    [UDP port 5050], [Port aplikasi kirim dan terima (`OtUdp.beginMulticast(GROUP, PORT)`).],
    [Sequence/counter], [Pesan `NODE<n>:<count>` sehingga paket hilang terdeteksi dari lompatan counter.],
  ),
  [Istilah kerja Modul 12],
  "tbl:m12-istilah",
)

*Dataset harus identik, termasuk prefix mesh-local.* `DataSet::initNew()`
mengacak prefix mesh-local tiap board. Ketiga firmware karena itu memaksa
prefix yang sama sebelum `OThread.start()` seperti @lst:m12-prefix.

#kode(```cpp
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] =
    {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};   // fdde:ad00:beef::/64
otThreadSetMeshLocalPrefix(esp_openthread_get_instance(), &prefix);
```.text,
  [Prefix mesh-local yang dipaksakan di ketiga node],
  "lst:m12-prefix",
)

Bila dilewatkan, node tetap attach dan `Attached as: ...` tetap tercetak,
tetapi tidak ada satu pun baris `RX` --- gejala yang mudah disalahartikan
sebagai masalah jarak atau interferensi. Periksa awalan Mesh-Local EID: harus
sama di semua node.

*Sekuens protokol yang diamati*

#diagram(```
 Node1 ──TX "NODE1:1" (multicast)──► Node2, Node3
 Node2 ──TX "NODE2:1" (multicast)──► Node1, Node3   (tiap 5 detik, semua node)
 Node3 ──TX "NODE3:1" (multicast)──► Node1, Node2
```.text)

== Topologi

#diagram(```
                    BOARD #1
              +-----------------+
              |    ESP32-H2     |
              |     Node1       |<----------------+
              | (Leader/Router) |                 |
              +--------+--------+                 |
                       |                          |
          +------------+------------+             |
          |                         |             |
     BOARD #2                  BOARD #3           |
 +--------v-------+       +---------v------+      |
 |    ESP32-H2    |<----->|    ESP32-H2    |------+
 |     Node2      |  RF   |     Node3      |
 | (Router/Child) |       | (Router/Child) |
 +----------------+       +----------------+
    env: node2               env: node3
   Thread: ESP_OT_MESH, channel 15, PAN 0xABCD,
           mesh-local prefix fdde:ad00:beef::/64
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, auto, 1fr, 1.1fr),
    align: (left, left, left, left, left, left),
    inset: (x: 0.35em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Node], th[Board], th[Env], th[`NODE_ID`], th[Role Thread], th[Aksi],
    ),
    [Node1], [ESP32-H2], [`node1`], [1], [Leader/Router/Child (dinamis)],
    [TX `NODE1:<n>` multicast tiap 5 s],
    [Node2], [ESP32-H2], [`node2`], [2], [Leader/Router/Child (dinamis)],
    [TX `NODE2:<n>` multicast tiap 5 s],
    [Node3], [ESP32-H2], [`node3`], [3], [Leader/Router/Child (dinamis)],
    [TX `NODE3:<n>` multicast tiap 5 s],
  ),
  [Peran tiap node Modul 12],
  "tbl:m12-topologi",
)

Ketiganya *ESP32-H2 DevKitM-1* dengan firmware yang sama kecuali `NODE_ID`.
Role Thread dipilih otomatis oleh stack dan bisa berbeda tiap kali dinyalakan
--- bukan ditentukan oleh nama environment.

*Formasi awal:* segitiga dengan jarak antar node ± 3 m. Formasi garis (untuk
membuktikan multi-hop) dipakai di EXP-03.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan OpenThread
(`OThread` dan `OThreadUDP`).

#tbl(
  table(
    columns: (auto, 1fr, 1.4fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1 (env `node1`, `node2`, `node3`)], [3],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [3],
    [3], [PC/Laptop], [PlatformIO Core/IDE, idealnya 3 port USB bebas], [1],
    [4], [Power bank atau catu daya USB], [wajib untuk formasi garis], [3],
    [5], [Ruang uji], [area untuk segitiga ±3 m dan garis panjang], [---],
  ),
  [Alat dan bahan Modul 12],
  "tbl:m12-alat",
)

*Parameter jaringan yang wajib identik di ketiga node*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Nilai]),
    [Network name], [`ESP_OT_MESH`],
    [Channel dan PAN ID], [15 dan `0xABCD`],
    [Ext PAN ID], [`DE:AD:00:BE:EF:00:CA:FE`],
    [Mesh-local prefix], [`fdde:ad00:beef::/64`],
    [Grup multicast dan port], [`ff03::abcd` : 5050],
    [Interval TX], [5000 ms],
  ),
  [Parameter jaringan Thread Modul 12],
  "tbl:m12-dataset",
)

== Kode Program

#sumber-kode("week12_thread_mesh",
  ("platformio.ini", "src/node1/main.cpp", "src/node2/main.cpp",
   "src/node3/main.cpp"))

#kode-berkas("week12_thread_mesh/platformio.ini",
  [`platformio.ini` Modul 12 pada repositori],
  "lst:m12-ini",
)

#kode-berkas("week12_thread_mesh/src/node1/main.cpp",
  [`src/node1/main.cpp` --- anggota mesh dengan `NODE_ID` 1],
  "lst:m12-node1",
  pecah: true,
)

#kode-berkas("week12_thread_mesh/src/node2/main.cpp",
  [`src/node2/main.cpp` --- anggota mesh dengan `NODE_ID` 2],
  "lst:m12-node2",
  pecah: true,
)

#kode-berkas("week12_thread_mesh/src/node3/main.cpp",
  [`src/node3/main.cpp` --- anggota mesh dengan `NODE_ID` 3],
  "lst:m12-node3",
  pecah: true,
)

== Build dan Flash

#keluaran("for e in node1 node2 node3; do pio run -d week12_thread_mesh -e $e -t erase; done
pio run -d week12_thread_mesh -e node1 -t upload
pio run -d week12_thread_mesh -e node2 -t upload
pio run -d week12_thread_mesh -e node3 -t upload -t monitor")

*Pre-flight checklist*

#checklist((
  [`pio device list` dijalankan, tiga port dicatat dan diisikan pada tiap env.],
  [*Hapus dataset lama* ketiga board (`-t erase`) bila pernah dipakai modul
   Thread lain.],
  [Flash environment `node1`, `node2`, dan `node3` (firmware sama, `NODE_ID`
   1, 2, 3).],
  [Serial Monitor 115200 baud pada ketiga board (3 terminal).],
  [Dataset identik: `ESP_OT_MESH`, channel 15, PAN `0xABCD`, port 5050, prefix
   `fdde:ad00:beef::/64`.],
  [Formasi segitiga ± 3 m sudah disiapkan.],
))

== Percobaan

=== EXP-01 --- Pembentukan Mesh dan Pemilihan Role

Nyalakan ketiga board. Tiap node men-commit dataset (termasuk prefix
mesh-local), start, menunggu attach (role sekurangnya Child), lalu join grup
multicast. Board yang selesai boot lebih dulu umumnya terpilih menjadi Leader.

#diagram(```
 [board pertama] dataset (+ ML prefix) ──► start ──► Leader
 [board kedua]   dataset (+ ML prefix) ──► start ──► attach ──► Router/Child
 [board ketiga]  dataset (+ ML prefix) ──► start ──► attach ──► Router/Child
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1.1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Role Node1], [… (Leader/Router/Child)],
    [Role Node2], [… (Leader/Router/Child)],
    [Role Node3], [… (Leader/Router/Child)],
    [Awalan Mesh-Local EID sama di ketiga node?], [… (harus `fdde:ad00:beef:0:`)],
    [Waktu attach tiap node (detik)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m12-exp01",
)

#buka-abstraksi[
  Matikan board yang menjadi Leader, tunggu, lalu amati role kedua node sisanya
  di Serial Monitor. Salah satunya akan *naik menjadi Leader* tanpa satu baris
  kode tambahan. Catat berapa lama peralihan itu. Bandingkan dengan M10: di
  Zigbee, coordinator tidak bisa digantikan --- matinya ZC berarti matinya
  jaringan.
]

#checkpoint[
  Ketiga node mencetak `Attached as: ...` dan awalan EID ketiganya sama. Jika
  ada yang berbeda, node itu berada di jaringan lain --- hapus NVS-nya dan
  flash ulang.
]

=== EXP-02 --- Multicast Many-to-Many

Setiap 5 detik tiap node mengirim `NODEn:<counter>` ke `ff03::abcd:5050` dan
menerima pesan node lain; alamat sumber mesh-local tercetak pada baris RX.

#diagram(```
 [tiap node] TX multicast ──► [semua node lain] RX [fdde:ad00:beef:0:...]: NODEx:c
```.text)

*Expected output --- contoh Node1*

#keluaran("Node1 (Thread) starting...
Attached as: Leader        <- bisa Router atau Child, tergantung urutan boot
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE1:1
RX [fdde:ad00:beef:0:yyyy:...]: NODE2:1
RX [fdde:ad00:beef:0:zzzz:...]: NODE3:1
TX multicast: NODE1:2
RX [fdde:ad00:beef:0:yyyy:...]: NODE2:2")

#checkpoint[
  Di *setiap* Serial Monitor muncul baris RX dari *dua* sumber berbeda (bukan
  satu). Jika hanya satu, node ketiga belum masuk mesh atau prefix-nya berbeda.
  Cocokkan juga counter: harus berurutan tanpa lompat.
]

=== EXP-03 --- Perubahan Topologi dan Kegagalan Node

+ *Formasi garis* N1, N2, N3 (N2 di tengah, N1 dan N3 dijauhkan sampai tidak
  saling terjangkau): amati apakah pesan NODE3 tetap diterima N1 (multi-hop)
  dengan counter berlanjut.
+ *Relayer mati* --- pada formasi garis, matikan N2; amati apakah N1 dan N3
  saling kehilangan paket. Catat counter terakhir yang diterima.
+ Nyalakan N2 lagi dan catat *waktu pemulihan* sampai counter kembali
  mengalir.
+ *Jarak* --- regangkan jarak antar node dan amati kenaikan loss dari lompatan
  counter.

*Data capture*

#tbl(
  table(
    columns: (1.7fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Counter NODE3 terakhir diterima N1 sebelum N2 mati], [#isian],
    [Apakah N1 dan N3 benar-benar putus saat N2 mati?], [#isian],
    [Waktu pemulihan setelah N2 hidup lagi (s)], [#isian],
    [Latency 1 hop dibanding 2 hop], [#isian],
    [Role setelah N2 kembali --- berubah?], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m12-exp03",
)

#checkpoint[
  Tersedia bukti kuantitatif untuk dua klaim terpisah: (a) pesan N3 mencapai N1
  lewat N2, dan (b) mesh pulih sendiri. Klaim (a) hanya sah bila N1 dan N3
  memang *tidak* saling terjangkau langsung --- buktikan dulu dengan mematikan
  N2 dan melihat aliran berhenti.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 3 × *ESP32-H2 DevKitM-1* (flash di-erase lebih dulu, formasi
meja kurang dari 1 m), capture 50 detik.

#keluaran("# Node1 (ESP32-H2)              # Node3 (ESP32-H2)
[9.617] Attached as: Router     [7.410] Attached as: Leader
[9.817] TX multicast: NODE1:1   [7.410] TX multicast: NODE3:1
                                [9.814] RX [...:385a:...]: NODE1:1
                                [11.016] RX [...:390e:...]: NODE2:1")

#tbl(
  table(
    columns: (1.5fr, 1.1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Role terpilih (Node1, Node2, Node3)], [Router, Child, Leader],
    [Awalan Mesh-Local EID ketiga node], [`fdde:ad00:beef:0:` (identik)],
    [Pesan diterima tiap node dari 2 node lain], [9 + 9, counter berurutan tanpa lompatan],
    [Loss], [0 % pada jarak meja],
  ),
  [Hasil verifikasi hardware Modul 12],
  "tbl:m12-verifikasi",
)

Karena semua node saling terjangkau langsung, hasil ini *belum* membuktikan
routing multi-hop --- itu tugas EXP-03 formasi garis.

== Pengukuran

*Tabel jarak* (amati RX pada node terjauh, 10 pesan sumber).

#tbl(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Jarak], th[RSSI], th[Latency], th[Success]),
    [1 m], [#isian], [], [… / 10],
    [3 m], [#isian], [], [… / 10],
    [5 m], [#isian], [], [… / 10],
    [10 m], [#isian], [], [… / 10],
    [15 m], [#isian], [], [… / 10],
  ),
  [Lembar pengukuran jarak Modul 12],
  "tbl:m12-ukur",
)

*Tabel per-node* (amati 1 menit, tiap node ± 12 TX).

#tbl(
  table(
    columns: (1.4fr, 1fr, 1.1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[RSSI], th[Paket diterima], th[Loss (%)]),
    [Node1 (dari N2 dan N3)], [#isian], [… / 24], [],
    [Node2 (dari N1 dan N3)], [#isian], [… / 24], [],
    [Node3 (dari N1 dan N2)], [#isian], [… / 24], [],
  ),
  [Lembar pengukuran per-node Modul 12],
  "tbl:m12-pernode",
)

*Tabel pembanding self-healing --- wajib.* Isi dari data tiga modul.

#tbl(
  table(
    columns: (1.2fr, auto, 1.1fr, auto, 1.1fr),
    align: (left, left, left, left, left),
    inset: (x: 0.4em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Pendekatan], th[Modul], th[Penentu jalur], th[Pulih sendiri?],
      th[Waktu pemulihan],
    ),
    [Relay manual (BLE)], [M06], [kode aplikasi], [#isian], [],
    [Routing Zigbee], [M10], [stack Zigbee], [#isian], [],
    [Mesh Thread], [M12], [stack Thread], [#isian], [],
  ),
  [Tabel pembanding self-healing M06, M10, dan M12],
  "tbl:m12-banding",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Role apa yang dipegang tiap node setelah attach? Apakah berubah setelah node
  dimatikan lalu dinyalakan?
+ Pada formasi garis, berapa hop yang ditempuh pesan NODE3 ke NODE1, dan apa
  buktinya dari latency atau loss?
+ Bagaimana pola loss tiap node ketika jarak diperbesar? Apakah merata atau ada
  node yang lebih rentan?
+ Apa yang terjadi pada komunikasi N1 dan N3 ketika N2 (relayer) dimatikan?
  Jelaskan dari counter yang berhenti atau berlanjut.
+ Bandingkan keandalan mesh ini dengan multi-node Zigbee M09 dan M10 serta
  relay manual M06, memakai tabel pembanding self-healing.

== Concept Check

+ Bagaimana Thread memilih Leader dan apa tugas Leader dalam mesh?
+ Mengapa pesan multicast `ff03::abcd` dapat diterima semua node tanpa alamat
  tujuan per node?
+ Apa perbedaan alamat mesh-local EID (`fd...`) dan link-local (`fe80::`) dalam
  forwarding mesh?
+ Apa yang membuat node Router dapat meneruskan paket sedangkan Child tidak?
+ Bagaimana format pesan `NODEn:counter` membantu deteksi paket hilang, dan apa
  yang tidak bisa ia deteksi?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Menambah node dan menghitung loss dari counter])[
  / CH-1 --- Node keempat: Tambah `node4`: salin `src/node3`, ubah `NODE_ID`
    menjadi 4, lalu tambahkan env `node4` di `platformio.ini`. Amati total
    pesan RX per menit di tiap node dan periksa apakah loss naik.

  / CH-2 --- Packet loss dari counter (wajib): Hitung loss otomatis dari
    lompatan counter per sumber. Contoh: Node2 mengirim `NODE2:1..60`, Node1
    menerima 54, sehingga loss = (60 − 54)/60 × 100 % = 10 %.
]

#tujuan-prak(3, [Memetakan hop dan mengukur self-healing])[
  / CH-3 --- Pemetaan hop: Pindahkan Node3 sehingga harus 2 hop ke Node1;
    bandingkan latency 1 hop dan 2 hop dari stempel waktu TX dan RX. Sajikan
    sebagai tabel jarak, hop, dan latency.

  / CH-4 --- Ukur self-healing secara kuantitatif: Matikan Leader (bukan
    relayer), catat berapa detik sampai ada node lain mengambil alih dan aliran
    pesan kembali normal. Ulangi 5 kali, lalu laporkan rata-rata dan
    sebarannya.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (mesh Thread, role election, multicast realm-local,
  forwarding, mesh-local prefix).
+ Konfigurasi --- env `node1` sampai `node3`, dataset `ESP_OT_MESH`, port 5050,
  grup `ff03::abcd`, serta interval 5 s.
+ Hasil eksperimen --- log ketiga node, skema formasi (segitiga dan garis),
  serta hasil percobaan "buka abstraksinya".
+ Data pengukuran --- tabel jarak, tabel per-node, dan tabel pembanding
  self-healing M06, M10, dan M12.
+ Analisis dan concept check.
+ Challenge --- minimal CH-2 dan CH-4.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
