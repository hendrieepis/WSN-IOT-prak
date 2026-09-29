// ============================================================================
// Modul 12 — Mesh Thread IPv6 (Many-to-Many)
// Sumber: week12_thread_mesh/README.md; listing kode dibaca langsung dari
//         assets/code/week12_thread_mesh/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

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

*Expected output --- contoh Node1* (dari uji di board; alamat dan peran di
board Anda akan berbeda)

#keluaran("Node1 (Thread) starting...
Attached as: Router        <- bisa Leader atau Child, tergantung urutan boot
Info network Thread:
  Peran          : Router
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x1C00
  Extended addr  : 56:22:E4:9A:19:AC:56:CA
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE1:1
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
TX multicast: NODE1:2
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2")

Blok info network ketiga node harus sama pada *Network name, Channel, PAN ID,
dan Extended PAN ID*. Dari `RLOC16` terbaca topologinya: pada uji ini Node3
Leader `0x6C00`, Node1 Router `0x1C00`, dan Node2 Child `0x1C01` --- Router
ID-nya sama dengan Node1, jadi *parent Node2 adalah Node1*. Padanan alamat
XBee/Zigbee/Thread ada di Modul 11.


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


// Log serial lengkap dari week12_thread_mesh/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1, firmware versi terbaru: setelah attach, tiap node mencetak info network Thread — peran, network name, channel, PAN ID, Extended PAN ID, RLOC16, Extended Address, EUI-64, dan Mesh-Local EID. Log direkam 60 detik dengan `monitor_serial.py` (ketiga port dalam satu komputer, satu sumbu waktu) lewat port UART CH343 di Windows. Board di-`erase` lalu di-flash; monitor me-reset semua board saat port dibuka, sehingga semua node boot hampir bersamaan.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: (left, left, left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Peran (terpilih)], th[RLOC16], th[EUI-64 (pabrik)], th[Extended addr (acak)], th[Port serial (UART)]),
      [Node1], [Router], [`0x1C00`], [`74:4D:BD:FF:` \ `FE:61:E6:2C`], [`56:22:E4:9A:` \ `19:AC:56:CA`], [`COM5`],
      [Node2], [Child (parent: Node1)], [`0x1C01`], [`74:4D:BD:FF:` \ `FE:61:E8:C1`], [`FE:8E:2B:FE:` \ `9E:44:7E:ED`], [`COM11`],
      [Node3], [*Leader*], [`0x6C00`], [`74:4D:BD:FF:` \ `FE:61:F3:97`], [`AA:64:77:10:` \ `45:C5:74:41`], [`COM13`],
    ),
    [Board dan port pada rekaman log serial Modul 12],
    "tbl:m12-log-1",
  )

  Network `ESP_OT_MESH`, channel *15*, PAN ID *`0xABCD`*, Extended PAN ID *`DE:AD:00:BE:EF:00:CA:FE`* — sama di ketiga node. Group multicast `ff03::abcd`, port UDP 5050.

  *Node1 --- COM5*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node1 (Thread) starting...
Attached as: Router
Info network Thread:
  Peran          : Router
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x1C00
  Extended addr  : 56:22:E4:9A:19:AC:56:CA
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE1:1
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
TX multicast: NODE1:2
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
TX multicast: NODE1:3
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
TX multicast: NODE1:4
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
TX multicast: NODE1:5
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
TX multicast: NODE1:6
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
TX multicast: NODE1:7
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
TX multicast: NODE1:8
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
TX multicast: NODE1:9
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
TX multicast: NODE1:10
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
TX multicast: NODE1:11", pecah: true)

  *Node2 --- COM11*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node2 (Thread) starting...
E (11623) OT_STATE: handle_ot_role_change(105): Failed to get the active dataset
Attached as: Child
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x1C01
  Extended addr  : FE:8E:2B:FE:9E:44:7E:ED
  EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
  Mesh-Local EID : fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE2:1
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
TX multicast: NODE2:2
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
TX multicast: NODE2:3
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
TX multicast: NODE2:4
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
TX multicast: NODE2:5
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
TX multicast: NODE2:6
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
TX multicast: NODE2:7
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
TX multicast: NODE2:8
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
TX multicast: NODE2:9
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
TX multicast: NODE2:10
RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11", pecah: true)

  *Node3 --- COM13*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node3 (Thread) starting...
Attached as: Leader
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_MESH
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C00
  Extended addr  : AA:64:77:10:45:C5:74:41
  EUI-64         : 74:4D:BD:FF:FE:61:F3:97
  Mesh-Local EID : fdde:ad00:beef:0:f915:1df2:1a01:26c9
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE3:1
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:1
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
TX multicast: NODE3:2
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
TX multicast: NODE3:3
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
TX multicast: NODE3:4
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
TX multicast: NODE3:5
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
TX multicast: NODE3:6
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
TX multicast: NODE3:7
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
TX multicast: NODE3:8
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
TX multicast: NODE3:9
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
TX multicast: NODE3:10
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
TX multicast: NODE3:11
RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11", pecah: true)

  *Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)*

  #keluaran("[   0.682] Node3  | Node3 (Thread) starting...
