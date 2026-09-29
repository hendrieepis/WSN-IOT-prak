// ============================================================================
// Modul 08 — Zigbee P2P: Join & Binding
// Sumber: week08_zigbee_p2p/README.md; listing kode dibaca langsung dari
//         assets/code/week08_zigbee_p2p/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 08 — Zigbee P2P: Join dan Binding", l: "bab:modul-08")

#identitas-modul(
  "Modul 08",
  [Join a Zigbee Network --- Zigbee P2P: Join dan Binding],
  [ESP32-H2 · Zigbee · ZC ke ZED · level Advanced · 3 × 50 menit ·
   folder kode `week08_zigbee_p2p`],
)

#pengantar([Gambaran Umum])[
Modul 08 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut.
Misinya membentuk jaringan Zigbee, memasukkan satu end device ke dalamnya, dan
mengendalikannya lewat binding. Percobaan berjalan sebagai Zigbee P2P antara
coordinator yang berperan sebagai switch dan end device yang berperan sebagai
lampu, diamati melalui dua terminal Serial Monitor pada 115200 baud dengan LED
RGB bawaan sebagai penanda visual.
]

== Pendahuluan

Pada M07 frame disusun sendiri: tidak ada identitas jaringan, tidak ada
keamanan, tidak ada penemuan perangkat. Zigbee menambahkan ketiganya di atas
radio 802.15.4 yang *sama persis*. Yang menarik justru harga yang harus
dibayar: firmware jauh lebih besar (butuh tabel partisi khusus), dan perangkat
menyimpan keanggotaan jaringan di NVS --- sesuatu yang tidak pernah jadi
masalah di modul-modul BLE.

Prasyaratnya adalah M07: channel, PAN ID, dan pemahaman bahwa Zigbee berjalan
di radio 802.15.4 yang sama. Yang dibangun di sini adalah pembentukan PAN,
window join, prosedur find-and-bind, cluster ON/OFF, perbedaan mode build ZCZR
dan ED, tabel partisi khusus Zigbee, serta penyimpanan keanggotaan jaringan di
NVS. Semuanya dipakai lagi pada M09 ketika satu coordinator melayani banyak end
device melalui binding table, M10 ketika router menambah hop, dan M16 ketika
Zigbee menjadi salah satu protokol yang dibandingkan.

*Peta modul blok Zigbee*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [07], [802.15.4 telanjang --- frame disusun manual],
    [*08 (ini)*], [*Jaringan Zigbee terbentuk: join, binding, cluster ON/OFF*],
    [09], [Satu coordinator melayani banyak end device (binding table)],
    [10], [Router menambah hop --- routing multi-hop otomatis],
  ),
  [Peta modul blok Zigbee],
  "tbl:m08-peta",
)

*Kontrak data lab ini.* Zigbee tidak mengirim "string", melainkan *perintah
cluster standar* (`On/Off`). Perbedaan ini penting untuk M16: BLE dan Thread di
lab ini mengirim payload bebas, Zigbee mengirim perintah baku. Catat
konsekuensinya pada interoperabilitas --- perangkat Zigbee merek berbeda bisa
saling mengerti, payload BLE buatan sendiri tidak.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membentuk jaringan Zigbee dan mengendalikan lewat binding])[
  + Membentuk jaringan Zigbee dengan satu coordinator dan memasukkan satu end
    device melalui window join 180 detik, dibuktikan dari log kedua board.
  + Menjelaskan perbedaan *join* dan *binding* dengan menunjuk baris log yang
    menandai masing-masing tahap.
  + Mengukur waktu join dan binding serta latency perintah ON/OFF (coordinator
    sampai LED berubah di end device) pada minimal 4 jarak.
  + Menjelaskan mengapa dua peran membutuhkan `build_flags` dan tabel partisi
    berbeda, serta akibatnya bila tertukar.
]

*Kriteria keberhasilan*

#checklist((
  [Coordinator mencetak `End device ter-binding!`.],
  [LED RGB pada end device berubah ON/OFF tiap 5 detik mengikuti perintah.],
  [Waktu join dan binding tercatat, minimal 3 percobaan.],
  [Tabel jarak--latency--success terisi dari pengukuran sendiri.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (ZDO,
APS layer, key management, Zigbee Cluster Library lengkap) berada di buku teori
terpisah. Istilah kerja dirangkum pada @tbl:m08-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Zigbee], [Protokol jaringan di atas IEEE 802.15.4 untuk otomasi; dipakai lewat library `Zigbee` Arduino core 3.x.],
    [Coordinator (ZC)], [Membentuk dan mengelola PAN; build flag `-DZIGBEE_MODE_ZCZR`.],
    [End Device (ZED)], [Node akhir hemat daya, tidak meneruskan trafik; build flag `-DZIGBEE_MODE_ED`.],
    [Endpoint], ["Nomor kamar" fungsi di dalam satu perangkat: switch EP 5, light EP 10.],
    [Join], [End device masuk ke jaringan yang dibuka coordinator (`setRebootOpenNetwork(180)`).],
    [Binding], [Mengaitkan endpoint switch dengan endpoint light (find-and-bind) agar perintah punya tujuan.],
    [Cluster ON/OFF], [Perintah standar Zigbee untuk menyalakan atau mematikan beban (`lightOn()` dan `lightOff()`).],
    [Partisi khusus], [`partitions_zczr.csv` dan `partitions_ed.csv` menyediakan `zb_storage` dan `zb_fct`.],
    [NVS jaringan], [Keanggotaan Zigbee disimpan di flash --- bertahan melewati reset *dan* melewati flash ulang firmware.],
  ),
  [Istilah kerja Modul 08],
  "tbl:m08-istilah",
)

