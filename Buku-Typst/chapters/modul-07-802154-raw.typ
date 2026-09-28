// ============================================================================
// Modul 07 — IEEE 802.15.4 Raw Frame (P2P)
// Sumber: week07_802154_p2p/README.md; listing kode dibaca langsung dari
//         assets/code/week07_802154_p2p/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 07 — IEEE 802.15.4 Raw Frame (P2P)", l: "bab:modul-07")

#identitas-modul(
  "Modul 07",
  [Speak Raw 802.15.4 --- IEEE 802.15.4 Raw Frame (P2P)],
  [ESP32-H2 · 802.15.4 · raw MAC frame · level Intermediate · 3 × 50 menit ·
   folder kode `week07_802154_p2p`],
)

#pengantar([Gambaran Umum])[
Modul 07 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya menyusun sendiri frame MAC 802.15.4 byte demi byte dan membuatnya
terbang tanpa bantuan stack apa pun. Percobaan berjalan sebagai pertukaran raw
frame PING/PONG antara dua node, diamati melalui dua terminal Serial Monitor
pada 115200 baud.
]

== Pendahuluan

Enam modul pertama berjalan di atas BLE, tempat stack menyembunyikan semua
detail radio. Modul ini *membuka lantai dasar*: tidak ada Zigbee, tidak ada
Thread, tidak ada GATT --- hanya PHY/MAC 802.15.4 dan array byte yang disusun
sendiri. Setelah modul ini, setiap kali Zigbee (M08--M10) atau Thread
(M11--M13) tampak "langsung bekerja", praktikan mengetahui persis apa yang
sebenarnya dikerjakan protokol tersebut.

Prasyaratnya adalah M01--M06: alur build, pembacaan Serial Monitor sebagai
instrumen, dan pengukuran loss. Yang dibangun di sini adalah pemahaman
struktur MHR 802.15.4, pengaturan channel dan PAN ID, short address,
penyusunan frame secara manual, serta penanganan callback penerimaan di konteks
ISR. Semuanya dipakai lagi pada M08--M10 karena Zigbee memakai PHY/MAC yang
sama, M11--M13 karena Thread pun demikian, dan M16 saat overhead antarprotokol
dibandingkan di atas radio yang identik.

*Peta modul --- titik balik seri ini*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Lapisan yang dikerjakan]),
    [01--06], [BLE --- stack menyembunyikan radio],
    [*07 (ini)*], [*802.15.4 telanjang --- frame disusun sendiri*],
    [08--10], [Zigbee di atas 802.15.4 --- stack mengurus join, binding, routing],
    [11--13], [Thread di atas 802.15.4 --- stack mengurus IPv6, mesh, dataset],
  ),
  [Titik balik lapisan pada Modul 07],
  "tbl:m07-peta",
)

*Kontrak data lab ini.* Radio yang dipakai M07--M13 *sama persis* (IEEE
802.15.4, channel 15). Yang berbeda hanya lapisan di atasnya. Karena itu angka
RSSI dan jangkauan yang diukur pada modul ini dapat dipakai sebagai garis dasar
(_baseline_) saat membandingkan Zigbee dan Thread di M16.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Menyusun dan menerbangkan frame MAC 802.15.4 sendiri])[
  + Menyusun frame MAC 802.15.4 lengkap (Len ditambah MHR 11 byte ditambah
    payload) dan menunjukkan letak tiap field pada dump heksadesimal frame yang
    benar-benar tertangkap.
  + Menjelaskan tiga aturan API `esp_ieee802154_*` yang wajib dipatuhi
    (panjang `Len` termasuk FCS, `esp_ieee802154_receive()` di `setup()`,
    buffer TX harus `static`) beserta gejala kegagalannya.
  + Menjalankan pertukaran PING/PONG dua arah dan menghitung packet loss tiap
    arah secara terpisah.
  + Membuktikan pengaruh channel dan PAN ID terhadap keterhubungan dengan
    mengubahnya dan mengamati akibatnya.
  + Membuktikan bahwa penyaringan PAN ID dan alamat tujuan hanya aktif bila
    promiscuous mode dimatikan dengan `esp_ieee802154_set_promiscuous(false)`.
]

*Kriteria keberhasilan*

