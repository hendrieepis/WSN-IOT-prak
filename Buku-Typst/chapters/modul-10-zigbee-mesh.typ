// ============================================================================
// Modul 10 — Zigbee Mesh: Routing Multi-Hop
// Sumber: week10_zigbee_mesh/README.md; listing kode dibaca langsung dari
//         assets/code/week10_zigbee_mesh/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 10 — Zigbee Mesh: Routing Multi-Hop", l: "bab:modul-10")

#identitas-modul(
  "Modul 10",
  [Route Through the Mesh --- Zigbee Mesh: Routing Multi-Hop],
  [ESP32-H2 · Zigbee · ZC ke ZR ke ZED · level Advanced · 3 × 50 menit ·
   folder kode `week10_zigbee_mesh`],
)

#pengantar([Gambaran Umum])[
Modul 10 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut.
Misinya membuktikan router benar-benar mengangkut trafik milik node lain,
sekaligus mengukur harga hop keduanya. Percobaan berjalan sebagai mesh
multi-hop dari coordinator ke router lalu ke end device, diamati melalui tiga
terminal Serial Monitor pada 115200 baud dengan LED RGB bawaan sebagai penanda
visual.
]

== Pendahuluan

M06 sudah memperkenalkan hop --- tetapi jalurnya ditulis sendiri di dalam kode.
Di sini jalur ditentukan *stack*: end device memilih parent terbaik sendiri,
dan router meneruskan trafik tanpa satu baris kode penerusan pun di sketch.
Membandingkan dua pendekatan ini (relay manual M06 dibanding routing otomatis
M10) adalah inti analisis modul ini, dan bekalnya dipakai lagi saat Thread
melakukan hal serupa di atas IPv6 (M12).

Prasyaratnya ada dua: M09 untuk binding table, multi-node, dan penghapusan NVS;
serta M06 untuk konsep hop dan loss per hop. Yang dibangun di sini adalah peran
Router (ZR), pemilihan parent secara otomatis, routing multi-hop, perbandingan
latency satu hop dengan dua hop, dan pengenalan status orphan. Semuanya dipakai
lagi pada M12 ketika mesh Thread menambahkan role election, M13 ketika gateway
berperan sebagai tepi jaringan, dan M16 ketika jangkauan mesh menjadi kriteria
pemilihan protokol.

*Peta modul blok Zigbee (penutup blok)*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [07], [802.15.4 telanjang],
    [08], [Jaringan Zigbee terbentuk: join, binding],
    [09], [Satu coordinator, banyak end device (binding table)],
    [*10 (ini)*], [*Router meneruskan trafik --- jangkauan melampaui satu hop*],
    [11], [Pindah ke Thread: IPv6 di atas radio 802.15.4 yang sama],
  ),
  [Peta modul blok Zigbee],
  "tbl:m10-peta",
)

*Kontrak data lab ini.* Ukur *latency 1 hop dan 2 hop* pada modul ini. Angka
itu adalah pembanding langsung untuk latency relay manual M06 dan untuk mesh
Thread M12 --- tiga cara berbeda menyelesaikan masalah yang sama, di radio yang
sama.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membuktikan dan mengukur routing multi-hop Zigbee])[
  + Membangun jaringan Zigbee tiga peran (ZC, ZR, ZED) dan menunjukkan dari log
    bahwa ketiganya berada dalam satu jaringan.
  + Membuktikan end device mencapai coordinator *melalui* router pada formasi
    garis, dengan cara memutus jalur langsung dan mengamati akibatnya.
  + Mengukur selisih latency 1 hop (formasi dekat) dan 2 hop (formasi garis)
    lalu menyajikannya sebagai angka.
  + Menjelaskan status _orphan_ pada end device saat router dimatikan, serta
    apakah dan bagaimana jaringan memulihkan diri.
]

*Kriteria keberhasilan*

