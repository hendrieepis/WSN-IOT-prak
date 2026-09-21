// ============================================================================
// Modul 02 — Pertukaran Data Dua Arah via BLE
// Sumber: week02_ble_p2p_data/README.md; listing kode dibaca langsung dari
//         salinan berkas sumber di assets/code/week02_ble_p2p_data/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 02 — Pertukaran Data Dua Arah via BLE", l: "bab:modul-02")

#identitas-modul(
  "Modul 02",
  [Exchange Data --- Pertukaran Data Dua Arah via BLE],
  [ESP32-H2 · BLE GATT · NOTIFY/WRITE · level Basic · 3 × 50 menit ·
   folder kode `week02_ble_p2p_data`],
)

#pengantar([Gambaran Umum])[
Modul 02 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat dasar.
Misinya memindahkan payload aplikasi ke dua arah di atas tautan BLE, lalu
mengukur apa yang benar-benar selamat sampai tujuan. Percobaan berjalan dalam
mode P2P antara server yang menyediakan notify dan write dengan sebuah client,
diamati melalui dua terminal Serial Monitor pada 115200 baud.
]

== Pendahuluan

Modul 01 hanya membuktikan *tautan* terbentuk --- belum ada satu byte aplikasi
pun yang lewat. Modul ini memakai tautan itu untuk membawa data, dan
memperkenalkan dua mekanisme yang akan dipakai terus sampai Modul 16: *notify*
(server mendorong) dan *write* (client mengirim).

Prasyaratnya adalah M01: tautan BLE P2P sudah terbentuk dan Serial Monitor
sudah terbaca sebagai instrumen. Yang dibangun di sini adalah dua
characteristic dengan peran berbeda (TX/NOTIFY dan RX/WRITE), mekanisme
subscribe, callback `onWrite` dan `onNotify`, pola echo, serta pengukuran loss
dua arah. Semuanya dipakai lagi pada M03 ketika characteristic menjadi data
terstruktur, M04 ketika notify berkembang menjadi telemetry berkala, M05 saat
jumlah node bertambah, dan M16 ketika loss serta latency menjadi metrik
pembanding antarprotokol.

*Peta modul blok BLE*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [01], [Tautan BLE P2P terbentuk dan stabil],
    [*02 (ini)*], [*Payload aplikasi mengalir dua arah lewat tautan M01*],
    [03], [GATT characteristic --- read/write data terstruktur],
    [04], [Telemetry via notify (push berkala tanpa polling)],
    [05], [Lebih dari dua node --- satu central, banyak peripheral],
    [06], [Relay A→B→C, jangkauan diperluas lewat hop],
  ),
  [Peta modul blok BLE],
  "tbl:m02-peta",
)

*Kontrak data lab ini.* Mulai modul ini setiap payload membawa penanda yang
bisa dihitung --- di sini `millis()`, mulai CH-1 berupa nomor urut `SEQ=<n>`.
Nomor urut itulah yang membuat _packet loss_ bisa dihitung, dan format yang
sama akan muncul lagi di Zigbee (M09), Thread (M12), dan MQTT (M14).

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Mengalirkan payload aplikasi dua arah dan mengukurnya])[
  + Membuat dua characteristic pada satu service BLE dengan property berbeda
    (`NOTIFY` untuk TX, `WRITE` untuk RX) dan menunjukkan baris kode yang
    menetapkannya.
  + Menjalankan subscribe dari sisi client sehingga notify dari server
    benar-benar diterima, dibuktikan dari log kedua node.
  + Mengirim data dari client ke server memakai write dan menjelaskan jalur
    echo-nya (`onWrite` → `notify` → `onNotify`) dari urutan timestamp di dua
    Serial Monitor.
  + Menghitung packet loss tiap arah secara terpisah (notify hilang
    dibandingkan write hilang) pada minimal 4 jarak berbeda.
]

*Kriteria keberhasilan*

#checklist((
  [Client subscribe ke characteristic TX dan menerima notify tiap 2 detik.],
  [Write dari client tiba di server dan di-echo balik utuh (isi sama persis).],
  [Tabel jarak--RSSI--loss terisi dari pengukuran sendiri, minimal 4 jarak.],
  [CH-1 selesai: payload memakai `SEQ=<n>` sehingga loss terhitung dari
   lompatan nomor.],
))

== Dasar Teori (Secukupnya)