#checklist((
  [Setiap `PING n` dibalas `PONG n` pada jarak dekat, isi payload utuh (bukan
   karakter acak).],
  [Komunikasi terbukti berhenti saat channel salah satu node dibedakan.],
  [PAN ID berbeda terbukti tersaring hanya bila promiscuous mode dimatikan
   (EXP-05).],
  [Loss tiap arah terukur terpisah (PING hilang dibanding PONG hilang).],
  [Dump frame heksadesimal dianalisis dan tiap field ditunjuk.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam
(modulasi O-QPSK, CSMA-CA, superframe, beacon) berada di buku teori terpisah.
Istilah kerja dirangkum pada @tbl:m07-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [IEEE 802.15.4], [Standar PHY/MAC nirkabel low-rate low-power; basis Zigbee dan Thread.],
    [Channel], [Frekuensi kerja radio (di sini 15); kedua node harus sama.],
    [PAN ID], [Identitas jaringan (`0xCAFE`); frame di luar PAN disaring hardware --- *hanya bila promiscuous mode dimatikan*.],
    [Promiscuous mode], [Mode "dengar semua": filter PAN ID dan alamat tujuan di MAC dimatikan, setiap frame dengan FCS valid diteruskan ke callback. Driver ESP-IDF menyalakannya *secara default*, sehingga kode memanggil `esp_ieee802154_set_promiscuous(false)` di `setup()`.],
    [Short address], [Alamat 16-bit node (`0x0001` atau `0x0002`).],
    [Frame / MHR], [Header MAC `[Len][FC(2)][Seq(1)][DestPAN(2)][DestAddr(2)][SrcPAN(2)][SrcAddr(2)][payload]`.],
    [FCS], [Checksum 2 byte; *isinya* dihitung hardware, tetapi *panjangnya tetap ikut* pada byte `Len`.],
    [RX when idle], [Radio kembali ke RX setiap selesai TX atau RX --- bukan pengganti `esp_ieee802154_receive()`.],
    [ISR], [`esp_ieee802154_receive_done()` berjalan di konteks interupsi: salin data, set flag, jangan mencetak.],
  ),
  [Istilah kerja Modul 07],
  "tbl:m07-istilah",
)

*Tiga jebakan API `esp_ieee802154_*`.* Ketiganya nyata dan ditemukan saat modul
ini diuji di perangkat. Kode yang disediakan sudah memperhitungkannya --- yang
dituntut di sini adalah kemampuan menjelaskan gejalanya (@tbl:m07-jebakan).

#tbl(
  table(
    columns: (1.1fr, 1.2fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Aturan], th[Gejala bila dilanggar]),
    [`Len` = MHR + payload + 2 (FCS)], [Frame ditolak atau payload terpotong di penerima],
    [`esp_ieee802154_receive()` wajib dipanggil di `setup()`],
    [TX jalan, tetapi tidak ada satu pun frame diterima],
    [Buffer TX harus tetap hidup sampai transmisi selesai (`static`, bukan variabel lokal)],
    [Payload sesekali berubah menjadi sampah atau isi RAM lama],
  ),
  [Tiga aturan API `esp_ieee802154_*` dan gejala pelanggarannya],
  "tbl:m07-jebakan",
)

Aturan ketiga paling menipu: `esp_ieee802154_transmit()` bersifat *asinkron*
dan hanya menyimpan _pointer_ ke buffer. Bila buffer dideklarasikan sebagai
variabel lokal di `loop()`, isinya sudah tertimpa stack frame lain saat radio
benar-benar mengirim --- sebagian frame berangkat berisi sampah, sebagian lain
kebetulan masih utuh. Itulah mengapa gejalanya _intermiten_, bukan gagal total.

*Catatan --- filter PAN tidak aktif dengan sendirinya.*
`esp_ieee802154_set_panid()` dan `esp_ieee802154_set_short_address()` hanya
mengisi register; nilai itu baru dipakai untuk menyaring bila promiscuous mode
mati. Karena driver ESP-IDF menyalakan promiscuous secara default, tanpa
`esp_ieee802154_set_promiscuous(false)` dua node dengan PAN ID berbeda tetap
bisa saling bertukar pesan, dan node lain ikut menerima unicast yang bukan
untuknya. Perilaku ini berbeda dengan XBee, yang firmware-nya selalu menyaring
PAN ID dan alamat tujuan. Pengaruh baris ini dibuktikan pada EXP-05.

*Sekuens protokol yang diamati*

#diagram(```
 buildFrame()                       radio 802.15.4
 [Len][FC][Seq][DPAN][DA][SPAN][SA][payload]
        │                                   │
        ▼                                   ▼
  esp_ieee802154_transmit() ─► udara ─► esp_ieee802154_receive_done() (ISR)
                                            │
                              flag hasRx ──► loop(): cetak "RX dari ..."