#checklist((
  [`Total device ter-bind: 2` tercetak di coordinator.],
  [EndLight tetap merespons pada formasi garis (ZC jauh dari ZED).],
  [Selisih latency 1 hop dan 2 hop terukur dan tercatat.],
  [Skenario router dimatikan diuji, perilaku ZED tercatat.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam
(algoritma routing AODV Zigbee, tabel routing, many-to-one routing) berada di
buku teori terpisah. Istilah kerja dirangkum pada @tbl:m10-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Coordinator (ZC)], [Membentuk jaringan, membuka window join 180 detik, sumber perintah ON/OFF.],
    [Router (ZR)], [Node penuh yang *meneruskan paket node lain* (`Zigbee.begin(ZIGBEE_ROUTER)`); juga punya aplikasi lampu (EP 10).],
    [End Device (ZED)], [Child yang bergabung lewat parent (bisa router), tidak meneruskan trafik.],
    [Parent selection], [ZED memilih parent dengan kualitas tautan terbaik --- bisa ZC, bisa ZR.],
    [Mesh], [Jalur alternatif otomatis; EndLight bisa mencapai ZC lewat ZR (2 hop) atau langsung (1 hop).],
    [Orphan], [Status ZED yang kehilangan parent dan belum menemukan pengganti.],
    [Endpoint/Cluster], [EP 5 (switch), EP 10 (router light), EP 11 (ED light), semuanya pada cluster On/Off.],
  ),
  [Istilah kerja Modul 10],
  "tbl:m10-istilah",
)

*Router bukan sekadar "node yang juga menyala".* Perbedaan sesungguhnya: router
*selalu mendengarkan* (tidak tidur) dan menyimpan tabel routing. Itulah mengapa
ZR memakai firmware ZCZR (lebih besar, partisi berbeda) dan mengapa ZR tidak
cocok untuk node baterai. Catat konsekuensi daya ini --- ia menjadi salah satu
argumen di M16.

*Sekuens protokol yang diamati*

#diagram(```
 ZC ──(lightOn/lightOff)──► ZR (EP10: nyala)
                 │
                 └── relay ──► ZED (EP11: nyala)
```.text)

== Topologi

#diagram(```
     BOARD #1                  BOARD #2                   BOARD #3
 +----------------+        +------------------+        +----------------+
 |    ESP32-H2    |  RF    |     ESP32-H2     |  RF    |    ESP32-H2    |
 |  Coordinator   | <----> |  RouterLight     | <----> |   EndLight     |
 |  (Switch, EP 5)|        |  (ZR, EP 10)     |        |  (ZED, EP 11)  |
 +----------------+        +------------------+        +----------------+
   env: coordinator          env: router                 env: enddevice
        \                                                  /
         \_______________ (1 hop bila dekat) ____________/
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Endpoint]),
    [Coordinator], [ESP32-H2 DevKitM-1], [`coordinator`], [ZC dan switch (ZCZR)], [EP 5],
    [RouterLight], [ESP32-H2 DevKitM-1], [`router`], [ZR dan light (ZCZR)], [EP 10],
    [EndLight], [ESP32-H2 DevKitM-1], [`enddevice`], [ZED dan light (ED)], [EP 11],
  ),
  [Peran tiap node Modul 10],
  "tbl:m10-topologi",
)

Ketiganya *ESP32-H2 DevKitM-1*. Router memakai firmware ZCZR
(`partitions_zczr.csv`) sedangkan end device memakai ED (`partitions_ed.csv`)
--- satu-satunya perbedaan perangkat keras adalah peran yang diberikan, bukan
chip.

*Rencana penempatan:* ZC, jarak, ZR, jarak, ZED, dalam satu garis. Formasi meja
(semua kurang dari 1 m) hanya untuk pemanasan; ia *tidak* membuktikan
multi-hop.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan library
`Zigbee` bawaan.

#tbl(
  table(
    columns: (auto, 1fr, 1.4fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1, LED RGB bawaan], [3],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [3],
    [3], [PC/Laptop], [PlatformIO Core/IDE], [1],
    [4], [Power bank atau catu daya USB], [wajib --- ZC dan ZED harus bisa dijauhkan], [3],
    [5], [Ruang uji], [lorong atau ruang panjang untuk formasi garis], [---],
  ),
  [Alat dan bahan Modul 10],
  "tbl:m10-alat",
)

