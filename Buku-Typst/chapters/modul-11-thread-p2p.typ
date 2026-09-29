// ============================================================================
// Modul 11 — Thread: Datagram UDP di atas IPv6
// Sumber: week11_thread_p2p/README.md; listing kode dibaca langsung dari
//         assets/code/week11_thread_p2p/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 11 — Thread: Datagram UDP di atas IPv6", l: "bab:modul-11")

#identitas-modul(
  "Modul 11",
  [Speak IPv6 over Thread --- Datagram UDP di atas IPv6],
  [ESP32-H2 · Thread · UDP/IPv6 · level Intermediate · 3 × 50 menit ·
   folder kode `week11_thread_p2p`],
)

#pengantar([Gambaran Umum])[
Modul 11 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya memberi tiap node alamat IPv6 sungguhan dan mengirim datagram UDP di
antara keduanya. Percobaan berjalan sebagai pertukaran P2P berbasis IPv6,
dengan PING dikirim secara multicast dan PONG dibalas secara unicast, diamati
melalui dua terminal Serial Monitor pada 115200 baud.
]

== Pendahuluan

Zigbee memakai alamat 16-bit milik jaringannya sendiri; untuk keluar ke
Internet ia butuh penerjemah. Thread memakai *IPv6* --- alamat yang bentuknya
sama dengan alamat Internet --- di atas radio 802.15.4 yang sama persis dengan
M07--M10. Inilah alasan Thread bisa disambungkan ke Wi-Fi di M13 hampir tanpa
penerjemahan: paketnya sudah IP sejak dari node sensor.

Prasyaratnya ada dua: M07 untuk channel, PAN ID, dan radio 802.15.4; serta
M08--M10 untuk pengalaman menghadapi jaringan yang mengelola dirinya sendiri.
Yang dibangun di sini adalah Active Dataset Thread, mesh-local prefix beserta
EID, proses attach role secara otomatis, socket UDP IPv6, dan perbedaan
multicast realm-local dengan unicast. Semuanya dipakai lagi pada M12 untuk mesh
many-to-many, M13 ketika dataset yang sama dipakai gateway C6, M15 ketika
payload UDP ini berakhir di MQTT, dan M16 ketika Thread dibandingkan dengan BLE
dan Zigbee.

*Peta modul blok Thread*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [07], [802.15.4 telanjang],
    [08--10], [Zigbee: alamat 16-bit, join dan binding, mesh],
    [*11 (ini)*], [*Thread: tiap node punya alamat IPv6, datagram UDP*],
    [12], [Mesh Thread many-to-many, role election],
    [13], [Thread disambungkan ke Wi-Fi lewat gateway C6],
  ),
  [Peta modul blok Thread],
  "tbl:m11-peta",
)

*Kontrak data lab ini.* Grup multicast `ff03::abcd` dan port *5050* dipakai
sama persis di M11, M12, M13, dan M15. Karena itu firmware penerima modul mana
pun bisa dijadikan alat bantu diagnosis untuk modul lainnya --- teknik yang
benar-benar dipakai saat menguji M13 tanpa board C6.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membentuk jaringan Thread dan mengirim datagram UDP IPv6])[
  + Menyusun Active Dataset Thread lengkap (nama, channel, PAN ID, ext PAN ID,
    network key, mesh-local prefix) dan menjelaskan mengapa keenam parameter
    harus identik di semua node.
  + Membentuk jaringan Thread dua node dan menunjukkan mesh-local EID
    masing-masing beserta *awalan yang sama*.
  + Mengirim datagram UDP IPv6 multicast dan membalasnya unicast, dibuktikan
    dari alamat sumber yang tercetak di log.
  + Mengukur latency PING ke PONG dan packet loss pada minimal 4 jarak, serta
    menjelaskan gejala khas bila prefix mesh-local berbeda.
]

*Kriteria keberhasilan*