Teori di sini dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam
(mengapa GATT dirancang berlapis, detail ATT/L2CAP) berada di buku teori
terpisah. Istilah kerja dirangkum pada @tbl:m02-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [GATT], [Skema data hierarkis Server → Service → Characteristic.],
    [Service], [Wadah characteristic; UUID `4fafc201-1fb5-459e-8fcc-c5c9c331914b`.],
    [Characteristic], [Unit data; punya UUID sendiri dan satu atau lebih property.],
    [Property WRITE], [Client boleh menulis nilai ke characteristic milik server.],
    [Property NOTIFY], [Server mendorong nilai ke client tanpa diminta --- tetapi hanya setelah client subscribe.],
    [Subscribe], [Client mengaktifkan notify pada characteristic TX (menulis ke CCCD).],
    [`onWrite` / `onNotify`], [Callback yang dipicu saat data ditulis ke server atau notifikasi tiba di client.],
    [Echo], [Server mengirim balik isi write lewat notify --- dipakai untuk membuktikan jalur pulang.],
  ),
  [Istilah kerja Modul 02],
  "tbl:m02-istilah",
)

*Mengapa dua characteristic, bukan satu?* Satu characteristic hanya bisa
mengalir efisien ke satu arah: `NOTIFY` adalah dorongan server ke client,
`WRITE` adalah kiriman client ke server. Memisahkan TX dan RX membuat arah data
terbaca langsung dari UUID-nya --- pola yang sama dipakai profil serial BLE
(Nordic UART Service) di dunia nyata.

*Sekuens protokol yang diamati*

#diagram(```
Node1 (Server)                              Node2 (Client)
  CHAR_TX (NOTIFY) ──── "Hello dari Node1" ────►  onNotify()
  CHAR_RX (WRITE)  ◄─── "Halo dari Node2"  ─────  writeValue()
  onWrite() ─── echo lewat CHAR_TX ────────────►  onNotify()
```.text)

== Topologi

#diagram(```
   BOARD #1                          BOARD #2
┌──────────────┐   NOTIFY (TX)   ┌──────────────┐
│   ESP32-H2   │ ──────────────► │   ESP32-H2   │
│  DevKitM-1   │                 │  DevKitM-1   │
│    Node 1    │                 │    Node 2    │
│ (BLE Server) │ ◄────────────── │ (BLE Client) │
└──────────────┘  WRITE (RX)     └──────────────┘
   env: node1                        env: node2
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, auto, 1.2fr),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Aksi periodik]),
    [Node 1], [ESP32-H2 DevKitM-1], [`node1`], [BLE Server (`NODE1_H2`)],
    [notify `Hello dari Node1 (<millis>)` tiap 2 s],
    [Node 2], [ESP32-H2 DevKitM-1], [`node2`], [BLE Client],
    [write `Halo dari Node2 (<millis>)` tiap 3 s],
  ),
  [Peran dan aksi periodik tiap node Modul 02],
  "tbl:m02-topologi",
)

Kedua peran berjalan di *ESP32-H2* dengan radio Bluetooth LE --- modul ini
tidak membutuhkan ESP32-C6. Pesan yang diterima server di-echo kembali ke
client lewat notify.

*Address map* (identik di kedua node)

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Objek], th[UUID]),
    [Service], [`4fafc201-1fb5-459e-8fcc-c5c9c331914b`],
    [CHAR_TX (NOTIFY)], [`beb5483e-36e1-4688-b7f5-ea07361b26a8`],
    [CHAR_RX (WRITE)], [`beb5483e-36e1-4688-b7f5-ea07361b26a9`],
  ),
  [Peta UUID Modul 02],
  "tbl:m02-uuid",
)

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
    [1], [Board ESP32-H2], [DevKitM-1], [2],
    [2], [Kabel USB data], [USB-A/C ke micro-USB, *kabel data* (bukan kabel _charge-only_)], [2],
    [3], [PC/Laptop], [PlatformIO Core/IDE terpasang, 2 port USB bebas], [1],
    [4], [Library NimBLE-Arduino], [`h2zero/NimBLE-Arduino@^2.2.3` --- otomatis via `lib_deps`], [---],
    [5], [Platform PlatformIO], [pioarduino `espressif32` 55.03.311 (Arduino core 3.3.11)], [---],
  ),
  [Alat dan bahan Modul 02],
  "tbl:m02-alat",
)

== Kode Program

#sumber-kode("week02_ble_p2p_data",
  ("platformio.ini", "src/node1/main.cpp", "src/node2/main.cpp"))