== Kode Program

#sumber-kode("week10_zigbee_mesh",
  ("platformio.ini", "partitions_zczr.csv", "partitions_ed.csv",
   "src/coordinator/main.cpp", "src/router/main.cpp",
   "src/enddevice/main.cpp"))

*Tiga peran, dua tabel partisi* (@lst:m10-ini-readme).

#kode(```ini
[env:coordinator]
build_flags = -DZIGBEE_MODE_ZCZR -lesp_zb_api.zczr -lzboss_stack.zczr -lzboss_port.native
board_build.partitions = partitions_zczr.csv

[env:router]                 ; ZR juga memakai firmware ZCZR
build_flags = -DZIGBEE_MODE_ZCZR -lesp_zb_api.zczr -lzboss_stack.zczr -lzboss_port.native
board_build.partitions = partitions_zczr.csv

[env:enddevice]
build_flags = -DZIGBEE_MODE_ED -lesp_zb_api.ed -lzboss_stack.ed -lzboss_port.native
board_build.partitions = partitions_ed.csv
```.text,
  [Potongan `platformio.ini` --- tiga peran Modul 10],
  "lst:m10-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week10_zigbee_mesh/platformio.ini",
  [`platformio.ini` Modul 10 pada repositori],
  "lst:m10-ini",
)

Tabel partisi `partitions_zczr.csv` dan `partitions_ed.csv` pada modul ini
identik dengan milik Modul 08 (@lst:m08-part-zczr dan @lst:m08-part-ed).

#kode-berkas("week10_zigbee_mesh/src/coordinator/main.cpp",
  [`src/coordinator/main.cpp` --- coordinator sekaligus switch (EP 5)],
  "lst:m10-coordinator",
  pecah: true,
)

#kode-berkas("week10_zigbee_mesh/src/router/main.cpp",
  [`src/router/main.cpp` --- RouterLight (ZR, EP 10)],
  "lst:m10-router",
  pecah: true,
)

#kode-berkas("week10_zigbee_mesh/src/enddevice/main.cpp",
  [`src/enddevice/main.cpp` --- EndLight (ZED, EP 11)],
  "lst:m10-enddevice",
  pecah: true,
)

== Build dan Flash

Urutan penting: ZC, lalu ZR, lalu ZED.

#keluaran("for e in coordinator router enddevice; do pio run -d week10_zigbee_mesh -e $e -t erase; done
pio run -d week10_zigbee_mesh -e coordinator -t upload -t monitor
pio run -d week10_zigbee_mesh -e router      -t upload    # dalam 180 s
pio run -d week10_zigbee_mesh -e enddevice   -t upload    # dalam 180 s")

*Pre-flight checklist*

#checklist((
  [`pio device list` dijalankan, tiga port dicatat dan diisikan pada tiap env.],
  [*Hapus NVS ketiga board* (`-t erase`) sebelum flash pertama.],
  [Flash `coordinator` (ZCZR), `router` (ZCZR, mulai sebagai `ZIGBEE_ROUTER`),
   dan `enddevice` (ED) --- semuanya dalam window 180 detik.],
  [Serial Monitor 115200 baud pada ketiga board.],
  [Formasi penempatan (meja dulu, lalu garis) sudah direncanakan.],
))

== Percobaan

=== EXP-01 --- Join Bertingkat

Nyalakan coordinator, lalu router, lalu end device (semua dalam window
180 detik). Router join langsung ke ZC; end device memilih parent terbaik.

#diagram(```
 [ZC on] ──► open 180 s ──► [ZR join ke ZC] ──► [ZED join (parent = ZR/ZC)]
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Waktu join Router (detik)], [#isian],
    [Waktu join End Device (detik)], [#isian],
    [Total device ter-bind di ZC], [#isian],
    [Role yang dicetak Router dan ZED], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m10-exp01",
)

#checkpoint[
  Router mencetak `role=ROUTER` dan end device mencetak `role=END_DEVICE`. Jika
  router mencetak `END_DEVICE`, `build_flags`-nya salah --- perbaiki sebelum
  lanjut, karena tanpa ZR tidak ada hop kedua.
]

=== EXP-02 --- Kontrol Multi-Hop

Coordinator menunggu binding (ditambah 8 detik), mencetak daftar device, lalu
men-toggle semua device tiap 5 detik. Perintah ke EndLight diteruskan router
bila ZED memilih ZR sebagai parent.

#diagram(```
 [ZC] ──── ON/OFF (5 s) ───► [ZR: RouterLight ON/OFF]
                  │
                  └── relay ──► [ZED: EndLight ON/OFF]
```.text)

*Expected output --- Coordinator* (nilai channel, PAN ID, dan alamat dari uji
di board; di board Anda akan berbeda)

#keluaran("Network Zigbee terbentuk:
  Peran          : Coordinator (ZC)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu router & end device ter-binding...
Total device ter-bind: 2
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xBB28
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF")

*Expected output --- Router*

#keluaran("Router menunggu join ke network...
Router tergabung (role=ROUTER).
Info network:
  Peran          : Router (ZR)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x33F4 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
RouterLight ON
RouterLight OFF")

*Expected output --- End device*

#keluaran("End device menunggu join (bisa lewat router)...
End device tergabung (role=END_DEVICE).
Info network:
  Peran          : End Device (ED)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0xBB28 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 11 (light)
EndLight ON
EndLight OFF")

Info network ketiga board harus sama: *Channel, PAN ID, dan Extended PAN ID*
(di sini 21, `0x4D92`, dan IEEE address coordinator). Router juga mendapat
short address dari coordinator, sama seperti end device. Short address end
device (`0xBB28`) sama dengan yang tercetak di daftar bound coordinator; router
tercetak `0xFFFF` di sana. Padanan XBee: `Short address` = MY,
`IEEE address` = SH + SL, `Channel` = CH, `PAN ID` = OI, `Extended PAN ID` =
OP --- lihat tabel padanan XBee di Modul 08.

#buka-abstraksi[
  Cari di `src/router/main.cpp` baris kode yang *meneruskan* perintah ke end
  device. Baris itu tidak akan ditemukan: penerusan dikerjakan stack Zigbee,
  bukan aplikasi. Bandingkan dengan `src/nodeb/main.cpp` di Modul 06, tempat
  penerusan ditulis eksplisit. Tuliskan perbandingan itu --- ia adalah jawaban
  pertanyaan analisis nomor 5.
]

#checkpoint[
  Dua baris `-> 0x....` muncul tiap siklus dan kedua LED berubah. Jika EndLight
  tidak ikut berubah padahal ter-bind, dekatkan dulu semuanya (formasi meja)
  sebelum mencoba formasi garis.
]

=== EXP-03 --- Varian Topologi (inti modul)

+ *Formasi garis* (ZC, 5 m, ZR, 5 m, ZED): EndLight menerima perintah lewat
  router (2 hop). Amati apakah tetap ON/OFF sinkron.
+ *Formasi dekat*: letakkan ZED bersebelahan ZC; ZED mungkin memilih ZC sebagai
  parent (1 hop). Bandingkan latency nyala LED.
+ *Hilangkan router*: matikan ZR pada formasi garis; amati apakah ZED menjadi
  _orphan_, lalu apakah dapat re-join ke ZC bila jarak masih terjangkau.
+ Nyalakan ZR kembali dan catat waktu pemulihan.

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Latency EndLight, formasi dekat (1 hop)], [#isian],
    [Latency EndLight, formasi garis (2 hop)], [#isian],
    [Selisih latency 1 hop dan 2 hop], [#isian],
    [Perilaku ZED saat ZR dimatikan], [#isian],
    [Waktu pemulihan setelah ZR hidup lagi], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m10-exp03",
)

#checkpoint[
  Tersedia *dua angka latency* dari dua formasi berbeda, bukan satu. Tanpa
  keduanya, klaim "multi-hop berhasil" tidak bisa dibuktikan.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 3 × *ESP32-H2 DevKitM-1* (flash di-erase lebih dulu; ketiga
board berdekatan, jadi ZED kemungkinan besar memilih ZC sebagai parent, yaitu
1 hop), capture 80 detik.

#keluaran("# Coordinator (ESP32-H2, ZCZR)
[0.401] Menunggu router & end device ter-binding...
[8.415] Total device ter-bind: 2
[8.415]  - endpoint 10, short addr 0xFFFF
[8.415]  - endpoint 11, short addr 0x727D
[8.415] -> 0xFFFF ON
[8.415] -> 0x727D ON

# Router (ESP32-H2, ZR)            # End device (ESP32-H2, ZED)
[0.401] Router tergabung           [3.206] End device tergabung
        (role=ROUTER).                     (role=END_DEVICE).
[8.416] RouterLight ON             [8.415] EndLight ON
[13.425] RouterLight OFF           [13.423] EndLight OFF")

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu join router dan end device], [0,4 s dan 3,2 s],
    [Semua node ter-bind], [2 light (EP 10 dan EP 11) pada detik 8,4],
    [Perintah dikirim per light], [15],
    [Aksi terjadi di RouterLight dan EndLight], [15 / 15 (0 % loss)],
  ),
  [Hasil verifikasi hardware Modul 10],
  "tbl:m10-verifikasi",
)

Formasi meja (semua node kurang dari 1 m) *belum membuktikan* routing
multi-hop. Untuk itu jalankan EXP-03 formasi garis dan matikan jalur langsung
ZC ke ZED.


// Log serial lengkap dari week10_zigbee_mesh/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1, firmware versi terbaru: setelah network terbentuk (coordinator) atau setelah join, tiap board mencetak info network — channel, PAN ID, Extended PAN ID, short address, IEEE address, dan endpoint. Log direkam 60 detik dengan `monitor_serial.py` (ketiga port dalam satu komputer, satu sumbu waktu) lewat port UART CH343 di Windows.

  Ketiga board di-`erase` lalu di-flash; network terbentuk pada boot pertama coordinator. Log di bawah direkam setelah monitor me-reset ketiga board saat port dibuka, jadi coordinator *memulihkan* network dari NVS (bukan membentuk baru) dan node lain bergabung kembali ke network yang sama.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: (left, left, left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Peran], th[Endpoint], th[Short address (MY)], th[IEEE address (SH+SL)], th[Port serial (UART)]),
      [Coordinator], [Zigbee Coordinator (ZCZR) — switch], [5], [`0x0000`], [`74:4D:BD:FF:` \ `FE:61:E6:2C`], [`COM5`],
      [Router], [Zigbee Router (ZCZR) — light + relay], [10], [`0x33F4`], [`74:4D:BD:FF:` \ `FE:61:E8:C1`], [`COM11`],
      [End Device], [Zigbee End Device (ED) — light], [11], [`0xBB28`], [`74:4D:BD:FF:` \ `FE:61:F3:97`], [`COM13`],
    ),
    [Board dan port pada rekaman log serial Modul 10],
    "tbl:m10-log-1",
  )

  Network: channel *21*, PAN ID *`0x4D92`*, Extended PAN ID *`74:4D:BD:FF:FE:61:E6:2C`* — sama di ketiga board.

  *Coordinator --- COM5*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Network Zigbee terbentuk:
  Peran          : Coordinator (ZC)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu router & end device ter-binding...
Total device ter-bind: 2
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xBB28
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON
-> 0xFFFF OFF
-> 0xBB28 OFF
-> 0xFFFF ON
-> 0xBB28 ON", pecah: true)

  *Router --- COM11*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Router menunggu join ke network...
Router tergabung (role=ROUTER).
Info network:
  Peran          : Router (ZR)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x33F4 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON
RouterLight OFF
RouterLight ON", pecah: true)

  *End Device --- COM13*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
End device menunggu join (bisa lewat router)...
End device tergabung (role=END_DEVICE).
Info network:
  Peran          : End Device (ED)
  Channel        : 21
  PAN ID         : 0x4D92
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0xBB28 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 11 (light)
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON
EndLight OFF
EndLight ON", pecah: true)

  *Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)*

  #keluaran("[   0.441] Coordinator | Network Zigbee terbentuk:
[   0.441] Coordinator |   Peran          : Coordinator (ZC)
[   0.441] Coordinator |   Channel        : 21
[   0.441] Coordinator |   PAN ID         : 0x4D92
[   0.441] Coordinator |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.441] Coordinator |   Short address  : 0x0000
[   0.441] Coordinator |   IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
[   0.441] Coordinator |   Endpoint       : 5 (switch)
[   0.454] Router      | Router menunggu join ke network...
[   0.454] Router      | Router tergabung (role=ROUTER).
[   0.454] Router      | Info network:
[   0.454] Router      |   Peran          : Router (ZR)
[   0.454] Router      |   Channel        : 21
[   0.454] Router      |   PAN ID         : 0x4D92
[   0.454] Router      |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.595] EndDevice   | End device menunggu join (bisa lewat router)...
[   0.643] Coordinator | Menunggu router & end device ter-binding...
[   0.658] Router      |   Short address  : 0x33F4 (diberikan coordinator)
[   0.658] Router      |   IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
[   0.658] Router      |   Endpoint       : 10 (light)
[   3.311] EndDevice   | End device tergabung (role=END_DEVICE).
[   3.311] EndDevice   | Info network:
[   3.311] EndDevice   |   Peran          : End Device (ED)
[   3.311] EndDevice   |   Channel        : 21
[   3.311] EndDevice   |   PAN ID         : 0x4D92
[   3.311] EndDevice   |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   3.311] EndDevice   |   Short address  : 0xBB28 (diberikan coordinator)
[   3.516] EndDevice   |   IEEE address   : 74:4D:BD:FF:FE:61:F3:97
[   3.517] EndDevice   |   Endpoint       : 11 (light)
[   8.653] Coordinator | Total device ter-bind: 2
[   8.653] Coordinator |  - endpoint 10, short addr 0xFFFF
[   8.653] Coordinator |  - endpoint 11, short addr 0xBB28
[   8.653] Coordinator | -> 0xFFFF ON
[   8.653] Coordinator | -> 0xBB28 ON
[   8.653] EndDevice   | EndLight ON
[   8.677] Router      | RouterLight ON
[  13.630] Coordinator | -> 0xFFFF OFF
[  13.630] Coordinator | -> 0xBB28 OFF
[  13.662] EndDevice   | EndLight OFF
[  13.693] Router      | RouterLight OFF
[  18.648] Coordinator | -> 0xFFFF ON
[  18.649] Coordinator | -> 0xBB28 ON
[  18.665] EndDevice   | EndLight ON
[  18.698] Router      | RouterLight ON
[  23.644] Coordinator | -> 0xFFFF OFF
[  23.644] Coordinator | -> 0xBB28 OFF
[  23.669] EndDevice   | EndLight OFF
[  23.685] Router      | RouterLight OFF
[  28.664] Coordinator | -> 0xFFFF ON
[  28.664] Coordinator | -> 0xBB28 ON
[  28.664] EndDevice   | EndLight ON
[  28.696] Router      | RouterLight ON
[  33.656] Coordinator | -> 0xFFFF OFF
[  33.656] Coordinator | -> 0xBB28 OFF
[  33.672] EndDevice   | EndLight OFF
[  33.688] Router      | RouterLight OFF
[  38.669] Coordinator | -> 0xFFFF ON
[  38.669] Coordinator | -> 0xBB28 ON
[  38.669] EndDevice   | EndLight ON
[  38.709] Router      | RouterLight ON
[  43.661] Coordinator | -> 0xFFFF OFF
[  43.662] Coordinator | -> 0xBB28 OFF
[  43.676] EndDevice   | EndLight OFF
[  43.699] Router      | RouterLight OFF
[  48.670] Coordinator | -> 0xFFFF ON
[  48.671] Coordinator | -> 0xBB28 ON
[  48.697] EndDevice   | EndLight ON
[  48.705] Router      | RouterLight ON
[  53.666] Coordinator | -> 0xFFFF OFF
[  53.666] Coordinator | -> 0xBB28 OFF
[  53.682] EndDevice   | EndLight OFF
[  53.711] Router      | RouterLight OFF
[  58.675] Coordinator | -> 0xFFFF ON
[  58.675] Coordinator | -> 0xBB28 ON
[  58.692] EndDevice   | EndLight ON
[  58.708] Router      | RouterLight ON", pecah: true)

  *Ringkasan `monitor_serial.py`*

  #keluaran("Durasi: 60.4 s
  Coordinator COM5             43 baris, boot 1x, daftar bound  8.30 s sejak boot
              channel 21, PAN 0x4D92, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x0000
  Router      COM11            30 baris, boot 1x, tergabung  0.10 s sejak boot, role=ROUTER
              channel 21, PAN 0x4D92, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x33F4
  EndDevice   COM13            30 baris, boot 1x, tergabung  2.95 s sejak boot, role=END_DEVICE
              channel 21, PAN 0x4D92, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0xBB28
  Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Device ter-bind di coordinator (2):
  endpoint 10  short addr 0xFFFF  -> Router
  endpoint 11  short addr 0xBB28  -> EndDevice

Lampu     perintah  aksi   loss   perintah->aksi ms rata2 (min..max)  status akhir ZC/lampu
--------------------------------------------------------------------------------------------
Router          11    11    0.0%       39 (24..63)                     ON/ON
EndDevice       11    11    0.0%       15 (-0..31)                     ON/ON

Putaran perintah per menit: 12.0 (harapan 12: satu putaran tiap 5 s)
Aksi dipasangkan bila status sama dan jatuh -0.5..+2.0 s dari perintah; selisih memakai timestamp PC (kasar).", pecah: true)

  *Catatan*

  - *Info network cocok di ketiga board*: channel 21, PAN ID `0x4D92`, dan Extended PAN ID sama. Router melaporkan peran `Router (ZR)` dan, seperti end device, mendapat short address dari coordinator (`0x33F4`).
  - Padanan XBee: `Short address` = MY, `IEEE address` = SH+SL, `Channel` = CH, `PAN ID` = OI, `Extended PAN ID` = OP — lihat tabel padanan XBee di Modul 08.
  - *Extended PAN ID = IEEE address coordinator* (`74:4D:BD:FF:FE:61:E6:2C`), karena Extended PAN ID tidak diatur di kode.
  - Daftar bound coordinator mencetak `0xFFFF` untuk router (short address aslinya `0x33F4`) dan `0xBB28` untuk end device — sama dengan short address yang dicetak end device sendiri.
  - Kedua lampu menerima *11/11 perintah (0 % loss)*; selisih perintah → aksi sekitar 24–63 ms di router dan 0–31 ms di end device.
  - Board berdekatan di meja, jadi end device kemungkinan besar terhubung langsung ke coordinator; log ini *belum* membuktikan penerusan lewat router (itu tugas formasi garis).
  - Firmware coordinator tidak menunggu `Zigbee.connected()`: pada reboot dengan `setRebootOpenNetwork()` aktif (seperti pada log ini), library Arduino core 3.3.x tidak pernah men-set flag itu untuk coordinator.
  - Selisih perintah → aksi memakai timestamp PC, jadi kasar (resolusi USB-serial).
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

*Tabel jarak ZC ke ZED* (dengan ZR di tengah).

#tbl(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Jarak total], th[RSSI], th[Latency], th[Success]),
    [1 m], [#isian], [], [… / 10],
    [3 m], [#isian], [], [… / 10],
    [5 m], [#isian], [], [… / 10],
    [10 m], [#isian], [], [… / 10],
    [15 m], [#isian], [], [… / 10],
  ),
  [Lembar pengukuran jarak Modul 10],
  "tbl:m10-ukur",
)

*Tabel per-hop atau per-node* (20 perintah).

#tbl(
  table(
    columns: (1.4fr, 1fr, 1.1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node atau Hop], th[RSSI], th[Paket diterima], th[Loss (%)]),
    [Router (EP 10, hop 1)], [#isian], [… / 20], [],
    [EndLight (EP 11, hop 2)], [#isian], [… / 20], [],
  ),
  [Lembar pengukuran per-hop Modul 10],
  "tbl:m10-perhop",
)

*Tabel pembanding hop --- wajib.* Isi dari data sendiri.

#tbl(
  table(
    columns: (1.3fr, auto, 1fr, 1.1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Cara mencapai node jauh], th[Modul], th[Latency terukur],
      th[Siapa yang menentukan jalur],
    ),
    [Relay manual (BLE)], [M06], [#isian], [kode aplikasi],
    [Routing otomatis (Zigbee)], [M10], [#isian], [stack Zigbee],
  ),
  [Tabel pembanding relay manual dan routing otomatis],
  "tbl:m10-banding",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Berapa lama waktu join router dan end device? Apakah urutan penyalaan
  memengaruhi keberhasilan?
+ Berdasarkan formasi dekat dibanding garis, kapan end device memilih router
  sebagai parent? Bagaimana hal itu dibuktikan dari log?
+ Bandingkan latency nyala EndLight pada 1 hop dan 2 hop; berapa selisihnya dan
  apakah sebanding dengan tambahan jangkauan?
+ Apa yang terjadi pada EndLight ketika router dimatikan? Sebutkan istilah
  status node tersebut dan berapa lama pemulihannya.
+ Bandingkan dengan relay manual M06: apa yang *diperoleh* dari routing
  otomatis, dan apa yang *hilang* (kendali, keterlihatan, ukuran firmware)?

== Concept Check

+ Apa perbedaan utama mode build ZCZR dan ED (lihat `build_flags` di
  `platformio.ini`)?
+ Mengapa router memakai `partitions_zczr.csv` sedangkan end device
  `partitions_ed.csv`?
+ Bagaimana mesh Zigbee menemukan jalur baru jika salah satu router mati?
+ Jelaskan hubungan endpoint 5, 10, dan 11 dengan binding pada percobaan ini.
+ Apa konsekuensi daya dari node yang berperan sebagai router dibanding end
  device, dan apa artinya untuk node bertenaga baterai?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Memperpanjang rantai dan mengukur loss per hop])[
  / CH-1 --- Rantai dua router: Tambahkan *router2* (salin `src/router`, tetap
    `ZigbeeLight(10)` tetapi ubah model string) dan susun rantai ZC, ZR1, ZR2,
    ZED. Amati berapa hop maksimum yang masih berfungsi dan berapa tambahan
    latency per hop.

  / CH-2 --- Packet loss per hop: Catat TX di ZC dan RX di tiap lampu selama
    3 menit. Contoh: TX = 36, RX EndLight = 33, sehingga
    loss = (36 − 33)/36 × 100 % = 8,33 %. Sajikan terpisah untuk hop 1 dan
    hop 2.
]

#tujuan-prak(3, [Melacak parent dan menguji self-healing])[
  / CH-3 --- Lacak parent: Amati alamat parent end device dengan memindahkan
    ZED bertahap, lalu simpulkan pada jarak berapa jalur mulai di-router.
    Sajikan sebagai tabel jarak terhadap parent.

  / CH-4 --- Uji self-healing: Pada formasi garis, matikan ZR lalu ukur berapa
    lama ZED butuh untuk kembali (baik lewat ZC langsung maupun setelah ZR
    hidup lagi). Bandingkan dengan perilaku relay manual M06 yang tidak pulih
    sendiri.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (mesh Zigbee, ZR sebagai relayer, parent selection,
  orphan).
+ Konfigurasi --- env `coordinator`, `router`, `enddevice`, endpoint 5, 10, 11,
  interval 5 detik, dan window 180 s.
+ Hasil eksperimen --- log ketiga node, skema formasi (meja dan garis), serta
  checkpoint.
+ Data pengukuran --- tabel jarak, tabel per-hop, dan tabel pembanding hop M06
  dengan M10.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-3.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