#checklist((
  [Kedua node attach (satu Leader, satu Child) dan mencetak mesh-local EID
   dengan *awalan yang sama*.],
  [PING multicast dibalas PONG unicast secara periodik.],
  [Latency PING ke PONG rata-rata dihitung dari sekurangnya 10 sampel.],
  [Tabel jarak--RSSI--latency--loss terisi dari pengukuran sendiri.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (MLE,
Router ID assignment, MPL forwarding, keamanan DTLS atau commissioning) berada
di buku teori terpisah. Istilah kerja dirangkum pada @tbl:m11-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Thread], [Protokol jaringan mesh berbasis IPv6 di atas IEEE 802.15.4.],
    [Leader], [Node yang mengelola router ID dan dataset jaringan; terpilih otomatis.],
    [Child], [Node yang attach ke parent (Leader atau Router) untuk berkomunikasi.],
    [Active Dataset], [Parameter jaringan --- nama `ESP_OT_P2P`, channel 15, PAN ID `0xABCD`, ext PAN ID `DE:AD:00:BE:EF:00:CA:FE`, network key 16 byte, *mesh-local prefix `fdde:ad00:beef::/64`*.],
    [Mesh-Local prefix], [Prefix `/64` milik seluruh jaringan; semua alamat mesh-local diturunkan darinya. Harus *sama persis* di setiap node.],
    [Mesh-Local EID], [Alamat IPv6 mesh-local tiap node (`fdde:ad00:beef:0:...`), dicetak via `getMeshLocalEid()`.],
    [Link-local (`fe80::`)], [Alamat per-interface untuk komunikasi 1 hop antar tetangga.],
    [Multicast `ff03::abcd`], [Realm-local: diteruskan ke seluruh mesh, bukan hanya tetangga langsung.],
    ["ping"], [Di lab ini diwakili pola PING/PONG aplikasi di atas UDP, bukan ICMPv6 echo.],
  ),
  [Istilah kerja Modul 11],
  "tbl:m11-istilah",
)

*Mengapa dataset di-commit ulang tiap boot.* `DataSet::initNew()` memanggil
`otDatasetCreateNewNetwork()`, yang *mengacak* network key, ext PAN ID, dan
mesh-local prefix. Kode modul ini menimpa empat field pertama dengan konstanta,
lalu memaksa prefix mesh-local lewat `otThreadSetMeshLocalPrefix()` sebelum
`OThread.start()` seperti @lst:m11-prefix.

#kode(```cpp
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] =
    {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};   // fdde:ad00:beef::/64
```.text,
  [Konstanta mesh-local prefix yang dipaksakan di setiap node],
  "lst:m11-prefix",
)

Tanpa langkah itu tiap board memakai prefix acak sendiri. Gejalanya
menyesatkan: kedua node *tetap attach* (MLE hanya mencocokkan channel, PAN ID,
ext PAN ID, dan network key) dan Serial Monitor tampak normal, tetapi tidak
satu pun paket multicast `ff03::` sampai --- karena penerusan multicast
realm-local terikat pada prefix mesh-local jaringan. Cirinya: dua node dengan
awalan Mesh-Local EID berbeda, misalnya `fdcd:8b6:7a73:...` di satu sisi dan
`fd99:6dd0:2d68:...` di sisi lain.

*Alamat di Thread: di mana MY, SH, dan SL?* Setelah attach, tiap node mencetak
blok `Info network Thread:` (fungsi `printNetworkInfo()`). Isinya bisa dipetakan
ke parameter XBee dan Zigbee (Modul 08) seperti pada @tbl:m11-alamat.

#tbl(
  table(
    columns: (0.55fr, 0.95fr, 0.95fr, 2fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.4em),
    stroke: 0.5pt + luma(170),
    table.header(th[XBee], th[Zigbee (M08)], th[Thread], th[Catatan]),
    [*MY*], [`Short address`], [`RLOC16`], [Alamat 16-bit yang dibagikan jaringan. Di Thread nilainya menyandi *Router ID + Child ID*, jadi berubah bila peran atau parent berubah.],
    [*SH + SL*], [`IEEE address`], [`EUI-64`], [Alamat pabrik 64-bit, tetap, unik --- padanan nomor di label XBee.],
    [---], [(sama dengan IEEE)], [`Extended addr`], [Alamat MAC 64-bit yang *diacak* Thread demi privasi, jadi *tidak sama* dengan EUI-64.],
    [*CH*], [`Channel`], [`Channel`], [Di Thread diambil dari dataset yang ditulis kode (15), bukan dipilih jaringan.],
    [*OI*], [`PAN ID`], [`PAN ID`], [Dari dataset (`0xABCD`).],
    [*OP*], [`Extended PAN ID`], [`Extended PAN ID`], [Dari dataset (`DE:AD:00:BE:EF:00:CA:FE`).],
    [---], [---], [`Network name`], [Nama jaringan dari dataset (`ESP_OT_P2P`). XBee tidak punya padanannya (NI adalah nama _node_, bukan nama jaringan).],
    [---], [---], [`Mesh-Local EID`], [Alamat *IPv6* node di dalam mesh --- alamat yang muncul di baris `RX [...]` dan dipakai untuk unicast balik.],
  ),
  [Padanan alamat XBee, Zigbee, dan Thread],
  "tbl:m11-alamat",
)

Dua perbedaan yang paling penting: *(1)* parameter jaringan (channel, PAN ID,
Extended PAN ID, network name) di Thread *ditentukan dataset di kode*, sedangkan
di Zigbee dipilih coordinator; *(2)* aplikasi Thread berbicara dengan *alamat
IPv6* (Mesh-Local EID), bukan alamat 16-bit seperti DH/DL di XBee atau binding
di Zigbee.

*Membaca RLOC16.* 6 bit atas adalah Router ID, 9 bit bawah adalah Child ID.
Router/Leader punya Child ID 0 (mis. `0xE800` = Router ID 58); child memakai
Router ID parent-nya (mis. `0xE801` = child nomor 1 dari router `0xE800`). Jadi
dari RLOC16 saja terlihat siapa parent sebuah child.

*Sekuens protokol yang diamati*

#diagram(```
 Node2 (pengirim)                       Node1 (penjawab)
   │ ──── PING multicast ff03::abcd:5050 ────► │
   │ ◄─── PONG unicast ke mesh-local EID ───── │