*Kunci agar dua board tidak salah flash.* Dengan dua ESP32-H2 terpasang
bersamaan, auto-detect port bisa mengirim firmware `node1` ke board yang
dimaksudkan sebagai `node2`. Pin port tiap environment seperti
@lst:m02-ini-readme.

#kode(```ini
[env:node1]
build_src_filter = +<node1/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3  -- board Node1
monitor_port = /dev/ttyACM0

[env:node2]
build_src_filter = +<node2/*.cpp>
upload_port  = /dev/ttyACM2     ; Windows: COM4  -- board Node2
monitor_port = /dev/ttyACM2
```.text,
  [Potongan `platformio.ini` dengan port yang dipin per environment],
  "lst:m02-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week02_ble_p2p_data/platformio.ini",
  [`platformio.ini` Modul 02 pada repositori],
  "lst:m02-ini",
)

#kode-berkas("week02_ble_p2p_data/src/node1/main.cpp",
  [`src/node1/main.cpp` --- BLE Server dengan CHAR_TX dan CHAR_RX],
  "lst:m02-node1",
  pecah: true,
)

#kode-berkas("week02_ble_p2p_data/src/node2/main.cpp",
  [`src/node2/main.cpp` --- BLE Client yang subscribe dan write],
  "lst:m02-node2",
  pecah: true,
)

== Build dan Flash

#keluaran("pio device list                                      # catat port dulu
pio run -d week02_ble_p2p_data -e node1 -t upload
pio run -d week02_ble_p2p_data -e node2 -t upload -t monitor")

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
  [Jalankan `pio device list`, catat port tiap board, isi
   `upload_port`/`monitor_port` di atas.],
  [Board pertama terhubung (akan diflash `node1`, BLE Server), board kedua
   terhubung (`node2`, BLE Client).],
  [Firmware `node1` dan `node2` berhasil build tanpa galat.],
  [Dua Serial Monitor 115200 baud dibuka lebih dulu, lalu tekan RESET agar
   sekuens boot terekam.],
))

== Percobaan

=== EXP-01 --- Connect dan Subscribe

Node1 advertise `NODE1_H2`; Node2 scan, konek, mencari service dan kedua
characteristic, lalu subscribe ke TX.

#diagram(```
Node2: Scan ─► NODE1_H2 ditemukan ─► Connect ─► getService()
      ─► getCharacteristic(TX/RX) ─► subscribe(TX, notify)
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama device server yang ditemukan], [#isian],
    [Service UUID ditemukan], [#isian],
    [Jumlah characteristic ditemukan], [#isian],
    [Waktu dari scan sampai subscribe selesai (s)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m02-exp01",
)

#buka-abstraksi[
  Di `src/node2/main.cpp`, `pTx->subscribe(true, onNotify)` tampak seperti satu
  baris biasa. Sebenarnya baris itu *menulis ke CCCD* (Client Characteristic
  Configuration Descriptor) milik server. Cari di `src/node1/main.cpp` di mana
  descriptor itu dibuat --- jawabannya: tidak ada, NimBLE menambahkannya
  otomatis begitu property `NOTIFY` dipasang. Buktikan dengan nRF Connect: buka
  characteristic TX dan lihat descriptor `0x2902`.
]

#checkpoint[
  Node2 mencetak `Koneksi berhasil`. Jika berhenti di `Scanning Node1...`:
  pastikan board `node1` menyala dan nama pada `advertisedDevice->getName()` di
  Node2 sama persis dengan `pAdvertising->setName()` di Node1.
]

=== EXP-02 --- Downlink: Server ke Client (notify)

Setelah terhubung, Node1 mengirim notify setiap 2000 ms.

*Expected output --- Node1 (Server)*

#keluaran("Node1 (BLE Server) starting...
Menunggu koneksi dari Node2...
Client terhubung
TX ke Node2: Hello dari Node1 (2043)
TX ke Node2: Hello dari Node1 (4047)")

*Expected output --- Node2 (Client)*

#keluaran("Node2 (BLE Client) starting...
Scanning Node1...
Node1 ditemukan
Terhubung ke Node1
Koneksi berhasil
RX dari Node1: Hello dari Node1 (2043)
RX dari Node1: Hello dari Node1 (4047)")

#checkpoint[
  Baris `RX dari Node1` muncul di Node2 dengan jarak ±2 detik dan nilai
  `millis()` yang sama persis dengan `TX ke Node2` di Node1. Jika nilainya
  berbeda, log yang sedang dibaca tidak sinkron --- hentikan dan periksa dulu,
  jangan lanjut ke EXP-03.
]

=== EXP-03 --- Uplink dan Echo: Client ke Server (write)

Node2 menulis ke characteristic RX tiap 3000 ms. Server menerima (`onWrite`),
mencetak, lalu meng-echo balik lewat notify pada characteristic TX.

#diagram(```
Node2 ── WRITE "Halo dari Node2 (6051)" ──► Node1 CHAR_RX
Node1 ── print "RX dari Node2: ..."
Node1 ── NOTIFY (echo) ──► Node2 print "RX dari Node1: Halo dari Node2 (6051)"
```.text)

*Expected output --- Node1*

#keluaran("RX dari Node2: Halo dari Node2 (6051)
TX ke Node2: Halo dari Node2 (6051)")

*Expected output --- Node2*

#keluaran("TX ke Node1: Halo dari Node2 (6051)
RX dari Node1: Halo dari Node2 (6051)")

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Interval notify Node1 (ms)], [2000],
    [Interval write Node2 (ms)], [3000],
    [Contoh payload notify Node1], [#isian],
    [Contoh payload write Node2], [#isian],
    [Apakah echo diterima Node2? (ya/tidak)], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m02-exp03",
)

#checkpoint[
  Pada Node2 muncul *dua jenis* baris `RX dari Node1`: yang berisi `Hello ...`
  (notify periodik) dan yang berisi `Halo ...` (echo dari write yang dikirim
  sendiri). Jika hanya satu jenis yang muncul, satu arah belum jalan ---
  perbaiki sebelum masuk ke pengukuran.
]

== Verifikasi Hardware --- Log Referensi

Modul ini sudah dijalankan pada 2 × *ESP32-H2 DevKitM-1* (jarak ±20 cm, capture
25 detik). Log di bawah adalah hasil sebenarnya, bukan ilustrasi.

#keluaran("# Node 1 (ESP32-H2, env node1)          # Node 2 (ESP32-H2, env node2)
[0.200] Node1 (BLE Server) starting...  [0.401] Node2 (BLE Client) starting...
[0.401] Menunggu koneksi dari Node2...  [0.401] Scanning Node1...
[0.601] Client terhubung                [0.401] Node1 ditemukan
[2.205] TX ke Node2: Hello ... (2005)   [0.601] Terhubung ke Node1
[3.407] RX dari Node2: Halo ... (3001)  [2.404] RX dari Node1: Hello ... (2005)
                                        [3.406] TX ke Node1: Halo ... (3001)
                                        [3.406] RX dari Node1: Halo ... (3001)  <- echo")

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu scan sampai subscribe], [± 1,4 s],
    [Notify Node1 diterima Node2], [12 / 12 (0 % loss)],
    [Write Node2 diterima Node1], [8 / 8 (0 % loss)],
    [Echo kembali ke Node2], [ya, payload utuh],
  ),
  [Hasil verifikasi hardware Modul 02],
  "tbl:m02-verifikasi",
)

== Pengukuran

Pindahkan Node1 menjauh; hitung jumlah pesan yang diterima Node2 per interval
pengamatan. *Hitung tiap arah terpisah* --- inti modul ini adalah dua arah
tidak selalu gagal bersamaan.

RSSI dibaca dari log Node2 sendiri. Tambahkan pada heartbeat Node2 seperti
@lst:m02-rssi.

#kode(```cpp
// Node2 - di loop(), saat terhubung
Serial.printf("RSSI: %d dBm\n", pClient->getRssi());
```.text,
  [Cetak RSSI pada heartbeat Node2],
  "lst:m02-rssi",
)

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[RSSI (dBm)], th[Interpretasi]),
    [> −70], [Kuat --- koneksi andal],
    [−70 s.d. −85], [Baik --- masih stabil],
    [−85 s.d. −95], [Marginal --- mulai rawan putus],
    [< −95], [Tidak reliable --- sering gagal],
  ),
  [Referensi interpretasi RSSI],
  "tbl:m02-referensi-rssi",
)

#tbl(
  table(
    columns: (auto, 0.9fr, 1.15fr, 1.15fr, 0.9fr, 0.9fr),
    align: (left, left, left, left, left, left),
    inset: (x: 0.35em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Jarak], th[RSSI (dBm)], th[Notify /30 s (harapan 15)],
      th[Write ter-echo /30 s (harapan 10)], th[Loss down (%)], th[Loss up (%)],
    ),
    [1 m], [#isian], [], [], [], [],
    [3 m], [#isian], [], [], [], [],
    [5 m], [#isian], [], [], [], [],
    [10 m], [#isian], [], [], [], [],
    [15 m], [#isian], [], [], [], [],
  ),
  [Lembar pengukuran loss dua arah Modul 02],
  "tbl:m02-loss",
)

Latency diestimasi dari selisih nilai `millis()` pada payload terhadap waktu
kedatangan di Node2.

== Analisis

Jawab berdasarkan tabel bagian Pengukuran, bukan berdasarkan teori saja.

+ Bagaimana pengaruh jarak terhadap nilai RSSI pada data pengukuran yang
  diperoleh?
+ Pada RSSI berapa pesan mulai hilang? Bandingkan dengan tabel referensi.
+ Berapa latency rata-rata satu arah (Node1 ke Node2)?
+ Apakah loss downlink dan uplink mulai naik pada jarak yang sama? Jika
  berbeda, apa dugaan penyebabnya (daya pancar, `writeValue(..., true)` yang
  menunggu response, atau posisi antena)?
+ Untuk data periodik, mana yang lebih hemat: notify atau client yang
  mem-_polling_ dengan read berulang? Dukung dengan jumlah transaksi per menit
  dari data hasil pengukuran.

== Concept Check

+ Apa perbedaan property READ, WRITE, dan NOTIFY pada characteristic?
+ Mengapa client harus subscribe sebelum bisa menerima notify?
+ Apa yang terjadi jika server memanggil `notify()` saat tidak ada client
  terhubung?
+ Bagaimana arsitektur GATT menentukan arah aliran data?
+ `writeValue(..., true)` menunggu response dari server, `false` tidak. Kapan
  masing-masing lebih tepat dipakai?

== Challenge (Tugas Modifikasi)

Modifikasi kode, bukan sekadar menjelaskan hasil.

#tujuan-prak(2, [Payload bernomor urut dan penghitungan loss])[
  / CH-1 --- Nomor urut (wajib, dipakai modul berikutnya): Ganti payload notify
    Node1 menjadi `SEQ=<n>` dengan nomor urut bertambah tiap kirim, interval
    500 ms, seperti @lst:m02-ch1.

  / CH-2 --- Deteksi loss otomatis: Di Node2, simpan nomor urut terakhir dan
    cetak peringatan saat ada lompatan, lalu hitung loss-nya seperti
    @lst:m02-ch2. Contoh pelaporan: 30 dikirim, 27 diterima, sehingga
    loss = (30 − 27)/30 × 100 % = 10 %.
]

#kode(```cpp
// Node1 - loop()
static uint32_t seq = 0;
String msg = "SEQ=" + String(++seq);
```.text,
  [Kerangka CH-1 --- payload bernomor urut],
  "lst:m02-ch1",
)

#kode(```cpp
// Node2 - di onNotify()
static uint32_t last = 0;
uint32_t n = atoi(strchr((char*)pData, '=') + 1);
if (last && n != last + 1) Serial.printf("LOSS: %lu paket\n", n - last - 1);
last = n;
```.text,
  [Kerangka CH-2 --- deteksi lompatan nomor urut],
  "lst:m02-ch2",
)

#tujuan-prak(3, [Uji arah balik dan batas laju])[
  / CH-3 --- Uplink berpenanda: Terapkan hal yang sama pada arah write (Node2
    ke Node1) sehingga loss uplink terhitung otomatis di Node1. Bandingkan
    angkanya dengan loss downlink pada jarak yang sama.

  / CH-4 --- Backpressure: Turunkan interval notify Node1 ke 50 ms. Amati
    apakah Node2 masih menerima semua nomor urut. Pada interval berapa mulai
    ada yang hilang, dan mengapa? Petunjuk: connection interval BLE.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (GATT, property, subscribe, echo).
+ Konfigurasi --- `platformio.ini`, environment, UUID TX/RX.
+ Hasil eksperimen --- log Serial Monitor kedua arah (EXP-01 sampai EXP-03
  beserta checkpoint).
+ Data pengukuran --- tabel bagian Pengukuran, loss dua arah terpisah.
+ Analisis dan concept check.
+ Challenge --- minimal CH-1 dan CH-2, sertakan potongan kode yang diubah.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