*Join berbeda dari binding.* Join membuat perangkat menjadi *anggota jaringan*
(punya alamat, punya kunci). Binding membuat satu endpoint *tahu harus mengirim
ke endpoint mana*. Perangkat bisa sudah join tetapi belum ter-binding --- dan
perintahnya tidak akan sampai ke mana pun. Dua tahap ini muncul sebagai dua
baris log yang berbeda; pastikan keduanya dapat ditunjuk.

*Dari XBee ke ESP32-H2: di mana MY, SH, dan SL?* Kalau sebelumnya Anda
belajar komunikasi dengan modul XBee, semua konsep alamat di sana tetap berlaku
--- hanya cara mengaksesnya yang berbeda. Di XBee, parameter dibaca dan diatur
dengan perintah AT (`ATMY`, `ATSH`, ...) lewat XCTU atau terminal. Di ESP32-H2,
nilai yang sama dibaca dari stack ESP-Zigbee oleh kode, lalu dicetak fungsi
`printNetworkInfo()`. Padanan lengkapnya ada pada @tbl:m08-xbee.

#diagram(```
  Short address  : 0x7EC7                    ← MY  (alamat logika 16-bit)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1   ← SH + SL (alamat fisik 64-bit)
                   └── SH ───┘ └── SL ───┘
                   0x744DBDFF  0xFE61E8C1
