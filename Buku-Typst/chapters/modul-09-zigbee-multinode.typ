// ============================================================================
// Modul 09 — Zigbee Multi-Node & Binding Table
// Sumber: week09_zigbee_multinode/README.md; listing kode dibaca langsung dari
//         assets/code/week09_zigbee_multinode/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 09 — Zigbee Multi-Node dan Binding Table", l: "bab:modul-09")

#identitas-modul(
  "Modul 09",
  [Scale the Network --- Zigbee Multi-Node dan Binding Table],
  [ESP32-H2 · Zigbee · 1 ZC + 2 ZED · level Intermediate · 3 × 50 menit ·
   folder kode `week09_zigbee_multinode`],
)

#pengantar([Gambaran Umum])[
Modul 09 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya menskalakan satu coordinator ke banyak end device tanpa satu perintah
pun hilang. Percobaan berjalan sebagai jaringan Zigbee multi-node dengan satu
coordinator dan dua end device, diamati melalui tiga terminal Serial Monitor
pada 115200 baud dengan LED RGB bawaan sebagai penanda visual.
]

== Pendahuluan

M08 mengikat *satu* lampu ke satu switch. Di sini `allowMultipleBinding(true)`
dinyalakan, dan coordinator harus menyimpan *daftar* tujuan --- inilah binding
table. Masalah yang muncul identik dengan M05 di dunia BLE (satu pusat, banyak
sumber), tetapi jawabannya berbeda: BLE memakai objek koneksi per node, Zigbee
memakai `endpoint + short address`. Perbandingan dua cara ini adalah bahan
analisis modul ini.

Prasyaratnya adalah M08: join, binding, endpoint, dan penghapusan NVS sebelum
flash. Yang dibangun di sini adalah pemakaian `allowMultipleBinding(true)`,
iterasi binding table melalui `getBoundDevices()`, pengalamatan per endpoint,
perhitungan loss per node, serta pengamatan perilaku sistem saat satu node
hilang. Semuanya dipakai lagi pada M10 ketika jenis anggota jaringan bertambah
dengan hadirnya router, M12 pada komunikasi many-to-many di Thread, dan M16
ketika skalabilitas menjadi kriteria pemilihan protokol.

*Peta modul blok Zigbee*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [07], [802.15.4 telanjang],
    [08], [Jaringan Zigbee terbentuk: join, binding, cluster ON/OFF],
    [*09 (ini)*], [*Satu coordinator melayani banyak end device (binding table)*],
    [10], [Router menambah hop --- routing multi-hop otomatis],
  ),
  [Peta modul blok Zigbee],
  "tbl:m09-peta",
)

*Kontrak data lab ini.* Identitas node di Zigbee adalah pasangan *`endpoint`
ditambah `short address`* --- bukan prefiks di dalam payload seperti M05 (`A:`,
`B:`). Catat perbedaannya: identitas di sini dikelola *jaringan*, bukan
aplikasi. Konsekuensinya muncul langsung di modul ini (lihat catatan `0xFFFF`
di bagian Percobaan).

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Menskalakan Zigbee ke banyak end device])[
  + Membangun jaringan Zigbee satu coordinator dengan dua end device pada satu
    window join, dan menampilkan isi binding table beserta endpoint tiap node.
  + Mengirim perintah ke node tertentu berdasarkan `endpoint + short address`
    dan membuktikan node yang dituju bereaksi.
  + Menghitung packet loss *per node* (EP 10 dibanding EP 11) pada jarak yang
    sama dan pada jarak berbeda.
  + Menjelaskan perilaku coordinator ketika satu end device menghilang,
    berdasarkan log --- termasuk apakah perintah tetap dikirim ke node yang
    sudah mati.
]

*Kriteria keberhasilan*