```.text)

== Topologi

#diagram(```
       BOARD #1                                        BOARD #2
 +----------------+  PING (multicast ff03::abcd:5050)  +----------------+
 |    ESP32-H2    | <---------------------------------- |    ESP32-H2    |
 |     Node1      |                                     |     Node2      |
 | (penjawab)     |  PONG (unicast ke mesh-local EID)   | (pengirim)     |
 +----------------+ ---------------------------------> +----------------+
    env: node1                                             env: node2
        Thread: ESP_OT_P2P, channel 15, PAN 0xABCD,
                mesh-local prefix fdde:ad00:beef::/64
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, 1.2fr),
    align: (left, left, left, left, left),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Role Thread], th[Aksi]),
    [Node1], [ESP32-H2 DevKitM-1], [`node1`], [Leader *atau* Child (dinamis)],
    [bind multicast dan unicast, balas `PONG`],
    [Node2], [ESP32-H2 DevKitM-1], [`node2`], [Leader *atau* Child (dinamis)],
    [kirim `PING` multicast tiap 3 s],
  ),
  [Peran tiap node Modul 11],
  "tbl:m11-topologi",
)

Keduanya *ESP32-H2 DevKitM-1* (radio 802.15.4). ESP32-C6 baru masuk di Modul 13
saat Thread perlu disambungkan ke Wi-Fi.

#catatan[
  *Role Thread tidak ditentukan oleh nama environment.* Leader dipilih otomatis
  oleh stack --- biasanya board yang selesai boot lebih dulu. Pada uji
  referensi, `node2` justru menjadi Leader dan `node1` menjadi Child, dan
  PING/PONG tetap berjalan normal. Yang harus sama di kedua board adalah
  *dataset*, bukan role.
]

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
    [1], [Board ESP32-H2], [DevKitM-1 (env `node1`, penjawab PONG)], [1],
    [2], [Board ESP32-H2], [DevKitM-1 (env `node2`, pengirim PING)], [1],
    [3], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [4], [PC/Laptop], [PlatformIO Core/IDE, 2 port USB bebas], [1],
    [5], [Power bank atau catu daya USB], [untuk uji jarak], [2],
  ),
  [Alat dan bahan Modul 11],
  "tbl:m11-alat",
)

Tidak ada library eksternal --- `OThread` dan `OThreadUDP` bawaan Arduino
core 3.x.

*Parameter jaringan yang wajib identik*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Nilai]),
    [Network name], [`ESP_OT_P2P`],
    [Channel dan PAN ID], [15 dan `0xABCD`],
    [Ext PAN ID], [`DE:AD:00:BE:EF:00:CA:FE`],
    [Network key], [`00 11 22 … ee ff` (16 byte)],
    [Mesh-local prefix], [`fdde:ad00:beef::/64`],
    [Grup multicast dan port], [`ff03::abcd` : 5050],
  ),
  [Parameter jaringan Thread Modul 11],
  "tbl:m11-dataset",
)

== Kode Program

#sumber-kode("week11_thread_p2p",
  ("platformio.ini", "src/node1/main.cpp", "src/node2/main.cpp"))

#kode-berkas("week11_thread_p2p/platformio.ini",
  [`platformio.ini` Modul 11 pada repositori],
  "lst:m11-ini",
)

#kode-berkas("week11_thread_p2p/src/node1/main.cpp",
  [`src/node1/main.cpp` --- penjawab PONG],
  "lst:m11-node1",
  pecah: true,
)

#kode-berkas("week11_thread_p2p/src/node2/main.cpp",
  [`src/node2/main.cpp` --- pengirim PING multicast],
  "lst:m11-node2",
  pecah: true,
)