```.text)

#tbl(
  table(
    columns: (0.62fr, 1fr, 1.55fr, 1.25fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.4em),
    stroke: 0.5pt + luma(170),
    table.header(th[XBee (AT)], th[Arti], th[Di ESP32-H2 / log modul ini], th[Catatan]),
    [*MY*], [Alamat *logika* 16-bit (network address)], [`Short address` --- `esp_zb_get_short_address()`], [Di Zigbee *dibagikan coordinator saat join*, hanya bisa dibaca; coordinator selalu `0x0000`. Bisa berubah bila node join ulang.],
    [*SH*], [32 bit *atas* alamat *fisik* 64-bit], [4 byte pertama `IEEE address` --- `esp_zb_get_long_address()`], [Ditanam pabrik, tetap, unik sedunia --- sama seperti nomor di label XBee.],
    [*SL*], [32 bit *bawah* alamat fisik 64-bit], [4 byte terakhir `IEEE address`], [],
    [*CH*], [Channel operasi], [`Channel` --- `esp_zb_get_current_channel()`], [XBee menulisnya heksadesimal: channel 18 = `0x12`.],
    [*SC*], [Daftar channel yang boleh di-scan], [`Zigbee.`#sym.zws`setPrimaryChannelMask()`], [Default semua channel 11--26.],
    [*ID*], [Extended PAN ID yang *diminta*], [Tidak diatur di kode modul ini], [ID = 0 di XBee berarti "coordinator yang memilih"; di sini coordinator memakai IEEE address-nya sendiri.],
    [*OP*], [Extended PAN ID 64-bit yang *dipakai*], [`Extended PAN ID` --- `esp_zb_get_extended_pan_id()`], [],
    [*OI*], [PAN ID 16-bit yang *dipakai*], [`PAN ID` --- `esp_zb_get_pan_id()`], [Dipilih acak oleh coordinator saat membentuk network.],
    [*CE*], [Coordinator Enable (peran node)], [Build flag `ZIGBEE_MODE_ZCZR` / `ZIGBEE_MODE_ED` + `Zigbee.begin(ZIGBEE_COORDINATOR)`], [Di ESP32 peran dipilih saat *build*, bukan lewat perintah AT.],
    [*NJ*], [Lama network terbuka untuk join], [`Zigbee.`#sym.zws`setRebootOpenNetwork(180)`], [Sama-sama dalam detik.],
    [*AI*], [Status asosiasi (0 = sudah join)], [`Zigbee.connected()`], [],
    [*DH / DL*], [Alamat 64-bit *tujuan* (mode transparan)], [*Tidak ada padanan langsung* --- tujuan ditentukan *binding table*], [Lihat penjelasan di bawah.],
    [Endpoint `0xE8` \ (DE/SE)], [Endpoint data transparan Digi], [Endpoint 5 (switch) dan 10 (light)], [Zigbee standar memakai endpoint + cluster (On/Off = `0x0006`), bukan satu endpoint data umum.],
  ),
  [Padanan parameter XBee dan ESP32-H2 pada Modul 08],
  "tbl:m08-xbee",
)

Tiga perbedaan yang paling sering membingungkan:

+ *MY tidak Anda isi sendiri.* Pada XBee 802.15.4 (Series 1) dan pada M07,
  alamat 16-bit ditentukan pengguna (`0x0001`, `0x0002`). Pada Zigbee --- baik
  XBee Zigbee (Series 2/3) maupun ESP32-H2 --- alamat 16-bit *diberikan
  coordinator* saat join. Karena bisa berubah, alamat yang pasti untuk mengenali
  satu perangkat adalah *SH+SL (IEEE address)*, bukan MY.
+ *Tidak ada DH/DL.* Di XBee mode transparan, Anda menulis alamat tujuan ke
  DH/DL lalu semua data serial terkirim ke sana. Di Zigbee standar, switch
  mengirim _command_ `On`/`Off` ke *endpoint* yang tercatat di *binding table*
  --- isinya diisi otomatis oleh find-and-bind. Karena itu log coordinator
  mencetak `End device ter-binding!`, bukan alamat tujuan.
+ *Yang dikirim bukan byte mentah, melainkan command cluster.* XBee transparan
  meneruskan byte apa pun yang masuk ke UART-nya. `lightOn()` mengirim command
  ZCL `On` pada cluster On/Off, dan penerimanya harus endpoint yang memang
  mengerti cluster itu (`ZigbeeLight`).

*`ZigbeeSwitch` dan `ZigbeeLight` bukan fitur standar Zigbee.* Keduanya class
C++ buatan Espressif di library `Zigbee` Arduino core 3.x, yang membungkus
_device type_ standar (On/Off Light Switch dan On/Off Light) beserta cluster
On/Off, endpoint, dan find-and-bind. Yang standar adalah cluster, device type,
dan command-nya (`On`, `Off`, `Toggle`); nama method seperti `bound()`,
`allowMultipleBinding()`, dan `onLightStateChange()` adalah API Espressif.
Pembagian perannya dirangkum pada @tbl:m08-class-dasar.

#tbl(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Class], th[Mewakili], th[Yang disembunyikan class ini]),
    [`ZigbeeSwitch`], [On/Off Light Switch (cluster On/Off sisi _client_, mengirim command)], [Membuat endpoint, mendaftarkan cluster, find-and-bind. `lightOn()` mengirim command ZCL `On` ke tujuan di binding table.],
    [`ZigbeeLight`], [On/Off Light (cluster On/Off sisi _server_, menerima command)], [Menerima command lalu memanggil callback `onLightChange`.],
  ),
  [Class dasar yang dipakai pada Modul 08],
  "tbl:m08-class-dasar",
)

*Class lain di library `Zigbee`.* Semua class endpoint mewarisi `ZigbeeEP` dan
dipakai dengan pola yang sama: buat objek dengan nomor endpoint,
`setManufacturerAndModel()`, `Zigbee.addEndpoint()`, lalu `Zigbee.begin()`.
Objek global `Zigbee` mengelola stack (`begin()`, `connected()`,
`setRebootOpenNetwork()`). Daftar class dikelompokkan pada
@tbl:m08-class-lain.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Kategori], th[Class]),
    [Lampu dan saklar], [`ZigbeeLight`, `ZigbeeSwitch`, `ZigbeeColorDimmableLight`, `ZigbeeColorDimmerSwitch`],
    [Sensor], [`ZigbeeTempSensor`, `ZigbeeFlowSensor`, `ZigbeePressureSensor`, `ZigbeeOccupancySensor`, `ZigbeeContactSwitch`, `ZigbeeVibrationSensor`, `ZigbeeIlluminanceSensor`, `ZigbeeCarbonDioxideSensor`],
    [Aktuator], [`ZigbeePowerOutlet`, `ZigbeeWindowCovering`, `ZigbeeFanControl`, `ZigbeeDoorWindowHandle`],
    [Kontrol dan ukur], [`ZigbeeThermostat`, `ZigbeeElectricalMeasurement`],
    [Generik], [`ZigbeeAnalog`, `ZigbeeBinary`, `ZigbeeGateway`],
  ),
  [Class endpoint pada library `Zigbee`],
  "tbl:m08-class-lain",
)

#catatan[
  Daftar ini bergantung pada versi Arduino core; sumber pastinya ada di
  `libraries/Zigbee/src/ep/` pada repositori `espressif/arduino-esp32`.
  `ZigbeeTempSensor` paling relevan untuk WSN karena mengirim data sensor lewat
  attribute reporting, bukan hanya perintah On/Off.
]

*Sekuens protokol yang diamati*

#diagram(```
 Coordinator boot ──► Zigbee.begin(ZIGBEE_COORDINATOR)
    ──► network terbuka 180 s ──► ED join ──► find-and-bind switch↔light
    ──► loop 5 s: lightOn() / lightOff() ──► ED: setLED ON/OFF
```.text)

== Topologi

#diagram(```
          BOARD #1                              BOARD #2
+---------------------------+   perintah ON/OFF (5 s)   +---------------------------+
|        ESP32-H2           | ------------------------> |        ESP32-H2           |
| Coordinator (switch)      |   join + binding          | End Device (light)        |
| ZIGBEE_MODE_ZCZR          | <------------------------ | ZIGBEE_MODE_ED            |
| endpoint 5 (ZigbeeSwitch) |   laporan status lampu    | endpoint 10 (ZigbeeLight) |
+---------------------------+                           +---------------------------+
      env: coordinator                                       env: enddevice
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Endpoint]),
    [Coordinator], [ESP32-H2 DevKitM-1], [`coordinator`], [ZC dan switch], [EP 5],
    [End device], [ESP32-H2 DevKitM-1], [`enddevice`], [ZED dan light], [EP 10],
  ),
  [Peran tiap node Modul 08],
  "tbl:m08-topologi",
)