#checklist((
  [Coordinator mencetak `Total 2 device.` pada daftar binding.],
  [Kedua lampu merespons pada siklus yang sama.],
  [Loss per node terukur terpisah (EP 10 dibanding EP 11).],
  [Skenario satu node dimatikan diuji dan perilakunya tercatat.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (tabel
routing Zigbee, addressing mode APS, group addressing) berada di buku teori
terpisah. Istilah kerja dirangkum pada @tbl:m09-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Coordinator (ZC)], [Membentuk jaringan, mengelola PAN, mengizinkan join.],
    [End Device (ZED)], [Node akhir (child) rendah daya, tidak meneruskan trafik.],
    [Join], [Node bergabung ke jaringan; dibuka 180 detik setelah reboot (`setRebootOpenNetwork(180)`).],
    [Binding table], [Daftar tujuan yang dipegang switch; dibaca lewat `getBoundDevices()`.],
    [Endpoint], [Titik komunikasi aplikasi; Switch EP 5, Light1 EP 10, Light2 EP 11.],
    [Cluster On/Off], [Perintah standar; dipanggil per tujuan lewat `lightOn(ep, addr)`.],
    [Short address], [Alamat 16-bit node Zigbee, dicetak coordinator sebagai `0x%04X`.],
  ),
  [Istilah kerja Modul 09],
  "tbl:m09-istilah",
)

*Mengapa endpoint kedua lampu harus berbeda?* Karena binding table
mengidentifikasi tujuan dari pasangan `endpoint + address`. Bila dua lampu
memakai endpoint yang sama, entri binding menjadi ambigu dan perintah bisa
menyasar. Endpoint adalah "nomor kamar" --- dua kamar tidak boleh bernomor sama
di satu daftar tujuan.

*Sekuens protokol yang diamati*

#diagram(```
 Coordinator                        Light1 / Light2
     │  ──── open network (180 s) ──►      │
     │  ◄────────── join request ───────── │
     │  ──── assign short address ───────► │
     │  ◄────────── binding request ────── │
     │  ── lightOn/lightOff (tiap 5 s) ──► │  (dikirim per entri binding)
```.text)

== Topologi

#diagram(```
                       BOARD #1
                 +----------------+
                 |    ESP32-H2    |
                 |  Coordinator   |
                 |  (Switch, EP 5)|
                 +--------+-------+
                          |  binding
              +-----------+-----------+
              |                       |
        BOARD #2                 BOARD #3
     +--------v-------+     +---------v------+
     |    ESP32-H2    |     |    ESP32-H2    |
     |   Light #1     |     |   Light #2     |
     | ZED, EP 10     |     | ZED, EP 11     |
     +----------------+     +----------------+
       env: light1            env: light2
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Endpoint]),
    [Coordinator], [ESP32-H2 DevKitM-1], [`coordinator`], [ZC dan switch (ZCZR)], [EP 5],
    [Light \#1], [ESP32-H2 DevKitM-1], [`light1`], [ZED dan light], [EP 10],
    [Light \#2], [ESP32-H2 DevKitM-1], [`light2`], [ZED dan light], [EP 11],
  ),
  [Peran tiap node Modul 09],
  "tbl:m09-topologi",
)

Ketiganya *ESP32-H2 DevKitM-1* dengan radio 802.15.4; peran ditentukan oleh
`build_flags` dan tabel partisi, bukan oleh jenis board.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan library
`Zigbee` bawaan.

#tbl(
  table(
    columns: (auto, 1fr, 1.6fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1, LED RGB bawaan], [3],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [3],
    [3], [PC/Laptop], [PlatformIO Core/IDE, idealnya 3 port USB bebas], [1],
    [4], [Power bank atau catu daya USB], [untuk node yang dipindah saat uji jarak], [2],
    [5], [Tabel partisi], [`partitions_zczr.csv` (ZC), `partitions_ed.csv` (ED) --- sudah ada di folder modul], [---],
  ),
  [Alat dan bahan Modul 09],
  "tbl:m09-alat",
)

== Kode Program

#sumber-kode("week09_zigbee_multinode",
  ("platformio.ini", "partitions_zczr.csv", "partitions_ed.csv",
   "src/coordinator/main.cpp", "src/light1/main.cpp", "src/light2/main.cpp"))