== Build dan Flash

#keluaran("pio run -d week11_thread_p2p -e node1 -t erase
pio run -d week11_thread_p2p -e node2 -t erase
pio run -d week11_thread_p2p -e node1 -t upload
pio run -d week11_thread_p2p -e node2 -t upload -t monitor")

*Pre-flight checklist*

#checklist((
  [`pio device list` dijalankan, dua port dicatat dan diisikan pada tiap env.],
  [Flash environment `node1` dan `node2` (role Leader atau Child dipilih
   otomatis oleh stack, bukan oleh nama environment).],
  [Mesh-local prefix di kedua firmware sama: `fdde:ad00:beef::/64`.],
  [*Hapus dataset lama* bila board pernah dipakai modul Thread lain:
   `pio run -e node1 -t erase`.],
  [Serial Monitor 115200 baud pada kedua board.],
  [Tabel pencatat jarak, RSSI, latency, dan loss siap.],
))

== Percobaan

=== EXP-01 --- Pembentukan Jaringan dan Attach

Nyalakan kedua board. Keduanya men-commit dataset identik (termasuk prefix
mesh-local), start Thread, dan menunggu role minimal CHILD. Board yang selesai
boot lebih dulu umumnya menjadi Leader --- urutannya boleh berbeda tiap
percobaan.

#diagram(```
 [board A] dataset (+ ML prefix) ──► start ──► Leader
 [board B] dataset (+ ML prefix) ──► start ──► scan ──► attach ──► Child
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1.1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Role Node1], [… (Leader atau Child)],
    [Role Node2], [… (Leader atau Child)],
    [Awalan Mesh-Local EID sama di kedua node?], [… (harus `fdde:ad00:beef:0:`)],
    [Mesh-Local EID Node1], [#isian],
    [Mesh-Local EID Node2], [#isian],
    [Waktu attach tiap node (detik)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m11-exp01",
)

#buka-abstraksi[
  Komentari baris `applyMeshLocalPrefix();` pada *salah satu* node, flash
  ulang, dan amati: kedua node tetap mencetak `Attached as:`, tetapi tidak ada
  satu pun baris `RX`. Bandingkan awalan EID keduanya --- di situlah bukti
  kegagalannya. Kembalikan kodenya. Percobaan ini mengajarkan sesuatu yang
  jarang terlihat: *jaringan bisa "terbentuk" tetapi tidak berfungsi*, dan log
  status saja tidak cukup untuk menyimpulkan keberhasilan.
]

#checkpoint[
  Kedua node mencetak `Attached as: ...` *dan* awalan EID keduanya sama
  (`fdde:ad00:beef:0:`). Jika awalannya berbeda, jangan lanjut --- tidak akan
  ada paket yang sampai.
]

=== EXP-02 --- PING Multicast dan PONG Unicast

Node1 bind grup multicast port 5050 dan juga unicast; Node2 mengirim `PING`
multicast tiap 3 detik lalu Node1 membalas `PONG` unicast.

#diagram(```
 [N2] TX PING (multicast ff03::abcd:5050) ──3 s──►
      [N1] RX PING ──► TX PONG (unicast ke EID N2)
 [N2] RX PONG dari EID Node1