[   0.682] Node2  | Node2 (Thread) starting...
[   0.682] Node1  | Node1 (Thread) starting...
[   7.547] Node3  | Attached as: Leader
[   7.547] Node3  | Info network Thread:
[   7.547] Node3  |   Peran          : Leader
[   7.547] Node3  |   Network name   : ESP_OT_MESH
[   7.547] Node3  |   Channel        : 15
[   7.547] Node3  |   PAN ID         : 0xABCD
[   7.547] Node3  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[   7.547] Node3  |   RLOC16         : 0x6C00
[   7.763] Node3  |   Extended addr  : AA:64:77:10:45:C5:74:41
[   7.763] Node3  |   EUI-64         : 74:4D:BD:FF:FE:61:F3:97
[   7.763] Node3  |   Mesh-Local EID : fdde:ad00:beef:0:f915:1df2:1a01:26c9
[   7.763] Node3  | Bergabung ke mesh, siap kirim/terima.
[   7.763] Node3  | TX multicast: NODE3:1
[  10.063] Node1  | Attached as: Router
[  10.064] Node1  | Info network Thread:
[  10.064] Node1  |   Peran          : Router
[  10.064] Node1  |   Network name   : ESP_OT_MESH
[  10.064] Node1  |   Channel        : 15
[  10.064] Node1  |   PAN ID         : 0xABCD
[  10.064] Node1  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  10.064] Node1  |   RLOC16         : 0x1C00
[  10.282] Node1  |   Extended addr  : 56:22:E4:9A:19:AC:56:CA
[  10.283] Node1  |   EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
[  10.283] Node1  |   Mesh-Local EID : fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
[  10.283] Node1  | Bergabung ke mesh, siap kirim/terima.
[  10.283] Node1  | TX multicast: NODE1:1
[  10.297] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:1
[  11.816] Node2  | E (11623) OT_STATE: handle_ot_role_change(105): Failed to get the active dataset
[  11.816] Node2  | Attached as: Child
[  11.816] Node2  | Info network Thread:
[  11.816] Node2  |   Peran          : Child
[  11.816] Node2  |   Network name   : ESP_OT_MESH
[  11.816] Node2  |   Channel        : 15
[  11.816] Node2  |   PAN ID         : 0xABCD
[  12.048] Node2  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  12.048] Node2  |   RLOC16         : 0x1C01
[  12.048] Node2  |   Extended addr  : FE:8E:2B:FE:9E:44:7E:ED
[  12.048] Node2  |   EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
[  12.048] Node2  |   Mesh-Local EID : fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d
[  12.048] Node2  | Bergabung ke mesh, siap kirim/terima.
[  12.048] Node2  | TX multicast: NODE2:1
[  12.048] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
[  12.111] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:1
[  12.778] Node3  | TX multicast: NODE3:2
[  12.786] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
[  12.834] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:2
[  15.284] Node1  | TX multicast: NODE1:2
[  15.297] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
[  15.297] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:2
[  17.039] Node2  | TX multicast: NODE2:2
[  17.052] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
[  17.129] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:2
[  17.778] Node3  | TX multicast: NODE3:3
[  17.791] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
[  17.791] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:3
[  20.290] Node1  | TX multicast: NODE1:3
[  20.311] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
[  20.311] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:3
[  22.041] Node2  | TX multicast: NODE2:3
[  22.054] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
[  22.097] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:3
[  22.776] Node3  | TX multicast: NODE3:4
[  22.791] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
[  22.791] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:4
[  25.296] Node1  | TX multicast: NODE1:4
[  25.312] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
[  25.313] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:4
[  27.059] Node2  | TX multicast: NODE2:4
[  27.061] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
[  27.075] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:4
[  27.787] Node3  | TX multicast: NODE3:5
[  27.802] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
[  27.802] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:5
[  30.308] Node1  | TX multicast: NODE1:5
[  30.323] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
[  30.323] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:5
[  32.063] Node2  | TX multicast: NODE2:5
[  32.063] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
[  32.128] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:5
[  32.791] Node3  | TX multicast: NODE3:6
[  32.800] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
[  32.804] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:6
[  35.322] Node1  | TX multicast: NODE1:6
[  35.323] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
[  35.328] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:6
[  37.060] Node2  | TX multicast: NODE2:6
[  37.075] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
[  37.140] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:6
[  37.794] Node3  | TX multicast: NODE3:7
[  37.807] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
[  37.807] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:7
[  40.334] Node1  | TX multicast: NODE1:7
[  40.334] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
[  40.334] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:7
[  42.076] Node2  | TX multicast: NODE2:7
[  42.092] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
[  42.123] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:7
[  42.800] Node3  | TX multicast: NODE3:8
[  42.815] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
[  42.816] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:8
[  45.334] Node1  | TX multicast: NODE1:8
[  45.349] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
[  45.350] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:8
[  47.077] Node2  | TX multicast: NODE2:8
[  47.093] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
[  47.109] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:8
[  47.813] Node3  | TX multicast: NODE3:9
[  47.828] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
[  47.828] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:9
[  50.344] Node1  | TX multicast: NODE1:9
[  50.359] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
[  50.360] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:9
[  52.089] Node2  | TX multicast: NODE2:9
[  52.105] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
[  52.136] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:9
[  52.804] Node3  | TX multicast: NODE3:10
[  52.820] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
[  52.820] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:10
[  55.345] Node1  | TX multicast: NODE1:10
[  55.358] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
[  55.358] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:10
[  57.094] Node2  | TX multicast: NODE2:10
[  57.110] Node1  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
[  57.141] Node3  | RX [fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d]: NODE2:10
[  57.823] Node3  | TX multicast: NODE3:11
[  57.838] Node1  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
[  57.838] Node2  | RX [fdde:ad00:beef:0:f915:1df2:1a01:26c9]: NODE3:11
[  60.357] Node1  | TX multicast: NODE1:11
[  60.371] Node2  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11
[  60.371] Node3  | RX [fdde:ad00:beef:0:d44d:fcf1:5002:f8c7]: NODE1:11", pecah: true)

  *Ringkasan `monitor_serial.py`*

  #keluaran("Durasi: 60.4 s
  Node1  Router  COM5             53 baris, boot 1x, attach  9.69 s sejak boot
         EID fdde:ad00:beef:0:d44d:fcf1:5002:f8c7
         network ESP_OT_MESH, channel 15, PAN 0xABCD, RLOC16 0x1C00, EUI-64 74:4D:BD:FF:FE:61:E6:2C
  Node2  Child   COM11            53 baris, boot 1x, attach 11.44 s sejak boot, 1 peringatan OT
         EID fdde:ad00:beef:0:6c6f:63ae:ba2c:a98d
         network ESP_OT_MESH, channel 15, PAN 0xABCD, RLOC16 0x1C01, EUI-64 74:4D:BD:FF:FE:61:E8:C1
  Node3  Leader  COM13            54 baris, boot 1x, attach  7.17 s sejak boot
         EID fdde:ad00:beef:0:f915:1df2:1a01:26c9
         network ESP_OT_MESH, channel 15, PAN 0xABCD, RLOC16 0x6C00, EUI-64 74:4D:BD:FF:FE:61:F3:97
  Network name/Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Link (pengirim -> penerima)  kirim  terima    loss   TX->RX ms rata2 (min..max)   jeda terpanjang
