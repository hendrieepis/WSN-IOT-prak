// ============================================================================
// Modul 11 — Thread: Datagram UDP di atas IPv6
// Sumber: week11_thread_p2p/README.md; listing kode dibaca langsung dari
//         assets/code/week11_thread_p2p/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

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

*Expected output --- Node1*

#keluaran("Node1 (Thread Leader) starting...
Menunggu attach...
Attached as: Leader        <- bisa juga Child, tergantung urutan boot
Mesh-Local EID: fdde:ad00:beef:0:xxxx:xxxx:xxxx:xxxx
Mendengarkan [ff03::abcd]:5050 (dan unicast)
RX [fdde:ad00:beef:0:xxxx:...]:5050 -> 'PING'
TX PONG (unicast ke pengirim)")

*Expected output --- Node2*

#keluaran("Node2 (Thread Child) starting...
Menunggu join ke network Leader...
Attached as: Child         <- bisa juga Leader, tergantung urutan boot
Mesh-Local EID: fdde:ad00:beef:0:yyyy:...
TX PING (multicast)
RX [fdde:ad00:beef:0:xxxx:...]:5050 -> 'PONG'")

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