```.text)

== Topologi

#diagram(```
        BOARD #1                              BOARD #2
+----------------------+                      +----------------------+
|      ESP32-H2        |  PING n  / 2 s       |      ESP32-H2        |
| Node1 (0x0001)       | ------------------>  | Node2 (0x0002)       |
| pengirim + penerima  |                      | penerima + balasan   |
| balasan PONG         | <------------------  | (PONG n)             |
+----------------------+      PONG n          +----------------------+
      env: node1                                    env: node2
        Channel 15, PAN ID 0xCAFE (kedua node sama)
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, auto, 1.2fr),
    align: (left, left, left, left, left),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Short addr], th[Aksi]),
    [Node1], [ESP32-H2 DevKitM-1], [`node1`], [`0x0001`],
    [TX `PING n` tiap 2 s, RX balasan],
    [Node2], [ESP32-H2 DevKitM-1], [`node2`], [`0x0002`],
    [RX `PING n`, TX `PONG n`],
  ),
  [Peran tiap node Modul 07],
  "tbl:m07-topologi",
)

Radio 802.15.4 dipakai *telanjang* (tanpa Zigbee atau Thread) di dua *ESP32-H2
DevKitM-1*. ESP32-C6 juga punya radio 802.15.4 dan bisa dipakai, tetapi lab ini
menyimpannya untuk peran gateway Wi-Fi di Modul 13.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan API ESP-IDF
`esp_ieee802154.h`.

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
    [4], [Platform PlatformIO], [pioarduino `espressif32` 55.03.311 (API `esp_ieee802154.h` bawaan)], [---],
  ),
  [Alat dan bahan Modul 07],
  "tbl:m07-alat",
)

Tidak ada library eksternal --- modul ini memanggil API ESP-IDF langsung.

*Radio config*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Nilai]),
    [Channel], [15],
    [PAN ID], [`0xCAFE`],
    [Short address], [Node1 `0x0001`, Node2 `0x0002`],
    [Interval PING], [2000 ms],
  ),
  [Konfigurasi radio Modul 07],
  "tbl:m07-radio",
)

== Kode Program

#sumber-kode("week07_802154_p2p",
  ("platformio.ini", "src/node1/main.cpp", "src/node2/main.cpp",
   "src/node3/main.cpp"))

*Pin port agar tidak salah flash* (@lst:m07-ini-readme).