--------------------------------------------------------------------------------------------------
Node1 -> Node2                  10      10     0.0%       13 (0..21)                  5.0 s
Node1 -> Node3                  11      11     0.0%       13 (0..22)                  5.0 s
Node2 -> Node1                  10      10     0.0%       11 (-0..16)                 5.0 s
Node2 -> Node3                  10      10     0.0%       54 (16..89)                 5.1 s
Node3 -> Node1                  10      10     0.0%       14 (8..15)                  5.0 s
Node3 -> Node2                  10      10     0.0%       18 (9..56)                  5.0 s

Jeda terpanjang = selang terlama antara dua pesan yang diterima dari pengirim itu (normal ~5 s);
selisih TX->RX memakai timestamp PC (kasar).", pecah: true)

  *Catatan*

  - *Info network cocok di ketiga node*: network name, channel, PAN ID, dan Extended PAN ID sama (dari dataset yang ditulis kode).
  - *Peran dipilih jaringan, bukan kode.* Node3 attach paling dulu (7,2 s) dan menjadi *Leader*; Node1 menjadi *Router*; Node2 menjadi *Child*.
  - *RLOC16 memperlihatkan topologi.* Leader `0x6C00` = Router ID 27; Node1 `0x1C00` = Router ID 7; Node2 `0x1C01` = Router ID 7 + Child ID 1, artinya *parent Node2 adalah Node1*, bukan Leader.
  - Selisih TX → RX paling besar pada link Node2 → Node3 (rata-rata 54 ms, lainnya 11–18 ms), sesuai dengan pesan Child yang harus lewat parent-nya.
  - *Padanan alamat* (bandingkan dengan XBee dan Zigbee di Modul 08): `RLOC16` ≈ MY (alamat 16-bit, dibagikan jaringan dan *bisa berubah* bila peran/parent berubah); `EUI-64` = SH+SL (alamat pabrik, tetap); `Channel` = CH; `PAN ID` = OI; `Extended PAN ID` = OP.
  - *Extended addr ≠ EUI-64.* Thread memakai Extended Address *acak* sebagai alamat MAC 64-bit (privasi), berbeda dengan Zigbee yang memakai IEEE address pabrik. Alamat yang tetap untuk mengenali board tetap EUI-64.
  - *Mesh-Local EID* adalah alamat IPv6 node di dalam mesh; alamat ini yang muncul di baris `RX [...]`. Awalannya (`fdde:ad00:beef:0:`) harus sama di semua node.
  - Semua link *0 % loss* selama rekaman, jeda terpanjang ±5 s (sesuai interval kirim 5 s).
  - `E (…) OT_STATE: … Failed to get the active dataset` di Node2 adalah peringatan non-fatal saat transisi role, tidak mengganggu komunikasi.
  - Selisih waktu memakai timestamp PC, jadi kasar (resolusi USB-serial).
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

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