*Tiga environment* (@lst:m09-ini-readme).

#kode(```ini
[env:coordinator]
build_src_filter = +<coordinator/*.cpp>
build_flags = -DZIGBEE_MODE_ZCZR -lesp_zb_api.zczr -lzboss_stack.zczr -lzboss_port.native
board_build.partitions = partitions_zczr.csv
upload_port = /dev/ttyACM0

[env:light1]
build_src_filter = +<light1/*.cpp>
build_flags = -DZIGBEE_MODE_ED -lesp_zb_api.ed -lzboss_stack.ed -lzboss_port.native
board_build.partitions = partitions_ed.csv
upload_port = /dev/ttyACM2

[env:light2]
build_src_filter = +<light2/*.cpp>
build_flags = -DZIGBEE_MODE_ED -lesp_zb_api.ed -lzboss_stack.ed -lzboss_port.native
board_build.partitions = partitions_ed.csv
upload_port = /dev/ttyACM4
```.text,
  [Potongan `platformio.ini` --- tiga environment Modul 09],
  "lst:m09-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week09_zigbee_multinode/platformio.ini",
  [`platformio.ini` Modul 09 pada repositori],
  "lst:m09-ini",
)

Tabel partisi `partitions_zczr.csv` dan `partitions_ed.csv` pada modul ini
identik dengan milik Modul 08 (@lst:m08-part-zczr dan @lst:m08-part-ed),
sehingga tidak diulang di sini.

#kode-berkas("week09_zigbee_multinode/src/coordinator/main.cpp",
  [`src/coordinator/main.cpp` --- coordinator dengan binding table],
  "lst:m09-coordinator",
  pecah: true,
)

#kode-berkas("week09_zigbee_multinode/src/light1/main.cpp",
  [`src/light1/main.cpp` --- Light \#1 pada endpoint 10],
  "lst:m09-light1",
  pecah: true,
)

#kode-berkas("week09_zigbee_multinode/src/light2/main.cpp",
  [`src/light2/main.cpp` --- Light \#2 pada endpoint 11],
  "lst:m09-light2",
  pecah: true,
)

== Build dan Flash

#keluaran("for e in coordinator light1 light2; do pio run -d week09_zigbee_multinode -e $e -t erase; done
pio run -d week09_zigbee_multinode -e coordinator -t upload -t monitor
pio run -d week09_zigbee_multinode -e light1 -t upload      # dalam 180 s
pio run -d week09_zigbee_multinode -e light2 -t upload      # dalam 180 s")

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
  [*Hapus NVS ketiga board* (`-t erase`) sebelum flash pertama.],
  [Flash `coordinator` (ZCZR, `partitions_zczr.csv`).],
  [Flash `light1` dan `light2` (ED, `partitions_ed.csv`) *dalam window
   180 detik*.],
  [Serial Monitor 115200 baud pada tiap board.],
  [Tabel pencatat jarak, RSSI, dan latency siap.],
))

== Percobaan

=== EXP-01 --- Pembentukan Jaringan dan Join Ganda

Nyalakan coordinator lebih dulu. Jaringan terbuka 180 detik setelah reboot;
dalam window ini nyalakan `light1` dan `light2` agar join dan binding.

#diagram(```
 [ZC reboot] ──► open network 180 s ──► [ZED1 join] [ZED2 join] ──► bound
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Waktu join Light1 (detik)], [#isian],
    [Waktu join Light2 (detik)], [#isian],
    [Status LED saat join], [#isian],
    [Apakah keduanya masuk dalam satu window?], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m09-exp01",
)

#checkpoint[
  Kedua light mencetak `tergabung ke network!`. Jika hanya satu, window join
  sudah habis untuk yang kedua --- reboot coordinator (window terbuka lagi)
  lalu ulangi. Jangan lanjut dengan satu node saja.
]

=== EXP-02 --- Binding Table dan Kontrol Otomatis

Setelah minimal satu light ter-bind, coordinator menunggu 5 detik tambahan
(agar light kedua sempat join dan bind), mencetak daftar device ter-bind, lalu
men-toggle semua light setiap 5 detik.

#diagram(```
 [ZC] getBoundDevices() ──► endpoint + short addr
 [ZC] lightOn(ep, addr) / lightOff(ep, addr)  tiap 5 s
```.text)

*Expected output --- Coordinator* (nilai channel, PAN ID, dan alamat dari uji
di board; di board Anda akan berbeda)

#keluaran("Network Zigbee terbentuk:
  Peran          : Coordinator (ZC)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu light ter-binding (join dalam 180 detik)...
Daftar device ter-bind:
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xFFFF
Total 2 device.
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF")

#catatan[
  Satu atau kedua `short addr` di daftar bound sering tercetak `0xFFFF` (pada
  uji ini keduanya), padahal short address asli kedua light terlihat di blok
  info network masing-masing. Itu *bukan* kegagalan
  binding --- lihat catatan pada bagian Verifikasi Hardware di bawah.
]

*Expected output --- Light1*

#keluaran("Light1 menunggu join ke network...
Light1 tergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x82C3 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
Light1 ON
Light1 OFF")

*Expected output --- Light2*

#keluaran("Light2 menunggu join ke network...
Light2 tergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x127F (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 11 (light)
Light2 ON
Light2 OFF")

Info network ketiga board harus sama: *Channel, PAN ID, dan Extended PAN ID*
(di sini 26, `0x1890`, dan IEEE address coordinator). Short address tiap
light berbeda dan *dibagikan coordinator* saat join. Padanan XBee:
`Short address` = MY, `IEEE address` = SH + SL, `Channel` = CH, `PAN ID` = OI,
`Extended PAN ID` = OP --- lihat tabel padanan XBee di Modul 08.

#buka-abstraksi[
  `getBoundDevices()` mengembalikan `std::list` berisi `zb_device_params_t`.
  Cetak *seluruh* field struct itu (bukan hanya endpoint dan short address) dan
  cocokkan dengan `IEEE address` (MAC 64-bit) yang dicetak tiap light pada
  blok `Info network`. Jawab: entri mana yang benar-benar unik dan stabil ---
  short address atau alamat IEEE?
]

#checkpoint[
  Baris `Total 2 device.` muncul, dan setelah itu ada *dua* baris
  `-> Light 0x....` untuk tiap siklus ON dan tiap siklus OFF. Jika hanya satu
  baris per siklus, binding kedua gagal.
]

=== EXP-03 --- Jarak dan Kehilangan Node

+ Letakkan Light2 pada jarak bertambah (1, 3, 5, lalu 10 m) dari coordinator;
  amati apakah perintah tetap diterima sementara Light1 tetap dekat.
+ Matikan (cabut daya) Light1 saat sistem berjalan; amati apakah coordinator
  *masih mencetak* `-> Light 0xXXXX ON` untuk node yang sudah mati.
+ Nyalakan kembali Light1 setelah window 180 detik berlalu; catat apakah dapat
  kembali sendiri dan apa yang perlu dilakukan.

*Data capture*

#tbl(
  table(
    columns: (1.6fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Success Light2 pada 10 m], [#isian],
    [Apakah loss Light1 terpengaruh oleh Light2 yang jauh?], [#isian],
    [Perilaku coordinator saat Light1 mati], [#isian],
    [Light1 kembali otomatis? (ya/tidak) beserta alasan], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m09-exp03",
)

#checkpoint[
  Praktikan dapat menjelaskan mengapa coordinator tetap mengirim perintah ke
  node yang sudah mati (petunjuk: binding table adalah daftar statis, bukan
  daftar node yang sedang hidup). Ini temuan penting untuk desain sistem nyata.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 3 × *ESP32-H2 DevKitM-1* (flash di-erase lebih dulu), capture
70 detik.

#keluaran("# Coordinator (ESP32-H2, ZCZR)
[0.401] Menunggu light ter-binding (join dalam 180 detik)...
[5.409] Daftar device ter-bind:
[5.409]  - endpoint 10, short addr 0xFFFF
[5.409]  - endpoint 11, short addr 0x1DA3
[5.409] Total 2 device.
[5.409] -> Light 0xFFFF ON
[5.409] -> Light 0x1DA3 ON

# Light1 (ESP32-H2, ED)            # Light2 (ESP32-H2, ED)
[0.602] Light1 tergabung ...       [3.208] Light2 tergabung ...
[5.411] Light1 ON                  [5.411] Light2 ON
[10.421] Light1 OFF                [10.419] Light2 OFF")

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Device ter-bind terdeteksi], [2 (EP 10 dan EP 11)],
    [Perintah dikirim per light], [14],
    [Aksi terjadi di Light1 dan Light2], [14 / 14 (0 % loss)],
    [Waktu join Light1 dan Light2], [0,6 s dan 3,2 s],
  ),
  [Hasil verifikasi hardware Modul 09],
  "tbl:m09-verifikasi",
)

#catatan[
  *Short addr `0xFFFF` itu normal.* Entri binding yang dibuat lewat alamat IEEE
  (bukan alamat pendek) disimpan library dengan `short_addr = 0xFFFF`.
  `lightOn(ep, 0xFFFF)` tetap sampai ke node yang benar --- buktinya Light1
  tetap menyala. Yang perlu dicatat pada laporan adalah jumlah device ter-bind
  dan keberhasilan aksinya, bukan nilai alamatnya.
]


// Log serial lengkap dari week09_zigbee_multinode/logserial.md. Hanya dicetak pada
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
      [Light1], [Zigbee End Device (ED) — light], [10], [`0x82C3`], [`74:4D:BD:FF:` \ `FE:61:E8:C1`], [`COM11`],
      [Light2], [Zigbee End Device (ED) — light], [11], [`0x127F`], [`74:4D:BD:FF:` \ `FE:61:F3:97`], [`COM13`],
    ),
    [Board dan port pada rekaman log serial Modul 09],
    "tbl:m09-log-1",
  )

  Network: channel *26*, PAN ID *`0x1890`*, Extended PAN ID *`74:4D:BD:FF:FE:61:E6:2C`* — sama di ketiga board.

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
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu light ter-binding (join dalam 180 detik)...
Daftar device ter-bind:
 - endpoint 10, short addr 0xFFFF
 - endpoint 11, short addr 0xFFFF
Total 2 device.
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON
-> Light 0xFFFF OFF
-> Light 0xFFFF OFF
-> Light 0xFFFF ON
-> Light 0xFFFF ON", pecah: true)

  *Light1 --- COM11*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Light1 menunggu join ke network...
Light1 tergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x82C3 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON
Light1 OFF
Light1 ON", pecah: true)

  *Light2 --- COM13*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Light2 menunggu join ke network...
Light2 tergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 26
  PAN ID         : 0x1890
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x127F (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 11 (light)
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON
Light2 OFF
Light2 ON", pecah: true)

  *Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)*

  #keluaran("[   0.450] Coordinator | Network Zigbee terbentuk:
[   0.450] Coordinator |   Peran          : Coordinator (ZC)
[   0.450] Coordinator |   Channel        : 26
[   0.450] Coordinator |   PAN ID         : 0x1890
[   0.450] Coordinator |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.450] Coordinator |   Short address  : 0x0000
[   0.450] Coordinator |   IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
[   0.450] Coordinator |   Endpoint       : 5 (switch)
[   0.658] Coordinator | Menunggu light ter-binding (join dalam 180 detik)...
[   0.686] Light1      | Light1 menunggu join ke network...
[   0.686] Light1      | Light1 tergabung ke network!
[   0.686] Light1      | Info network:
[   0.686] Light1      |   Peran          : End Device (ED)
[   0.686] Light1      |   Channel        : 26
[   0.686] Light1      |   PAN ID         : 0x1890
[   0.686] Light1      |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.895] Light1      |   Short address  : 0x82C3 (diberikan coordinator)
[   0.895] Light1      |   IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
[   0.896] Light1      |   Endpoint       : 10 (light)
[   5.668] Coordinator | Daftar device ter-bind:
[   5.669] Coordinator |  - endpoint 10, short addr 0xFFFF
[   5.669] Coordinator |  - endpoint 11, short addr 0xFFFF
[   5.669] Coordinator | Total 2 device.
[   5.669] Coordinator | -> Light 0xFFFF ON
[   5.669] Coordinator | -> Light 0xFFFF ON
[   5.700] Light1      | Light1 ON
[   6.443] Light2      | Light2 menunggu join ke network...
[   6.443] Light2      | Light2 tergabung ke network!
[   6.443] Light2      | Info network:
[   6.443] Light2      |   Peran          : End Device (ED)
[   6.443] Light2      |   Channel        : 26
[   6.443] Light2      |   PAN ID         : 0x1890
[   6.443] Light2      |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   6.650] Light2      |   Short address  : 0x127F (diberikan coordinator)
[   6.650] Light2      |   IEEE address   : 74:4D:BD:FF:FE:61:F3:97
[   6.650] Light2      |   Endpoint       : 11 (light)
[  10.656] Coordinator | -> Light 0xFFFF OFF
[  10.656] Coordinator | -> Light 0xFFFF OFF
[  10.700] Light1      | Light1 OFF
[  15.658] Coordinator | -> Light 0xFFFF ON
[  15.658] Coordinator | -> Light 0xFFFF ON
[  15.690] Light1      | Light1 ON
[  15.690] Light2      | Light2 ON
[  20.668] Coordinator | -> Light 0xFFFF OFF
[  20.668] Coordinator | -> Light 0xFFFF OFF
[  20.703] Light1      | Light1 OFF
[  20.703] Light2      | Light2 OFF
[  25.672] Coordinator | -> Light 0xFFFF ON
[  25.672] Coordinator | -> Light 0xFFFF ON
[  25.709] Light1      | Light1 ON
[  25.710] Light2      | Light2 ON
[  30.668] Coordinator | -> Light 0xFFFF OFF
[  30.669] Coordinator | -> Light 0xFFFF OFF
[  30.709] Light1      | Light1 OFF
[  30.709] Light2      | Light2 OFF
[  35.679] Coordinator | -> Light 0xFFFF ON
[  35.679] Coordinator | -> Light 0xFFFF ON
[  35.711] Light1      | Light1 ON
[  35.711] Light2      | Light2 ON
[  40.677] Coordinator | -> Light 0xFFFF OFF
[  40.677] Coordinator | -> Light 0xFFFF OFF
[  40.718] Light2      | Light2 OFF
[  40.718] Light1      | Light1 OFF
[  45.684] Coordinator | -> Light 0xFFFF ON
[  45.685] Coordinator | -> Light 0xFFFF ON
[  45.716] Light1      | Light1 ON
[  45.732] Light2      | Light2 ON
[  50.688] Coordinator | -> Light 0xFFFF OFF
[  50.689] Coordinator | -> Light 0xFFFF OFF
[  50.720] Light1      | Light1 OFF
[  50.720] Light2      | Light2 OFF
[  55.689] Coordinator | -> Light 0xFFFF ON
[  55.690] Coordinator | -> Light 0xFFFF ON
[  55.721] Light1      | Light1 ON
[  55.721] Light2      | Light2 ON", pecah: true)

  *Ringkasan `monitor_serial.py`*

  #keluaran("Durasi: 60.3 s
  Coordinator COM5             44 baris, boot 1x, daftar bound  5.30 s sejak boot
              channel 26, PAN 0x1890, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x0000
  Light1      COM11            30 baris, boot 1x, tergabung  0.31 s sejak boot
              channel 26, PAN 0x1890, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x82C3
  Light2      COM13            28 baris, boot 1x, tergabung  6.07 s sejak boot
              channel 26, PAN 0x1890, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x127F
  Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Device ter-bind di coordinator (2):
  endpoint 10  short addr 0xFFFF  -> Light1
  endpoint 11  short addr 0xFFFF  -> Light2

Light     perintah  aksi   loss   perintah->aksi ms rata2 (min..max)  status akhir ZC/light
--------------------------------------------------------------------------------------------
Light1          11    11    0.0%       35 (32..44)                     ON/ON
Light2          11     9   18.2%       37 (31..47)                     ON/ON
          tanpa aksi: ON @ 5.7 s, OFF @ 10.7 s

Putaran perintah per menit: 12.0 (harapan 12: satu putaran tiap 5 s)
Aksi dipasangkan bila status sama dan jatuh -0.5..+2.0 s dari perintah; selisih memakai timestamp PC (kasar).", pecah: true)

  *Catatan*

  - *Info network cocok di ketiga board*: channel 26, PAN ID `0x1890`, dan Extended PAN ID sama. Short address tiap light (`0x82C3`, `0x127F`) dibagikan coordinator saat join.
  - Padanan XBee: `Short address` = MY, `IEEE address` = SH+SL, `Channel` = CH, `PAN ID` = OI, `Extended PAN ID` = OP — lihat tabel padanan XBee di Modul 08.
  - *Extended PAN ID = IEEE address coordinator* (`74:4D:BD:FF:FE:61:E6:2C`), karena Extended PAN ID tidak diatur di kode.
  - *Daftar bound mencetak `0xFFFF` untuk kedua light*, padahal short address aslinya `0x82C3` dan `0x127F` (lihat blok info network). Perintah tetap sampai ke keduanya, jadi `0xFFFF` di sini bukan tanda binding gagal.
  - `allowMultipleBinding(true)`: kedua light ada di binding table dan menerima perintah yang sama tiap 5 s.
  - *Light1* bergabung 0,31 s setelah boot → *11/11 perintah sampai* (0 % loss). *Light2* baru bergabung 6,07 s setelah boot, sehingga dua perintah pertama (5,7 s dan 10,7 s) tidak sampai; sejak 15,7 s semua perintah sampai (9/11). Selisih perintah → aksi sekitar 31–47 ms.
  - Firmware coordinator tidak menunggu `Zigbee.connected()`: pada reboot dengan `setRebootOpenNetwork()` aktif (seperti pada log ini), library Arduino core 3.3.x tidak pernah men-set flag itu untuk coordinator.
  - Selisih perintah → aksi memakai timestamp PC, jadi kasar (resolusi USB-serial).
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

*Tabel jarak* (geser Light2, Light1 tetap di 1 m; amati LED dan Serial
Monitor).

#tbl(
  table(
    columns: (auto, auto, auto, 1.1fr, 1.1fr),
    align: (left, left, left, left, left),
    inset: (x: 0.45em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak Light2], th[RSSI], th[Latency], th[Success Light2],
      th[Success Light1],
    ),
    [1 m], [#isian], [], [… / 10], [… / 10],
    [3 m], [#isian], [], [… / 10], [… / 10],
    [5 m], [#isian], [], [… / 10], [… / 10],
    [10 m], [#isian], [], [… / 10], [… / 10],
    [15 m], [#isian], [], [… / 10], [… / 10],
  ),
  [Lembar pengukuran jarak Modul 09],
  "tbl:m09-ukur",
)

*Tabel per-node* (jarak tetap 3 m, amati 20 perintah).

#tbl(
  table(
    columns: (1.2fr, 1fr, 1.1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[RSSI], th[Paket diterima], th[Loss (%)]),
    [Light1 (EP 10)], [#isian], [… / 20], [],
    [Light2 (EP 11)], [#isian], [… / 20], [],
  ),
  [Lembar pengukuran per-node Modul 09],
  "tbl:m09-pernode",
)

*Bandingkan dengan M05.* Isi @tbl:m09-banding memakai data BLE multi-node.

#tbl(
  table(
    columns: (1.4fr, 1fr, 1fr),
    align: (left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Aspek], th[BLE bintang (M05)], th[Zigbee multi-node (M09)]),
    [Cara pusat membedakan node], [#isian], [],
    [Loss node dekat saat node lain jauh], [#isian], [],
    [Perilaku saat satu node mati], [#isian], [],
    [Batas jumlah node (perkiraan beserta alasan)], [#isian], [],
  ),
  [Tabel pembanding BLE bintang dan Zigbee multi-node],
  "tbl:m09-banding",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Berapa waktu rata-rata proses join dari menyala hingga pesan
  `tergabung ke network`?
+ Apakah kedua light menerima perintah ON/OFF pada siklus yang sama? Buktikan
  dari urutan baris log coordinator.
+ Bagaimana pengaruh jarak terhadap success rate perintah ON/OFF, dan apakah
  node yang dekat ikut terdampak?
+ Apa yang terjadi di coordinator ketika salah satu light dimatikan? Masihkah
  perintah dikirim ke node itu, dan apa implikasinya untuk sistem nyata?
+ Mengapa endpoint light1 dan light2 harus berbeda (10 dibanding 11)? Apa yang
  akan terjadi jika sama?

== Concept Check

+ Apa fungsi `allowMultipleBinding(true)` pada switch coordinator?
+ Apa yang dimaksud window join 180 detik pada `setRebootOpenNetwork(180)`, dan
  mengapa tidak dibuka selamanya?
+ Jelaskan perbedaan peran ZC dan ZED dalam topologi multi-node ini.
+ Bagaimana coordinator mengidentifikasi setiap light secara unik (endpoint
  ditambah short address)?
+ Apa keuntungan multi-binding dibanding broadcast ke semua node?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Menambah node dan menghitung loss per endpoint])[
  / CH-1 --- Node ketiga: Tambahkan *light3* (endpoint 12): salin `src/light2`,
    ubah `ZigbeeLight(11)` menjadi `ZigbeeLight(12)` dan teks `Light2` menjadi
    `Light3`, lalu tambahkan env `light3` di `platformio.ini`. Amati
    `Total 3 device.` pada coordinator dan periksa apakah interval siklus
    bergeser.

  / CH-2 --- Loss per node otomatis: Catat jumlah perintah TX
    (`-> Light 0xXXXX ON/OFF`) dibanding jumlah `LightX ON/OFF` yang diterima
    tiap node selama 2 menit. Contoh: TX = 24, RX = 22, sehingga
    loss = (24 − 22)/24 × 100 % = 8,33 %. Sajikan terpisah per endpoint.
]

#tujuan-prak(3, [Kontrol selektif dan deteksi node hilang])[
  / CH-3 --- Kontrol selektif: Ubah coordinator agar menyalakan Light1 dan
    mematikan Light2 pada saat yang sama (bukan toggle serentak). Ini
    membuktikan perintah benar-benar dialamatkan per node, bukan disiarkan.

  / CH-4 --- Deteksi node hilang: Tambahkan mekanisme di coordinator untuk
    menandai node yang tidak merespons, misalnya menghitung berapa siklus
    berturut-turut tanpa laporan balik dari CH-2 Modul 08. Cetak
    `Node 0xXXXX tidak merespons` setelah 3 siklus.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (Zigbee multi-node, ZC dan ZED, binding table, endpoint,
  cluster).
+ Konfigurasi --- env `coordinator`, `light1`, `light2`, endpoint 5, 10, 11,
  serta interval 5 detik.
+ Hasil eksperimen --- log join, daftar binding, log ketiga board (EXP-01
  sampai EXP-03 beserta checkpoint).
+ Data pengukuran --- tabel jarak, tabel per-node, dan tabel perbandingan
  dengan M05.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-2.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