#kode(```ini
[env:node1]
build_src_filter = +<node1/*.cpp>
upload_port  = /dev/ttyACM0
monitor_port = /dev/ttyACM0

[env:node2]
build_src_filter = +<node2/*.cpp>
upload_port  = /dev/ttyACM2
monitor_port = /dev/ttyACM2

[env:node3]
build_src_filter = +<node3/*.cpp>
; port diisi sesuai board ketiga (opsional, untuk EXP-04-e broadcast)
```.text,
  [Potongan `platformio.ini` dengan port yang dipin per environment],
  "lst:m07-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week07_802154_p2p/platformio.ini",
  [`platformio.ini` Modul 07 pada repositori],
  "lst:m07-ini",
)

#kode-berkas("week07_802154_p2p/src/node1/main.cpp",
  [`src/node1/main.cpp` --- pengirim PING `0x0001`],
  "lst:m07-node1",
  pecah: true,
)

#kode-berkas("week07_802154_p2p/src/node2/main.cpp",
  [`src/node2/main.cpp` --- penerima dan pembalas PONG `0x0002`],
  "lst:m07-node2",
  pecah: true,
)

Berkas `src/node3/main.cpp` (@lst:m07-node3) adalah node ketiga bershort
address `0x0003` yang dipakai pada uji broadcast EXP-04-e.

#kode-berkas("week07_802154_p2p/src/node3/main.cpp",
  [`src/node3/main.cpp` --- node ketiga `0x0003` untuk uji broadcast],
  "lst:m07-node3",
  pecah: true,
)

== Build dan Flash

#keluaran("pio device list
pio run -d week07_802154_p2p -e node1 -t upload
pio run -d week07_802154_p2p -e node2 -t upload -t monitor")

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
  [Dua ESP32-H2 terpasang dan terdeteksi.],
  [Environment `node1` dan `node2` dikenali PlatformIO.],
  [Serial Monitor 115200 baud untuk kedua node.],
  [Tidak ada firmware Zigbee atau Thread yang masih berjalan di board yang
   sama (radio 802.15.4 dipakai langsung).],
))

== Percobaan

=== EXP-01 --- Konfigurasi Radio dan Anatomi Frame

Unggah kedua firmware, verifikasi konfigurasi radio pada baris pertama Serial
Monitor, lalu telusuri fungsi `buildFrame()`.

#diagram(```
 frame[0]=Len | [1..2]=FC 0x8801 | [3]=Seq | [4..5]=PAN 0xCAFE
 [6..7]=DestAddr | [8..9]=PAN | [10..11]=SrcAddr | [12..]=payload

 Len = 11 (MHR) + panjang payload + 2 (FCS)
```.text)

Contoh frame `PING 38` yang benar-benar tertangkap di udara (dump
`receive_done` pada ESP32-H2; dua byte terakhir adalah RSSI dan LQI yang
menggantikan FCS saat penerimaan).

#diagram(```
14 01 88 00 FE CA 02 00 FE CA 01 00 50 49 4E 47 20 33 38 E5 0A
│  │     │  │     │     │     │     "P  I  N  G  _  3  8" │  │
│  FC    │  PAN   Dest  PAN   Src                        │  LQI
Len=0x14 Seq      0x0002      0x0001                     RSSI
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Channel], [#isian],
    [PAN ID], [#isian],
    [Short address Node1], [#isian],
    [Short address Node2], [#isian],
    [Ukuran MHR (byte)], [#isian],
    [`Len` untuk payload 7 karakter], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m07-exp01",
)

#buka-abstraksi[
  Hitung sendiri nilai `Len` untuk payload `"PING 38"` (7 karakter) dan
  cocokkan dengan `0x14` pada dump di atas. Lalu jawab: jika FCS dihitung
  hardware, mengapa panjangnya tetap harus disertakan? Petunjuk: `Len` adalah
  field PHY, dan PHY menghitung *semua* byte yang mengudara.
]

#checkpoint[
  Kedua node mencetak baris `Channel 15, PAN 0xCAFE, short addr 0x000X` dengan
  nilai yang berbeda untuk tiap node. Jika keduanya mencetak alamat yang sama,
  berarti terjadi kesalahan flash --- periksa `upload_port`.
]

=== EXP-02 --- Pertukaran PING dan PONG

Node1 mengirim `PING n` tiap 2 s; Node2 menerima (callback
`esp_ieee802154_receive_done` menyalin payload dan menyetel flag, `loop()`
mencetak), lalu membalas `PONG n`; Node1 menerima balasan itu.

#diagram(```
 Node1 loop (tiap 2 s)             Node2 receive_done
 TX "PING n" ─────────────────►  RX dari 0x0001: PING n
 RX dari 0x0002: PONG n  ◄──────  TX balasan "PONG n"
```.text)

*Expected output --- Node1*

#keluaran("Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0x0002: PING 1
RX dari 0x0002: PONG 1
TX ke 0x0002: PING 2
RX dari 0x0002: PONG 2")

*Expected output --- Node2*

#keluaran("Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0002
RX dari 0x0001: PING 1
TX balasan ke 0x0001: PONG 1")

#checkpoint[
  Isi payload harus *terbaca sebagai teks*, bukan karakter acak. Jika muncul
  sampah tak terbaca, itu gejala buffer TX bukan `static` (lihat bagian Dasar
  Teori). Jika Node2 hanya mencetak baris konfigurasi dan tidak pernah `RX`,
  `esp_ieee802154_receive()` tidak dipanggil. Perbaiki dulu, jangan lanjut
  mengukur.
]

=== EXP-03 --- Isolasi Channel dan RTT

+ Ubah jarak antar node secara bertahap.
+ Ubah `CHANNEL` pada *salah satu* node (perlu unggah ulang) sehingga berbeda,
  lalu verifikasi komunikasi berhenti total.
+ Kembalikan ke channel yang sama, lalu ubah `PAN_ID` salah satu node --- amati
  apakah gejalanya sama atau berbeda dengan kasus channel.
+ Ukur round-trip kasar PING ke PONG dari waktu di Serial Monitor.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Perilaku saat channel berbeda], [#isian],
    [Perilaku saat PAN ID berbeda], [#isian],
    [Round-trip PING ke PONG (kasar)], [#isian],
    [Interval kirim PING (s)], [#isian],
    [Pesan per menit yang dibalas], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m07-exp03",
)

#checkpoint[
  Praktikan dapat menjelaskan *perbedaan* antara gagal karena channel dan gagal
  karena PAN ID (petunjuk: yang satu radio tidak mendengar sama sekali, yang
  satu mendengar tetapi menyaring). Ini penting untuk memahami penyaringan
  Zigbee dan Thread di modul berikutnya.
]

=== EXP-04 --- Efek Parameter: PAN ID, Channel, Broadcast

Semua efek di bawah cukup dicapai dengan *mengubah `#define` di
`src/nodeX/main.cpp`* --- tidak ada logika yang diubah. Tiap ubah parameter,
unggah ulang node yang bersangkutan.

#tbl(
  table(
    columns: (auto, auto, auto, 1.6fr),
    align: (left, left, left, left),
    inset: (x: 0.45em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Uji], th[`node1`], th[`node2`], th[Gejala yang harus terlihat]),
    [04-a PAN sama], [`PAN_ID 0xCAFE`], [`PAN_ID 0xCAFE`],
    [PING--PONG normal (baseline)],
    [04-b PAN beda], [`PAN_ID 0xCAFE`], [`PAN_ID 0xBEEF`],
    [Node1 tetap cetak `TX`, Node2 *tidak pernah* cetak `RX` --- frame _heard but filtered_ (disaring hardware MAC)],
    [04-c Channel sama], [`CHANNEL 15`], [`CHANNEL 15`], [PING--PONG normal],
    [04-d Channel beda], [`CHANNEL 15`], [`CHANNEL 20`],
    [Kedua node sunyi di sisi RX --- radio _never heard_ (tuli, tidak mendengar sama sekali)],
    [04-e Broadcast], [`PEER_ADDR 0xFFFF`], [`PEER_ADDR` apa pun],
    [Node2 *dan* Node3 (bila ada) menerima frame yang sama],
  ),
  [Matriks uji efek parameter EXP-04],
  "tbl:m07-exp04",
)

Perbedaan 04-b dengan 04-d adalah inti yang harus bisa dijelaskan.

/ PAN ID beda (04-b): radio memang menerima transmisi di channel yang sama,
  tetapi MAC hardware *menyaring frame* dengan PAN ID asing sebelum sampai ke
  callback (berlaku karena `setup()` mematikan promiscuous mode; lihat EXP-05). TX di sisi
  lain tetap berjalan normal --- komunikasi terlihat "searah hilang".

/ Channel beda (04-d): radio tidak berada di frekuensi yang sama, sehingga
  tidak ada yang diterima secara fisik. Tidak ada filter yang "menolak" karena
  memang tidak ada yang masuk.

*Uji broadcast (04-e) --- wajib 3 node.* Firmware node ketiga sudah tersedia
pada `src/node3` (@lst:m07-node3) dengan `MY_ADDR` `0x0003`; tambahkan
`[env:node3]` di `platformio.ini`, lalu set `PEER_ADDR` Node1 menjadi `0xFFFF`.
Amati bahwa Node2 dan Node3 menerima frame yang sama, lalu diskusikan apa yang
hilang dibanding unicast (tidak ada ACK, tidak ada penyaringan alamat tujuan).

*Data capture --- tabel gejala lintas kelompok*

#tbl(
  table(
    columns: (auto, 1fr, auto, auto, auto, 1.2fr),
    align: (left, left, left, left, left, left),
    inset: (x: 0.35em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Uji], th[Konfigurasi], th[TX Node1?], th[RX Node2?],
      th[Loss], th[Gejala yang diamati],
    ),
    [04-a], [PAN sama], [#isian], [], [], [],
    [04-b], [PAN beda], [#isian], [], [], [],
    [04-c], [Channel sama], [#isian], [], [], [],
    [04-d], [Channel beda], [#isian], [], [], [],
    [04-e], [Broadcast (3 node)], [#isian], [], [], [],
  ),
  [Lembar pengamatan EXP-04],
  "tbl:m07-exp04-capture",
)

#checkpoint[
  Praktikan dapat membedakan 04-b dari 04-d tanpa melihat kode, hanya dari pola
  log: 04-b ada TX tanpa RX di pasangan; 04-d kedua sisi sunyi. Jika sebuah
  kelompok di ruangan sama menyalakan radio 802.15.4 di channel yang sama,
  gejala yang muncul mirip 04-b --- itu sebabnya tiap kelompok wajib memakai
  channel berbeda.
]

=== EXP-05 --- Promiscuous Mode: Ada dan Tidaknya Filter MAC

EXP-04 menunjukkan bahwa node dengan PAN ID berbeda tidak saling menerima.
Penyaringan itu *tidak* terjadi dengan sendirinya: driver ESP-IDF menyalakan
promiscuous mode secara default, dan filter PAN ID serta alamat tujuan baru
aktif karena `setup()` memanggil satu baris berikut sebelum
`esp_ieee802154_set_rx_when_idle(true)`:

```cpp
esp_ieee802154_set_promiscuous(false);  // aktifkan filter PAN ID & alamat di hardware (default driver: true)
```

Percobaan ini membuktikan pengaruh baris tersebut. Seperti EXP-04, yang diubah
hanya satu baris di `setup()`; tiap perubahan diikuti unggah ulang node yang
bersangkutan. Channel semua node tetap 15.

#tbl(
  table(
    columns: (auto, auto, 1.1fr, 1.6fr),
    align: (left, left, left, left),
    inset: (x: 0.45em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Uji], th[PAN (Node1 / Node2)], th[Baris promiscuous], th[Gejala yang harus terlihat]),
    [05-a], [`0xCAFE` / `0xBEEF`], [`false` di semua node (kode asli)],
    [Node1 tetap cetak `TX`, Node2 *tidak pernah* cetak `RX` --- sama dengan 04-b],
    [05-b], [`0xCAFE` / `0xBEEF`], [Node2: `true`],
    [Node2 cetak `RX` untuk setiap PING dan membalas PONG, tetapi Node1 *tidak pernah* cetak `RX`],
    [05-c], [`0xCAFE` / `0xBEEF`], [Node2: baris *dihapus*],
    [Sama dengan 05-b --- tanpa baris ini driver memakai nilai default `true`],
    [05-d], [`0xCAFE` / `0xCAFE`], [Node3: `true` (Node1, Node2: `false`)],
    [PING--PONG Node1--Node2 tetap jalan, tetapi Node3 *ikut* cetak `RX` untuk unicast yang bukan untuknya dan membalasnya; Node1 menerima PONG *ganda*],
  ),
  [Matriks uji promiscuous mode EXP-05],
  "tbl:m07-exp05",
)

Ada tiga hal yang harus bisa dijelaskan dari percobaan ini.

/ Filter bekerja di hardware (05-a vs 05-b): kode callback
  `esp_ieee802154_receive_done()` tidak pernah memeriksa header, sehingga
  satu-satunya yang membedakan 05-a dan 05-b adalah filter MAC. Begitu
  promiscuous dinyalakan, PING dari PAN asing langsung sampai ke callback.

/ Penyaringan terjadi di sisi penerima (05-b): PONG dari Node2 membawa Dest
  PAN `0xBEEF`, sementara Node1 masih memakai `false` sehingga PONG itu
  dibuang. Komunikasi hanya "tembus" ke arah node yang promiscuous.

/ Filter alamat tujuan ikut mati (05-d): promiscuous tidak hanya mengabaikan
  PAN ID, tetapi juga alamat tujuan. Node3 menerima PING yang ditujukan ke
  `0x0002` *dan* PONG yang ditujukan ke `0x0001` --- keduanya bukan untuknya,
  padahal Node1 tidak mengirim ke `0xFFFF`. Karena buffer penerima hanya satu
  slot dan PONG datang beberapa milidetik setelah PING, yang tercetak di Node3
  biasanya `RX ... PONG n` (PING tertimpa). Node3 lalu membalas ke Node1,
  sehingga Node1 mencetak dua PONG untuk satu PING. Perhatikan bahwa label
  "`RX dari 0x0002`" di log adalah konstanta `PEER_ADDR`, bukan alamat asal
  frame yang sebenarnya.

Bandingkan dengan XBee: firmware XBee selalu menyaring PAN ID dan alamat
tujuan, sehingga perilakunya setara dengan 05-a tanpa perlu diatur. Pada
ESP32-H2 yang memakai radio 802.15.4 secara langsung, filter itu harus
dinyalakan sendiri.

*Peringatan.* Jangan menyalakan promiscuous pada Node2 *dan* Node3
bersamaan. Kedua node akan saling menerima dan membalas setiap PONG, sehingga
terjadi _reply storm_: Serial Monitor dibanjiri puluhan `RX`/`TX` per detik
untuk nomor PONG yang sama. Ubah satu node saja pada tiap uji, dan kembalikan
semua node ke `false` dan `PAN_ID 0xCAFE` setelah selesai.

*Data capture*

#tbl(
  table(
    columns: (auto, 1fr, auto, auto, auto, 1.2fr),
    align: (left, left, left, left, left, left),
    inset: (x: 0.35em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Uji], th[Konfigurasi], th[RX Node1?], th[RX Node2?],
      th[RX Node3?], th[Gejala yang diamati],
    ),
    [05-a], [PAN beda, `false`], [#isian], [], [], [],
    [05-b], [PAN beda, Node2 `true`], [#isian], [], [], [],
    [05-c], [PAN beda, Node2 tanpa baris], [#isian], [], [], [],
    [05-d], [PAN sama, Node3 `true`], [#isian], [], [], [],
  ),
  [Lembar pengamatan EXP-05],
  "tbl:m07-exp05-capture",
)

#checkpoint[
  Praktikan dapat menjelaskan mengapa 05-b menghasilkan komunikasi *satu arah*
  (Node2 menerima PING, Node1 tidak menerima PONG), dan mengapa 05-c sama
  dengan 05-b. Jawaban yang benar menyebut bahwa `esp_ieee802154_set_panid()`
  hanya mengisi register, sedangkan penyaringan baru aktif bila promiscuous
  dimatikan. Praktikan juga dapat menjelaskan mengapa Node1 menerima PONG ganda
  pada 05-d.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 2 × *ESP32-H2 DevKitM-1*, capture 25 detik.

#keluaran("# Node1 (ESP32-H2, env node1)          # Node2 (ESP32-H2, env node2)
[0.201] Channel 15, PAN 0xCAFE, 0x0001 [0.201] Channel 15, PAN 0xCAFE, 0x0002
[2.204] TX ke 0x0002: PING 1           [2.205] RX dari 0x0001: PING 1
[2.204] RX dari 0x0002: PONG 1         [2.205] TX balasan ke 0x0001: PONG 1
[4.208] TX ke 0x0002: PING 2           [4.209] RX dari 0x0001: PING 2")

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [PING dikirim / diterima Node2], [12 / 12],
    [PONG dikirim / diterima Node1], [12 / 12],
    [Round-trip PING ke PONG], [< 1 ms (di bawah resolusi cetak Serial)],
  ),
  [Hasil verifikasi hardware Modul 07],
  "tbl:m07-verifikasi",
)


// Log serial lengkap dari week07_802154_p2p/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, 1fr, auto, auto),
      align: (left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Peran], th[short addr], th[Port serial (UART)]),
      [Node1], [Sender (kirim PING)], [`0x0001`], [`/dev/ttyACM0`],
      [Node2], [Receiver (balas PONG)], [`0x0002`], [`/dev/ttyACM2`],
    ),
    [Board dan port pada rekaman log serial Modul 07],
    "tbl:m07-log-1",
  )

  Channel 15, PAN ID `0xCAFE`.

  *Node1 — `/dev/ttyACM0`*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0x0002: PING 1
RX dari 0x0002: PONG 1
TX ke 0x0002: PING 2
RX dari 0x0002: PONG 2
TX ke 0x0002: PING 3
RX dari 0x0002: PONG 3
TX ke 0x0002: PING 4
RX dari 0x0002: PONG 4
TX ke 0x0002: PING 5
RX dari 0x0002: PONG 5
TX ke 0x0002: PING 6
RX dari 0x0002: PONG 6
TX ke 0x0002: PING 7
RX dari 0x0002: PONG 7
TX ke 0x0002: PING 8
RX dari 0x0002: PONG 8", pecah: true)

  *Node2 — `/dev/ttyACM2`*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xd (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0002
RX dari 0x0001: PING 1
TX balasan ke 0x0001: PONG 1
RX dari 0x0001: PING 2
TX balasan ke 0x0001: PONG 2
RX dari 0x0001: PING 3
TX balasan ke 0x0001: PONG 3
RX dari 0x0001: PING 4
TX balasan ke 0x0001: PONG 4
RX dari 0x0001: PING 5
TX balasan ke 0x0001: PONG 5
RX dari 0x0001: PING 6
TX balasan ke 0x0001: PONG 6
RX dari 0x0001: PING 7
TX balasan ke 0x0001: PONG 7
RX dari 0x0001: PING 8
TX balasan ke 0x0001: PONG 8", pecah: true)

  *Catatan*

  - Node1 mengirim frame 802.15.4 (raw, tanpa stack Zigbee/Thread) berisi `PING n` tiap 2 detik ke short address `0x0002`.
  - Node2 menerima, lalu membalas `PONG n` ke `0x0001`.
  - FCS dihitung otomatis oleh hardware; pada sisi RX dua byte FCS diganti RSSI+LQI.
  - Komunikasi dua arah terbukti dari sisi Node1 (`RX dari 0x0002: PONG n`) dan sisi Node2 (`RX dari 0x0001: PING n`).
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

#tbl(
  table(
    columns: (auto, 1fr, 1.2fr, 1.1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak], th[RSSI (dBm)], th[Latency RTT (kasar)], th[Success PONG (%)],
    ),
    [1 m], [#isian], [], [],
    [3 m], [#isian], [], [],
    [5 m], [#isian], [], [],
    [10 m], [#isian], [], [],
    [15 m], [#isian], [], [],
  ),
  [Lembar pengukuran jarak Modul 07],
  "tbl:m07-ukur",
)

*Pengukuran per-node* (pengamatan 2 menit) --- pisahkan dua arah.

#tbl(
  table(
    columns: (1.2fr, 1fr, 1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[TX], th[RX], th[Loss (%)]),
    [Node1 (`0x0001`)], [#isian], [], [],
    [Node2 (`0x0002`)], [#isian], [], [],
  ),
  [Lembar pengukuran per-node Modul 07],
  "tbl:m07-pernode",
)

RSSI dapat dibaca dari `frame_info->rssi` di dalam `receive_done` --- salin ke
variabel, cetak di `loop()`, jangan mencetak di ISR.

*Baseline untuk M16.* Catat jarak maksimum yang masih 100 % berhasil pada modul
ini. Angka itu adalah jangkauan radio 802.15.4 *tanpa* bantuan mesh ---
pembanding langsung untuk Zigbee (M10) dan Thread (M12).

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Bagaimana pengaruh jarak terhadap RSSI dan persentase PING yang dibalas PONG?
+ Pada jarak berapa komunikasi mulai gagal, dan apa indikasinya di Serial
  Monitor?
+ Apakah round-trip latency bertambah signifikan dengan jarak? Mengapa?
+ Berapa packet loss tiap arah (PING hilang dibanding PONG hilang)? Adakah
  asimetri, dan apa dugaan penyebabnya?
+ Mengapa channel dan PAN ID harus sama, dan apa hubungan 802.15.4 dengan
  Zigbee pada modul berikutnya?

== Concept Check

+ Apa fungsi field Frame Control dan sequence number pada frame 802.15.4?
+ Apa perbedaan short address dan extended address, dan kapan masing-masing
  dipakai?
+ Mengapa FCS tidak perlu dihitung di perangkat lunak, tetapi panjangnya tetap
  harus dihitung?
+ Mengapa callback penerimaan tidak boleh mencetak langsung ke Serial (konteks
  ISR)?
+ Apa yang terjadi bila dua node memakai PAN ID berbeda --- di lapisan mana
  penyaringan itu terjadi?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Sequence number dan ukuran payload])[
  / CH-1 --- Sequence number nyata (wajib): Field `frame[3]` saat ini selalu
    `0`. Isi dengan nomor urut yang naik tiap kirim seperti @lst:m07-ch1, lalu
    hitung packet loss dari sisi penerima. Contoh: 60 PING dikirim, 57 PONG
    diterima, sehingga loss = (60 − 57)/60 × 100 % = 5 %.

  / CH-2 --- Pengaruh ukuran payload: Perbesar payload menjadi 40 byte teks dan
    bandingkan success rate terhadap payload pendek pada jarak yang sama.
    Jelaskan hasilnya dari sisi peluang bit error per frame.
]

#kode(```cpp
// buildFrame(): ganti frame[3] = 0;
static uint8_t seq = 0;
frame[3] = seq++;
```.text,
  [Kerangka CH-1 --- sequence number pada MHR],
  "lst:m07-ch1",
)

#tujuan-prak(3, [RSSI sendiri dan broadcast])[
  / CH-3 --- RSSI dari frame sendiri: Salin `frame_info->rssi` dan
    `frame_info->lqi` di ISR, cetak di `loop()`, lalu isi kolom RSSI bagian
    Pengukuran dari data node sendiri (bukan aplikasi luar).

  / CH-4 --- Broadcast: Ubah `DestAddr` menjadi `0xFFFF` (broadcast) dan
    tambahkan node ketiga. Amati apakah kedua penerima menerima frame yang
    sama, dan diskusikan apa yang hilang (tidak ada ACK, tidak ada penyaringan
    alamat).
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (802.15.4, MHR, channel, PAN ID, short address, tiga
  aturan API).
+ Konfigurasi --- environment `node1` dan `node2`, channel 15, PAN `0xCAFE`,
  interval 2 s.
+ Hasil eksperimen --- log PING--PONG kedua node beserta analisis dump frame
  heksadesimal.
+ Data pengukuran --- tabel jarak, tabel per-node, dan baseline jangkauan untuk
  M16.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-3.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