Kedua peran memakai *ESP32-H2 DevKitM-1*. Perbedaannya hanya pada `build_flags`
(`-DZIGBEE_MODE_ZCZR` dibanding `-DZIGBEE_MODE_ED`) dan tabel partisi ---
board-nya identik, jadi board mana pun bisa diberi peran mana pun.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan library
`Zigbee` bawaan.

#tbl(
  table(
    columns: (auto, 1fr, 1.5fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1, *dengan LED RGB bawaan* (`RGB_BUILTIN`)], [2],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [3], [PC/Laptop], [PlatformIO Core/IDE, 2 port USB bebas], [1],
    [4], [Platform PlatformIO], [pioarduino `espressif32` 55.03.311 (library `Zigbee` bawaan core 3.x)], [---],
    [5], [Tabel partisi], [`partitions_zczr.csv` (ZC) dan `partitions_ed.csv` (ED) --- sudah ada di folder modul], [---],
  ),
  [Alat dan bahan Modul 08],
  "tbl:m08-alat",
)

== Kode Program

#sumber-kode("week08_zigbee_p2p",
  ("platformio.ini", "partitions_zczr.csv", "partitions_ed.csv",
   "src/coordinator/main.cpp", "src/enddevice/main.cpp"))

*Dua peran, dua tabel partisi.* Potongan `platformio.ini` pada
@lst:m08-ini-readme memperlihatkan perbedaan `build_flags` dan
`board_build.partitions` antara kedua environment.