```.text)

*Expected output --- Node1* (dari uji di board; alamat dan peran di board Anda
akan berbeda)

#keluaran("Node1 (Thread Leader) starting...
Menunggu attach...
Attached as: Child         <- bisa juga Leader, tergantung urutan boot
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_P2P
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0xE801
  Extended addr  : FA:FE:07:23:A6:B1:A9:FB
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:e54c:17e1:80ad:62a4
Mendengarkan [ff03::abcd]:5050 (dan unicast)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)")

*Expected output --- Node2*

#keluaran("Node2 (Thread Child) starting...
Menunggu join ke network Leader...
Attached as: Leader        <- bisa juga Child, tergantung urutan boot
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_P2P
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0xE800
  Extended addr  : 3E:CC:8F:12:00:85:DF:E5
  EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
  Mesh-Local EID : fdde:ad00:beef:0:cbc4:ae06:ccea:2768
TX PING (multicast)
TX PING (multicast)
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'")

Blok info network kedua node harus sama pada *Network name, Channel, PAN ID,
dan Extended PAN ID*. Pada uji ini Node2 yang menjadi Leader (`RLOC16 0xE800`)
dan Node1 menjadi child-nya (`0xE801`) --- peran tidak ditentukan kode.
Perhatikan juga `Extended addr` ≠ `EUI-64` (@tbl:m11-alamat).


#checkpoint[
  Alamat yang tercetak pada baris `RX` di Node2 harus *sama persis* dengan
  Mesh-Local EID Node1. Jika tidak cocok, ada node lain di ruangan yang ikut
  membalas --- catat, itu temuan menarik untuk analisis.
]

=== EXP-03 --- Jarak, Kehilangan Peer, dan Latency

+ *Jarak* --- geser Node2 dari 1 sampai 15 m; hitung jumlah PONG diterima per
  10 PING pada tiap jarak.
+ *Kehilangan peer* --- matikan Node1 selama 30 detik; amati Node2 tetap
  mencetak `TX PING (multicast)` tanpa `RX PONG`, lalu nyalakan lagi dan amati
  pemulihan *tanpa* intervensi manual.
+ *Latency* --- ukur selisih waktu antara `TX PING` di Node2 dan
  `RX ... 'PONG'` pada 10 sampel, lalu hitung rata-ratanya.

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [PONG diterima per 10 PING (1 m)], [#isian],
    [Perilaku Node2 saat Node1 mati], [#isian],
    [Waktu pemulihan setelah Node1 hidup lagi], [#isian],
    [Latency rata-rata (10 sampel)], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m11-exp03",
)

#checkpoint[
  Setelah Node1 dinyalakan lagi, `RX PONG` kembali muncul di Node2 *tanpa*
  Node2 direset sama sekali. Bandingkan dengan M06 (relay BLE) yang tidak pulih
  sendiri --- perbedaan ini adalah nilai jual Thread.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada 2 × *ESP32-H2 DevKitM-1* (flash di-erase lebih dulu), capture
45 detik.

#keluaran("# Node1 (ESP32-H2, env node1)              # Node2 (ESP32-H2, env node2)
[9.416] Attached as: Child                 [7.414] Attached as: Leader
[9.416] Mesh-Local EID:                    [7.414] Mesh-Local EID:
        fdde:ad00:beef:0:9fd0:c175:...             fdde:ad00:beef:0:407e:e905:...
[9.416] Mendengarkan [ff03::abcd]:5050     [7.414] TX PING (multicast)
[10.418] RX [fdde:ad00:beef:0:407e:...]    [10.419] TX PING (multicast)
         :5050 -> 'PING'                   [10.419] RX [fdde:ad00:beef:0:9fd0:...]
[10.418] TX PONG (unicast ke pengirim)              :5050 -> 'PONG'")

#tbl(
  table(
    columns: (1.4fr, 1.1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu attach Node2 dan Node1], [7,4 s dan 9,4 s sejak boot],
    [Awalan Mesh-Local EID kedua node], [`fdde:ad00:beef:0:` (identik --- syarat wajib)],
    [PING dikirim / PONG diterima], [12 / 12 (0 % loss)],
    [Latency PING ke PONG], [< 1 ms terukur di Serial (satu hop)],
  ),
  [Hasil verifikasi hardware Modul 11],
  "tbl:m11-verifikasi",
)

#catatan[
  Baris `E OT_STATE: handle_ot_role_change(105): Failed to get the active dataset`
  muncul sekali saat boot dan tidak berbahaya: role sempat berubah sebelum
  dataset selesai dibaca netif. Jaringan tetap terbentuk normal sesudahnya.
]


// Log serial lengkap dari week11_thread_p2p/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata. Baud 115200, dua board ESP32-H2 DevKitM-1, firmware versi terbaru: setelah attach, tiap node mencetak info network Thread — peran, network name, channel, PAN ID, Extended PAN ID, RLOC16, Extended Address, EUI-64, dan Mesh-Local EID. Log direkam 60 detik dengan `monitor_serial.py` (kedua port dalam satu komputer, satu sumbu waktu) lewat port UART CH343 di Windows. Board di-`erase` lalu di-flash; monitor me-reset semua board saat port dibuka, sehingga semua node boot hampir bersamaan.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: (left, left, left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Peran (terpilih)], th[RLOC16], th[EUI-64 (pabrik)], th[Extended addr (acak)], th[Port serial (UART)]),
      [Node1], [Child — menjawab PING], [`0xE801`], [`74:4D:BD:FF:` \ `FE:61:E6:2C`], [`FA:FE:07:23:` \ `A6:B1:A9:FB`], [`COM5`],
      [Node2], [*Leader* — mengirim PING], [`0xE800`], [`74:4D:BD:FF:` \ `FE:61:E8:C1`], [`3E:CC:8F:12:` \ `00:85:DF:E5`], [`COM11`],
    ),
    [Board dan port pada rekaman log serial Modul 11],
    "tbl:m11-log-1",
  )

  Network `ESP_OT_P2P`, channel *15*, PAN ID *`0xABCD`*, Extended PAN ID *`DE:AD:00:BE:EF:00:CA:FE`* — sama di kedua node. Group multicast `ff03::abcd`, port UDP 5050.

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
Node1 (Thread Leader) starting...
Menunggu attach...
Attached as: Child
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_P2P
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0xE801
  Extended addr  : FA:FE:07:23:A6:B1:A9:FB
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:e54c:17e1:80ad:62a4
Mendengarkan [ff03::abcd]:5050 (dan unicast)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
TX PONG (unicast ke pengirim)", pecah: true)

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
Node2 (Thread Child) starting...
Menunggu join ke network Leader...
Attached as: Leader
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_P2P
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0xE800
  Extended addr  : 3E:CC:8F:12:00:85:DF:E5
  EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
  Mesh-Local EID : fdde:ad00:beef:0:cbc4:ae06:ccea:2768
TX PING (multicast)
TX PING (multicast)
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
TX PING (multicast)
RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'", pecah: true)

  *Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)*

  #keluaran("[   0.739] Node2  | Node2 (Thread Child) starting...
[   0.739] Node2  | Menunggu join ke network Leader...
[   0.752] Node1  | Node1 (Thread Leader) starting...
[   0.752] Node1  | Menunggu attach...
[   7.303] Node2  | Attached as: Leader
[   7.303] Node2  | Info network Thread:
[   7.303] Node2  |   Peran          : Leader
[   7.303] Node2  |   Network name   : ESP_OT_P2P
[   7.303] Node2  |   Channel        : 15
[   7.303] Node2  |   PAN ID         : 0xABCD
[   7.303] Node2  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[   7.303] Node2  |   RLOC16         : 0xE800
[   7.529] Node2  |   Extended addr  : 3E:CC:8F:12:00:85:DF:E5
[   7.529] Node2  |   EUI-64         : 74:4D:BD:FF:FE:61:E8:C1
[   7.529] Node2  |   Mesh-Local EID : fdde:ad00:beef:0:cbc4:ae06:ccea:2768
[   7.529] Node2  | TX PING (multicast)
[  10.527] Node2  | TX PING (multicast)
[  10.562] Node1  | Attached as: Child
[  10.562] Node1  | Info network Thread:
[  10.562] Node1  |   Peran          : Child
[  10.562] Node1  |   Network name   : ESP_OT_P2P
[  10.562] Node1  |   Channel        : 15
[  10.562] Node1  |   PAN ID         : 0xABCD
[  10.562] Node1  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  10.562] Node1  |   RLOC16         : 0xE801
[  10.780] Node1  |   Extended addr  : FA:FE:07:23:A6:B1:A9:FB
[  10.781] Node1  |   EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
[  10.781] Node1  |   Mesh-Local EID : fdde:ad00:beef:0:e54c:17e1:80ad:62a4
[  10.781] Node1  | Mendengarkan [ff03::abcd]:5050 (dan unicast)
[  13.541] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  13.541] Node1  | TX PONG (unicast ke pengirim)
[  13.581] Node2  | TX PING (multicast)
[  13.581] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  16.554] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  16.554] Node1  | TX PONG (unicast ke pengirim)
[  16.570] Node2  | TX PING (multicast)
[  16.570] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  19.547] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  19.548] Node1  | TX PONG (unicast ke pengirim)
[  19.582] Node2  | TX PING (multicast)
[  19.582] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  22.551] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  22.552] Node1  | TX PONG (unicast ke pengirim)
[  22.567] Node2  | TX PING (multicast)
[  22.567] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  25.556] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  25.556] Node1  | TX PONG (unicast ke pengirim)
[  25.582] Node2  | TX PING (multicast)
[  25.582] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  28.568] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  28.569] Node1  | TX PONG (unicast ke pengirim)
[  28.568] Node2  | TX PING (multicast)
[  28.569] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  31.561] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  31.561] Node1  | TX PONG (unicast ke pengirim)
[  31.584] Node2  | TX PING (multicast)
[  31.584] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  34.571] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  34.571] Node1  | TX PONG (unicast ke pengirim)
[  34.586] Node2  | TX PING (multicast)
[  34.586] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  37.577] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  37.577] Node1  | TX PONG (unicast ke pengirim)
[  37.583] Node2  | TX PING (multicast)
[  37.584] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  40.573] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  40.573] Node1  | TX PONG (unicast ke pengirim)
[  40.583] Node2  | TX PING (multicast)
[  40.583] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  43.583] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  43.583] Node1  | TX PONG (unicast ke pengirim)
[  43.583] Node2  | TX PING (multicast)
[  43.584] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  46.587] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  46.587] Node1  | TX PONG (unicast ke pengirim)
[  46.598] Node2  | TX PING (multicast)
[  46.598] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  49.600] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  49.600] Node1  | TX PONG (unicast ke pengirim)
[  49.600] Node2  | TX PING (multicast)
[  49.601] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  52.600] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  52.601] Node1  | TX PONG (unicast ke pengirim)
[  52.614] Node2  | TX PING (multicast)
[  52.614] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  55.605] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  55.605] Node1  | TX PONG (unicast ke pengirim)
[  55.621] Node2  | TX PING (multicast)
[  55.621] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'
[  58.628] Node1  | RX [fdde:ad00:beef:0:cbc4:ae06:ccea:2768]:5050 -> 'PING'
[  58.628] Node1  | TX PONG (unicast ke pengirim)
[  58.628] Node2  | TX PING (multicast)
[  58.628] Node2  | RX [fdde:ad00:beef:0:e54c:17e1:80ad:62a4]:5050 -> 'PONG'", pecah: true)

  *Ringkasan `monitor_serial.py`*

  #keluaran("Durasi: 60.4 s
  Node1  Child   COM5             55 baris, boot 1x, attach 10.20 s sejak boot
         EID fdde:ad00:beef:0:e54c:17e1:80ad:62a4
         network ESP_OT_P2P, channel 15, PAN 0xABCD, RLOC16 0xE801, EUI-64 74:4D:BD:FF:FE:61:E6:2C
  Node2  Leader  COM11            56 baris, boot 1x, attach  6.92 s sejak boot
         EID fdde:ad00:beef:0:cbc4:ae06:ccea:2768
         network ESP_OT_P2P, channel 15, PAN 0xABCD, RLOC16 0xE800, EUI-64 74:4D:BD:FF:FE:61:E8:C1
  Network name/Channel/PAN ID/Extended PAN ID semua node: sama (satu network)

Link (pengirim -> penerima)   jenis   kirim  terima    loss
------------------------------------------------------------
Node1 -> Node2                PONG       16      16     0.0%
Node2 -> Node1                PING       16      16     0.0%

Round-trip di Node2: 16/18 PING dijawab PONG (88.9%)
  RTT PING -> PONG: rata2 0 ms (0..0) — timestamp PC, kasar

Loss hanya menghitung pesan setelah penerima siap; 'n/a' = tidak bisa dihitung.", pecah: true)

  *Catatan*

  - *Info network cocok di kedua node*: network name, channel, PAN ID, dan Extended PAN ID sama — nilai ini berasal dari dataset yang ditulis kode, bukan dipilih jaringan (berbeda dengan Zigbee).
  - *Peran tidak ditentukan kode.* Banner firmware menyebut `Node1 (Thread Leader)`, tetapi pada rekaman ini *Node2 menjadi Leader* (attach 6,9 s) dan Node1 menjadi Child (10,2 s): node yang lebih dulu membentuk partisi menjadi Leader. Aplikasi tetap berjalan karena PING/PONG tidak bergantung pada peran.
  - *RLOC16 menunjukkan parent.* Leader `0xE800` adalah router dengan Router ID 58 (`0xE800 >> 10`); Child `0xE801` memakai Router ID yang sama ditambah Child ID 1, artinya parent Node1 adalah Node2.
  - *Padanan alamat* (bandingkan dengan XBee dan Zigbee di Modul 08): `RLOC16` ≈ MY (alamat 16-bit, dibagikan jaringan dan *bisa berubah* bila peran/parent berubah); `EUI-64` = SH+SL (alamat pabrik, tetap); `Channel` = CH; `PAN ID` = OI; `Extended PAN ID` = OP.
  - *Extended addr ≠ EUI-64.* Thread memakai Extended Address *acak* sebagai alamat MAC 64-bit (privasi), berbeda dengan Zigbee yang memakai IEEE address pabrik. Alamat yang tetap untuk mengenali board tetap EUI-64.
  - *Mesh-Local EID* adalah alamat IPv6 node di dalam mesh; alamat ini yang muncul di baris `RX [...]`. Awalannya (`fdde:ad00:beef:0:`) harus sama di semua node.
  - *PING/PONG 16/16 (0 % loss)* setelah Node1 siap. Dua PING pertama Node2 (dikirim sebelum Node1 attach) tidak terjawab, sehingga round-trip tercatat 16/18. RTT tercatat 0 ms karena PONG tiba di bawah resolusi timestamp PC.
  - Selisih waktu memakai timestamp PC, jadi kasar (resolusi USB-serial).
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

#tbl(
  table(
    columns: (auto, 1fr, 1.1fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Jarak], th[RSSI], th[Latency (ms)], th[Success]),
    [1 m], [#isian], [], [… / 10],
    [3 m], [#isian], [], [… / 10],
    [5 m], [#isian], [], [… / 10],
    [10 m], [#isian], [], [… / 10],
    [15 m], [#isian], [], [… / 10],
  ),
  [Lembar pengukuran jarak Modul 11],
  "tbl:m11-ukur",
)

Success adalah jumlah PONG diterima dari 10 PING; latency adalah waktu PING ke
PONG dalam milidetik.

*Bandingkan dengan M07 dan M08.* Radionya sama (802.15.4 channel 15), jadi
selisih jangkauan berasal dari lapisan di atasnya (@tbl:m11-banding).

#tbl(
  table(
    columns: (1.2fr, auto, 1.2fr, 1.2fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Protokol], th[Modul], th[Jarak 100 % berhasil], th[Overhead per pesan],
    ),
    [802.15.4 raw], [M07], [#isian], [11 byte MHR],
    [Zigbee], [M08], [#isian], [],
    [Thread (IPv6/UDP)], [M11], [#isian], [header IPv6 dan UDP],
  ),
  [Tabel pembanding jangkauan dan overhead M07, M08, dan M11],
  "tbl:m11-banding",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Berapa latency rata-rata round-trip PING ke PONG pada jarak 1 m dan 10 m?
+ Bagaimana tren RSSI dan success rate terhadap peningkatan jarak?
+ Mengapa PING dikirim multicast sedangkan PONG unicast? Apa keuntungannya
  untuk jaringan berisi banyak node?
+ Apa perbedaan alamat mesh-local EID (`fd...`) dan link-local (`fe80::`) pada
  jaringan Thread, dan yang mana yang muncul pada log hasil percobaan?
+ Apa yang terjadi di Node2 ketika Node1 dimatikan? Mengapa PING tetap
  terkirim, dan apa artinya bagi desain aplikasi?

== Concept Check

+ Apa itu Active Dataset dan parameter apa saja yang di-set sebelum
  `OThread.start()`?
+ Bagaimana sebuah node menjadi Leader pada jaringan Thread?
+ Jelaskan perbedaan alamat realm-local multicast `ff03::abcd` dengan unicast
  mesh-local EID.
+ Mengapa komunikasi Thread memakai IPv6 dibanding alamat 16-bit seperti
  Zigbee? Apa untungnya untuk Modul 13?
+ Apa fungsi `OtUdp.begin(PORT)` pada Node2 dibanding `beginMulticast()` pada
  Node1?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Menambah node dan menghitung loss])[
  / CH-1 --- Node ketiga: Tambah `node3` (salin `src/node2`, tambahkan env di
    `platformio.ini`). Amati bahwa PONG dari Node1 tetap hanya dikirim ke
    pengirim aslinya, dan bandingkan EID ketiga node --- awalannya harus sama,
    sisanya berbeda.

  / CH-2 --- Packet loss (wajib): Beri nomor urut pada PING (`PING:1`,
    `PING:2`, dan seterusnya) lalu hitung loss di sisi penerima. Contoh: 60
    PING dikirim, 55 PONG diterima, sehingga
    loss = (60 − 55)/60 × 100 % = 8,33 %. Pisahkan: PING yang hilang dibanding
    PONG yang hilang.
]

#tujuan-prak(3, [Statistik latency dan kegagalan senyap])[
  / CH-3 --- Statistik latency: Ukur latency 30 sampel, hitung minimum,
    maksimum, rata-rata, dan simpangannya. Bandingkan dengan latency Zigbee M08
    pada jarak yang sama.

  / CH-4 --- Prefix salah, sengaja: Ubah `OT_ML_PREFIX` di *satu* node saja
    (misalnya byte kedua menjadi `0xdd`), flash, lalu dokumentasikan gejalanya
    secara lengkap: apa yang tetap normal, apa yang gagal, dan bagaimana
    diagnosisnya ditegakkan dari log. Ini melatih membaca _kegagalan senyap_.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (Thread, Leader dan Child, Active Dataset, mesh-local
  prefix dan EID, multicast realm-local).
+ Konfigurasi --- env `node1` dan `node2`, dataset lengkap, port 5050, grup
  `ff03::abcd`, serta interval 3 s.
+ Hasil eksperimen --- log attach, EID kedua node, sesi PING--PONG, dan hasil
  percobaan "buka abstraksinya".
+ Data pengukuran --- tabel bagian Pengukuran beserta tabel pembanding M07,
  M08, dan M11.
+ Analisis dan concept check.
+ Challenge --- minimal CH-2 dan CH-4.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