#kode(```ini
[env:coordinator]
build_src_filter = +<coordinator/*.cpp>
build_flags =
    -DZIGBEE_MODE_ZCZR
    -lesp_zb_api.zczr
    -lzboss_stack.zczr
    -lzboss_port.native
board_build.partitions = partitions_zczr.csv
upload_port  = /dev/ttyACM0
monitor_port = /dev/ttyACM0

[env:enddevice]
build_src_filter = +<enddevice/*.cpp>
build_flags =
    -DZIGBEE_MODE_ED
    -lesp_zb_api.ed
    -lzboss_stack.ed
    -lzboss_port.native
board_build.partitions = partitions_ed.csv
upload_port  = /dev/ttyACM2
monitor_port = /dev/ttyACM2
```.text,
  [Potongan `platformio.ini` --- dua peran dengan tabel partisi berbeda],
  "lst:m08-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week08_zigbee_p2p/platformio.ini",
  [`platformio.ini` Modul 08 pada repositori],
  "lst:m08-ini",
)

#kode-berkas("week08_zigbee_p2p/partitions_zczr.csv",
  [`partitions_zczr.csv` --- tabel partisi peran coordinator/router],
  "lst:m08-part-zczr",
  bahasa: "text",
)

#kode-berkas("week08_zigbee_p2p/partitions_ed.csv",
  [`partitions_ed.csv` --- tabel partisi peran end device],
  "lst:m08-part-ed",
  bahasa: "text",
)

#catatan[
  Kedua berkas partisi di atas identik isinya pada modul M08, M09, dan M10,
  sehingga listing yang sama tidak diulang pada bab-bab berikutnya.
]

#kode-berkas("week08_zigbee_p2p/src/coordinator/main.cpp",
  [`src/coordinator/main.cpp` --- coordinator sekaligus switch (EP 5)],
  "lst:m08-coordinator",
  pecah: true,
)

#kode-berkas("week08_zigbee_p2p/src/enddevice/main.cpp",
  [`src/enddevice/main.cpp` --- end device sekaligus light (EP 10)],
  "lst:m08-enddevice",
  pecah: true,
)

== Build dan Flash

Coordinator dulu, lalu end device *dalam 180 detik*.

#keluaran("pio run -d week08_zigbee_p2p -e enddevice   -t erase     # bersihkan NVS
pio run -d week08_zigbee_p2p -e coordinator -t erase
pio run -d week08_zigbee_p2p -e coordinator -t upload -t monitor
pio run -d week08_zigbee_p2p -e enddevice   -t upload    # jangan lewat 180 s")

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
  [`pio device list` dijalankan, dua port dicatat dan diisikan di atas.],
  [*Hapus NVS kedua board sebelum flash pertama:*
   `pio run -d week08_zigbee_p2p -e enddevice -t erase`. Tanpa ini, board yang
   pernah join jaringan lain akan terus mencari koordinator lama.],
  [Environment `coordinator` (ZCZR) dan `enddevice` (ED) dikenali PlatformIO.],
  [Serial Monitor 115200 baud untuk kedua board.],
  [Endpoint dipahami: switch EP 5, light EP 10.],
  [Tidak ada jaringan Zigbee lain aktif di sekitar (hindari interferensi dan
   salah join).],
))

== Percobaan

=== EXP-01 --- Pembentukan Jaringan (Coordinator)

Unggah environment `coordinator`, buka Serial Monitor, verifikasi: coordinator
membentuk network, mencetak parameternya, membuka network 180 detik, lalu
menunggu binding.

#diagram(```
 boot ──► begin(ZIGBEE_COORDINATOR) OK
      ──► network terbentuk: cetak channel, PAN ID, alamat
      ──► network terbuka 180 s
      ──► menunggu: . . . . . (titik tiap 500 ms)
```.text)

Channel dan PAN ID *tidak ditulis di kode*: coordinator memilih sendiri saat
membentuk network (channel dari hasil scan, PAN ID acak), lalu menyimpannya di
NVS. Nilainya dibaca dari stack ESP-Zigbee (`esp_zb_get_current_channel()`,
`esp_zb_get_pan_id()`, dan seterusnya) di fungsi `printNetworkInfo()`, karena
library Arduino hanya menuliskannya ke log debug.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Pesan awal coordinator], [#isian],
    [Channel], [#isian],
    [PAN ID / Extended PAN ID], [#isian],
    [Short address coordinator], [#isian],
    [Lama network terbuka (s)], [#isian],
    [Endpoint switch], [#isian],
    [Perintah yang dikirim tiap 5 s], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m08-exp01",
)

#buka-abstraksi[
  Bandingkan ukuran firmware modul ini dengan modul BLE (lihat ringkasan
  `RAM/Flash` di akhir `pio run`). Lalu buka `partitions_zczr.csv`
  (@lst:m08-part-zczr) dan temukan partisi `zb_storage` dan `zb_fct`. Jawab:
  apa yang disimpan di sana, dan mengapa tabel partisi default Arduino tidak
  cukup?
]

#checkpoint[
  Coordinator mencetak titik-titik `.` berulang. Jika langsung muncul
  `Zigbee gagal start!` lalu board restart, tabel partisi atau `build_flags`
  tidak cocok --- perbaiki sebelum lanjut.
]

=== EXP-02 --- Join dan Binding (End Device)

Unggah environment `enddevice` ke board kedua *sebelum 180 detik habis*. Amati
proses join lalu binding, dan verifikasi RGB bawaan berkedip ON/OFF tiap
5 detik.

#diagram(```
 ED boot ──► Zigbee.begin() ──► scan channel
          ──► join network ──► find & bind ke switch
 ZC loop 5 s: lightOn() … lightOff() … (bergantian)
```.text)

*Expected output --- Coordinator* (nilai channel, PAN ID, dan alamat dari uji
di board; di board Anda akan berbeda)

#keluaran("Network Zigbee terbentuk:
  Peran          : Coordinator (ZC)
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu end device ter-binding...
End device ter-binding!
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF")

Bila binding berlangsung lambat, baris titik-titik (`....`) tercetak di bawah
`Menunggu end device ter-binding...` selama menunggu.

#catatan[
  Baris `Lampu sekarang: ...` berasal dari callback `onLightStateChange()`,
  yaitu *laporan balik* dari lampu ke switch. Pada firmware Arduino core 3.3.x
  baris ini tidak muncul karena `ZigbeeLight` tidak mengonfigurasi attribute
  reporting ke switch secara otomatis --- perintah tetap sampai dan lampu tetap
  menyala. Mengaktifkan laporan balik justru menjadi CH-2.
]

*Expected output --- End device*

#keluaran("Menunggu bergabung ke network koordinator...
Berhasil bergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x7EC7 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
Lampu ON
Lampu OFF")

Padanan XBee (@tbl:m08-xbee): `Short address` = *MY*, `IEEE address` =
*SH + SL*, `Channel` = *CH*, `PAN ID` = *OI*, `Extended PAN ID` = *OP*.

Bandingkan info network kedua board: *Channel, PAN ID, dan Extended PAN ID
harus sama* --- itulah bukti end device bergabung ke network coordinator ini,
bukan network lain. Short address coordinator selalu `0x0000`; short address
end device dibagikan coordinator saat join. Bila tidak diatur di kode,
Extended PAN ID diambil dari IEEE address coordinator --- terlihat pada log di
atas.

#checkpoint[
  Dua hal harus terjadi berurutan: end device mencetak
  `Berhasil bergabung ke network!` (join), lalu coordinator mencetak
  `End device ter-binding!` (binding). Jika join berhasil tetapi binding tidak
  pernah terjadi, perintah tidak akan sampai --- jangan lanjut, ulangi dengan
  menghapus NVS kedua board.
]

=== EXP-03 --- Keandalan Kontrol

+ Hitung siklus ON/OFF per menit (harapan 12) dan bandingkan status di kedua
  Serial Monitor.
+ Reset end device --- catat waktu join ulang dan verifikasi apakah keanggotaan
  tersimpan (network terbuka lagi tiap coordinator reboot 180 s).
+ *Cabut daya coordinator selama 30 detik*, lalu nyalakan lagi. Amati apakah
  end device otomatis kembali atau perlu di-reset.
+ Geser jarak bertahap dan catat kapan perintah mulai tertinggal.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Siklus ON/OFF per menit], [#isian],
    [Waktu join ulang setelah reset ED], [#isian],
    [Perilaku saat coordinator mati lalu hidup], [#isian],
    [Sinkron status ZC dan ED?], [#isian],
    [Jarak mulai ada perintah tertinggal (m)], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m08-exp03",
)

#checkpoint[
  Praktikan dapat menjelaskan mengapa end device yang di-reset bisa kembali
  *tanpa* window join dibuka lagi (petunjuk: keanggotaan tersimpan di NVS, join
  hanya diperlukan sekali).
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 2 × *ESP32-H2 DevKitM-1* (flash di-erase lebih dulu agar tidak
ada sisa jaringan Zigbee lama di NVS), capture 70 detik.

#keluaran("# Coordinator (ESP32-H2, ZCZR)         # End device (ESP32-H2, ED)
[0.401] Menunggu end device ...        [0.401] Menunggu bergabung ...
[3.407] ......                         [3.205] Berhasil bergabung ke network!
[3.407] End device ter-binding!
[5.209] Perintah: Lampu ON             [5.207] Lampu ON
[10.219] Perintah: Lampu OFF           [10.214] Lampu OFF")

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu join dan binding sejak boot], [3,4 s],
    [Perintah dikirim coordinator], [13],
    [Aksi terjadi di end device], [13 (0 % loss)],
    [Selisih waktu perintah sampai aksi], [≈ 2 ms],
    [Siklus ON/OFF per menit], [12],
  ),
  [Hasil verifikasi hardware Modul 08],
  "tbl:m08-verifikasi",
)


// Log serial lengkap dari week08_zigbee_p2p/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2 DevKitM-1, firmware `src/coordinator` dan `src/enddevice` versi terbaru: setelah network terbentuk (coordinator) atau setelah join (end device), tiap board mencetak info network — channel, PAN ID, Extended PAN ID, short address, IEEE address, dan endpoint. Log direkam 60 detik dengan `monitor_serial.py` (ketiga port dalam satu komputer, satu sumbu waktu) lewat port UART CH343 di Windows.

  Ketiga board di-`erase` lalu di-flash; network terbentuk pada boot pertama coordinator. Log di bawah direkam setelah monitor me-reset ketiga board saat port dibuka, jadi coordinator *memulihkan* network dari NVS (bukan membentuk baru) dan end device bergabung kembali ke network yang sama.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: (left, left, left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Peran], th[Endpoint], th[Short address (MY)], th[IEEE address (SH+SL)], th[Port serial (UART)]),
      [Coordinator], [Zigbee Coordinator (ZCZR) — switch], [5], [`0x0000`], [`74:4D:BD:FF:` \ `FE:61:E6:2C`], [`COM5`],
      [ED COM11], [Zigbee End Device (ED) — light, *ter-binding*], [10], [`0x7EC7`], [`74:4D:BD:FF:` \ `FE:61:E8:C1`], [`COM11`],
      [ED COM13], [Zigbee End Device (ED) — light, tidak ter-binding], [10], [`0xEF6E`], [`74:4D:BD:FF:` \ `FE:61:F3:97`], [`COM13`],
    ),
    [Board dan port pada rekaman log serial Modul 08],
    "tbl:m08-log-1",
  )

  Network: channel *18*, PAN ID *`0x4FC6`*, Extended PAN ID *`74:4D:BD:FF:FE:61:E6:2C`* — sama di ketiga board.

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
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x0000
  IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
  Endpoint       : 5 (switch)
Menunggu end device ter-binding...
End device ter-binding!
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON
Perintah: Lampu OFF
Perintah: Lampu ON", pecah: true)

  *ED COM11 (ter-binding, menerima perintah)*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Menunggu bergabung ke network koordinator...
Berhasil bergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0x7EC7 (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
  Endpoint       : 10 (light)
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON
Lampu OFF
Lampu ON", pecah: true)

  *ED COM13 (join, tidak ter-binding)*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Menunggu bergabung ke network koordinator...
Berhasil bergabung ke network!
Info network:
  Peran          : End Device (ED)
  Channel        : 18
  PAN ID         : 0x4FC6
  Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
  Short address  : 0xEF6E (diberikan coordinator)
  IEEE address   : 74:4D:BD:FF:FE:61:F3:97
  Endpoint       : 10 (light)", pecah: true)

  *Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)*

  #keluaran("[   0.452] Coordinator | Network Zigbee terbentuk:
[   0.452] Coordinator |   Peran          : Coordinator (ZC)
[   0.452] Coordinator |   Channel        : 18
[   0.452] Coordinator |   PAN ID         : 0x4FC6
[   0.452] Coordinator |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.452] Coordinator |   Short address  : 0x0000
[   0.452] Coordinator |   IEEE address   : 74:4D:BD:FF:FE:61:E6:2C
[   0.452] Coordinator |   Endpoint       : 5 (switch)
[   0.670] Coordinator | Menunggu end device ter-binding...
[   0.670] Coordinator | End device ter-binding!
[   0.702] ED COM11    | Menunggu bergabung ke network koordinator...
[   0.702] ED COM11    | Berhasil bergabung ke network!
[   0.702] ED COM11    | Info network:
[   0.702] ED COM11    |   Peran          : End Device (ED)
[   0.702] ED COM11    |   Channel        : 18
[   0.702] ED COM11    |   PAN ID         : 0x4FC6
[   0.702] ED COM11    |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   0.924] ED COM11    |   Short address  : 0x7EC7 (diberikan coordinator)
[   0.924] ED COM11    |   IEEE address   : 74:4D:BD:FF:FE:61:E8:C1
[   0.924] ED COM11    |   Endpoint       : 10 (light)
[   5.602] ED COM11    | Lampu ON
[   5.602] Coordinator | Perintah: Lampu ON
[   6.460] ED COM13    | Menunggu bergabung ke network koordinator...
[   6.460] ED COM13    | Berhasil bergabung ke network!
[   6.460] ED COM13    | Info network:
[   6.460] ED COM13    |   Peran          : End Device (ED)
[   6.460] ED COM13    |   Channel        : 18
[   6.460] ED COM13    |   PAN ID         : 0x4FC6
[   6.460] ED COM13    |   Extended PAN ID: 74:4D:BD:FF:FE:61:E6:2C
[   6.682] ED COM13    |   Short address  : 0xEF6E (diberikan coordinator)
[   6.682] ED COM13    |   IEEE address   : 74:4D:BD:FF:FE:61:F3:97
[   6.682] ED COM13    |   Endpoint       : 10 (light)
[  10.591] Coordinator | Perintah: Lampu OFF
[  10.591] ED COM11    | Lampu OFF
[  15.587] Coordinator | Perintah: Lampu ON
[  15.603] ED COM11    | Lampu ON
[  20.600] Coordinator | Perintah: Lampu OFF
[  20.601] ED COM11    | Lampu OFF
[  25.589] Coordinator | Perintah: Lampu ON
[  25.605] ED COM11    | Lampu ON
[  30.596] Coordinator | Perintah: Lampu OFF
[  30.612] ED COM11    | Lampu OFF
[  35.605] Coordinator | Perintah: Lampu ON
[  35.605] ED COM11    | Lampu ON
[  40.594] Coordinator | Perintah: Lampu OFF
[  40.610] ED COM11    | Lampu OFF
[  45.612] Coordinator | Perintah: Lampu ON
[  45.612] ED COM11    | Lampu ON
[  50.592] Coordinator | Perintah: Lampu OFF
[  50.608] ED COM11    | Lampu OFF
[  55.613] Coordinator | Perintah: Lampu ON
[  55.613] ED COM11    | Lampu ON", pecah: true)

  *Ringkasan `monitor_serial.py`*

  #keluaran("Durasi: 60.4 s
  Coordinator switch, ep 5  COM5             30 baris, boot 1x, ter-binding  0.30 s sejak boot
              channel 18, PAN 0x4FC6, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x0000
  ED COM11    light, ep 10  COM11            30 baris, boot 1x, bergabung  0.33 s sejak boot
              channel 18, PAN 0x4FC6, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0x7EC7
  ED COM13    light, ep 10  COM13            19 baris, boot 1x, bergabung  6.09 s sejak boot
              channel 18, PAN 0x4FC6, ext PAN 74:4D:BD:FF:FE:61:E6:2C, short 0xEF6E
  Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Perintah Coordinator -> ED COM11 (COM11)
------------------------------------------------------------
  Perintah dikirim (ZC)      : 11  (ON 6, OFF 5)
  Aksi terlaksana (ED)       : 11
  Loss                       : 0.0%
  Selisih perintah -> aksi   : rata2 7 ms (-0..16)  — timestamp PC, kasar
  Siklus ON/OFF per menit    : 12.0  (harapan 12: satu perintah tiap 5 s)
  Status akhir ZC vs ED      : ON vs ON -> sinkron: ya

Perintah Coordinator -> ED COM13 (COM13)
------------------------------------------------------------
  Perintah dikirim (ZC)      : 11  (ON 6, OFF 5)
  Aksi terlaksana (ED)       : 0
  Loss                       : 100.0%
  Siklus ON/OFF per menit    : 12.0  (harapan 12: satu perintah tiap 5 s)
  Perintah tanpa aksi di ED  : ON @ 5.6 s, OFF @ 10.6 s, ON @ 15.6 s, OFF @ 20.6 s, ON @ 25.6 s, OFF @ 30.6 s, ON @ 35.6 s, OFF @ 40.6 s, ON @ 45.6 s, OFF @ 50.6 s ...

  Laporan balik ke switch ('Lampu sekarang', CH-2): 0

Aksi dipasangkan bila status sama dan jatuh -0.5..+2.0 s dari perintah.", pecah: true)

  *Catatan*

  - *Info network cocok di ketiga board*: channel 18, PAN ID `0x4FC6`, dan Extended PAN ID sama — bukti ketiganya berada di satu network. Short address coordinator `0x0000`; short address end device (`0x7EC7`, `0xEF6E`) dibagikan coordinator saat join.
  - *Extended PAN ID = IEEE address coordinator* (`74:4D:BD:FF:FE:61:E6:2C`), karena Extended PAN ID tidak diatur di kode.
  - Padanan XBee: `Short address` = MY, `IEEE address` = SH+SL (mis. ED COM11: SH `0x744DBDFF`, SL `0xFE61E8C1`), `Channel` = CH (18 = `0x12`), `PAN ID` = OI, `Extended PAN ID` = OP. Lihat tabel di README bagian Dasar Teori.
  - *Hanya satu end device yang menerima perintah.* Coordinator memakai `allowMultipleBinding(false)` (P2P), sehingga hanya ED COM11 yang ada di binding table. ED COM13 tetap join dan mendapat alamat, tetapi tidak pernah mencetak `Lampu ON/OFF` — contoh nyata bahwa _join ≠ binding_.
  - `End device ter-binding!` tercetak 0,67 s setelah boot karena binding table ikut dipulihkan dari NVS; coordinator tidak menunggu find-and-bind ulang.
  - ED COM11 bergabung 0,33 s setelah boot, sebelum perintah pertama (5,6 s), sehingga *11 dari 11 perintah sampai (0 % loss)* dengan selisih 0–16 ms (timestamp PC, kasar) dan 12 perintah per menit sesuai interval 5 s.
  - ED COM13 baru bergabung 6,1 s setelah boot. Lama join berbeda antar-end device dan antar-rekaman; bila end device yang ter-binding belum selesai join, perintah pertama akan tercatat hilang.
  - Library Arduino core 3.3.x tidak pernah men-set `Zigbee.connected()` untuk coordinator yang *reboot* dengan `setRebootOpenNetwork()` aktif (seperti pada log ini); karena itu firmware coordinator tidak menunggu flag tersebut (lihat komentar di `src/coordinator/main.cpp`).
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

#tbl(
  table(
    columns: (auto, 1fr, 1.3fr, 1.2fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak], th[RSSI (dBm)], th[Latency perintah (kasar)],
      th[Success ON/OFF (%)],
    ),
    [1 m], [#isian], [], [],
    [3 m], [#isian], [], [],
    [5 m], [#isian], [], [],
    [10 m], [#isian], [], [],
    [15 m], [#isian], [], [],
  ),
  [Lembar pengukuran jarak Modul 08],
  "tbl:m08-ukur",
)

*Pengukuran per-node* (pengamatan 2 menit, jarak tetap).

#tbl(
  table(
    columns: (1.3fr, 1fr, 1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Perintah terkirim], th[Aksi terlaksana], th[Loss (%)]),
    [Coordinator (switch)], [#isian], [---], [],
    [End device (light)], [---], [#isian], [],
  ),
  [Lembar pengukuran per-node Modul 08],
  "tbl:m08-pernode",
)

*Waktu join dan binding* (minimal 3 percobaan, hapus NVS tiap kali).

#tbl(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Percobaan], th[Waktu join (s)], th[Waktu binding (s)], th[Total (s)]),
    [1], [#isian], [], [],
    [2], [#isian], [], [],
    [3], [#isian], [], [],
  ),
  [Lembar pengukuran waktu join dan binding],
  "tbl:m08-join",
)

*Bandingkan dengan M07.* Pada jarak yang sama, apakah success rate Zigbee lebih
baik, sama, atau lebih buruk daripada raw 802.15.4? Radionya identik, jadi
selisih apa pun berasal dari lapisan di atasnya.

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Bagaimana pengaruh jarak terhadap keberhasilan perintah ON/OFF diterima
  lampu?
+ Apakah latency perintah (ZC hingga LED berubah di ED) bertambah pada jarak
  jauh?
+ Berapa persen perintah gagal dalam 2 menit pengamatan, dan pola gagalnya
  bagaimana (acak atau berkelompok)?
+ Berapa waktu proses join dan binding dari tiga percobaan, dan apa yang
  membuatnya bervariasi?
+ Apakah Zigbee (join dan binding otomatis ditambah enkripsi) lebih cocok untuk
  WSN dibanding raw 802.15.4 M07? Sebutkan apa yang diperoleh dan apa harga
  yang dibayar.

== Concept Check

+ Apa fungsi coordinator dalam jaringan Zigbee?
+ Apa perbedaan proses join dan binding? Bisakah salah satu terjadi tanpa yang
  lain?
+ Mengapa end device memakai partisi dan library berbeda (`partitions_ed.csv`,
  `esp_zb_api.ed`)?
+ Apa yang terjadi bila end device dinyalakan setelah window 180 detik
  berakhir, dan bagaimana cara memperbaikinya?
+ Mengapa `allowMultipleBinding(false)` dipakai pada skenario P2P ini, dan apa
  yang berubah di Modul 09?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Mengukur latency dan menutup arah balik])[
  / CH-1 --- Latency terukur: Ukur latency perintah secara objektif: kirim
    timestamp di payload atau catat `millis()` saat `lightOn()` di coordinator
    dan saat `setLED()` di end device, lalu bandingkan. Lakukan 20 kali dan
    hitung rata-rata serta sebarannya.

  / CH-2 --- Laporan balik (menutup celah `onLightStateChange`): Aktifkan
    attribute reporting pada `ZigbeeLight` sehingga coordinator benar-benar
    mencetak `Lampu sekarang: ON/OFF`. Bandingkan jumlah perintah terkirim
    dengan laporan diterima untuk menghitung loss arah balik.
]

#tujuan-prak(3, [Kontrol dua arah dan ketahanan NVS])[
  / CH-3 --- Kontrol dari end device: Tambahkan tombol pada end device yang
    mengirim perintah toggle ke coordinator. Diskusikan mengapa ini memerlukan
    binding arah sebaliknya.

  / CH-4 --- Uji ketahanan NVS: Flash ulang end device *tanpa* `-t erase`, lalu
    amati apakah ia langsung kembali ke jaringan. Jelaskan perbedaannya dengan
    perangkat BLE di M01--M06 yang tidak menyimpan apa pun.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (Zigbee, ZC dan ZED, endpoint, join dibanding binding,
  cluster ON/OFF).
+ Konfigurasi --- `build_flags`, tabel partisi, endpoint, window join 180 s.
+ Hasil eksperimen --- log kedua board (EXP-01 sampai EXP-03 beserta
  checkpoint).
+ Data pengukuran --- tabel jarak, tabel per-node, tabel waktu join dan
  binding, serta perbandingan dengan M07.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-2.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
