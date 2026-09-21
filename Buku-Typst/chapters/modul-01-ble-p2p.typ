// ============================================================================
// Modul 01 — Komunikasi BLE Point-to-Point
// Sumber: week01_ble_p2p/README.md; listing kode dibaca langsung dari salinan
//         berkas sumber di assets/code/week01_ble_p2p/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist

#chapter("Modul 01 — Komunikasi BLE Point-to-Point", l: "bab:modul-01")

#identitas-modul(
  "Modul 01",
  [Establish a BLE Link --- Komunikasi BLE Point-to-Point],
  [ESP32-H2 · BLE · P2P · level Basic · 3 × 50 menit ·
   folder kode `week01_ble_p2p`],
)

#pengantar([Gambaran Umum])[
Modul 01 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat dasar.
Misinya membangun tautan BLE point-to-point yang stabil dan terverifikasi lewat
instrumen, bukan sekadar tersambung sekali lalu dianggap selesai. Percobaan
berjalan dalam mode P2P antara satu peripheral dan satu central, dengan Serial
Monitor 115200 baud sebagai instrumen utama dan aplikasi nRF Connect sebagai
pembanding opsional.
]

== Pendahuluan

BLE adalah stack berlapis. Modul ini adalah lapisan paling bawah: tautan radio
itu sendiri --- belum ada payload aplikasi. Modul-modul berikutnya menumpuk di
atas tautan yang dibangun di sini, sehingga modul ini perlu dikerjakan sampai
benar-benar solid sebelum melangkah lebih jauh.

Bekal yang diperlukan hanya dasar bahasa C dan pemahaman alur build PlatformIO;
sebagai modul pembuka, tidak ada modul BLE yang mendahuluinya. Yang dibangun di
sini adalah advertising, active scanning, pembentukan koneksi P2P, dan
pengukuran RSSI terhadap jarak. Keempatnya dipakai lagi secara berurutan pada
M02 (payload di atas tautan ini), M03 (GATT read/write), M04 (telemetry via
notify), hingga M05 ketika jumlah node melampaui dua.

*Peta modul blok BLE*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [*01 (ini)*], [*Tautan BLE P2P terbentuk dan stabil*],
    [02], [Pertukaran payload aplikasi lewat tautan M01],
    [03], [GATT characteristic --- read/write data terstruktur],
    [04], [Telemetry via notify (push berkala tanpa polling)],
    [05], [Skala lebih dari dua node (menuju ranah WSN)],
    [06], [Relay A→B→C --- jangkauan diperluas lewat hop],
  ),
  [Peta modul blok BLE],
  "tbl:m01-peta",
)

*Kontrak data lab ini.* Modul ini belum mengirim payload, tetapi sudah
menetapkan dua hal yang dipakai seterusnya: *Service UUID*
`4fafc201-1fb5-459e-8fcc-c5c9c331914b` (dipakai ulang M02--M06 dan M16) dan
*Serial Monitor sebagai instrumen ukur*, bukan sekadar tempat log.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Membangun tautan BLE point-to-point yang terverifikasi])[
  + Menjelaskan perbedaan peran BLE Peripheral (advertiser/server) dan Central
    (scanner/client).
  + Menyusun proyek PlatformIO dua environment (`node1`, `node2`) dan memilih
    source per board lewat `build_src_filter`.
  + Menjalankan advertising dengan Device Name dan Service UUID tertentu, lalu
    memverifikasinya dari paket yang benar-benar mengudara.
  + Membangun koneksi BLE point-to-point melalui active scanning dari sisi
    Central.
  + Mengukur RSSI terhadap jarak dari log node sendiri dan menentukan ambang
    RSSI saat koneksi mulai gagal.
]

*Kriteria keberhasilan*

#checklist((
  [Node2 menemukan `NODE1_H2` dan membentuk koneksi.],
  [Kedua node mencetak heartbeat status terhubung tiap 5 detik.],
  [Uji disconnect (EXP-03) membuktikan tautan dua arah --- bukan sekadar
   heartbeat lokal.],
  [Tabel jarak--RSSI--keberhasilan terisi lengkap dari pengukuran sendiri.],
))

== Dasar Teori (Secukupnya)

Teori di sini dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam
(mengapa BLE hemat daya, detail lapisan protokol) berada di buku teori
terpisah; panduan ini fokus pada "bagaimana". Istilah kerja yang diperlukan
dirangkum pada @tbl:m01-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [BLE], [Varian Bluetooth berdaya rendah untuk komunikasi data berkala.],
    [Peripheral / Advertiser], [Device yang menyiarkan paket advertising berisi nama device dan Service UUID.],
    [Central / Scanner], [Device yang memindai paket advertising dan memulai koneksi.],
    [Advertising], [Proses menyiarkan keberadaan device (nama `NODE1_H2` dan Service UUID).],
    [Active scan], [Scan dengan scan-request tambahan agar data advertising lengkap.],
    [Connection], [Tautan BLE setelah Central meminta koneksi ke Peripheral.],
    [GATT / Service], [Struktur data di atas koneksi; modul ini membuat service *tanpa* characteristic.],
    [RSSI], [Kuat sinyal terima (dBm); makin mendekati nol makin kuat --- −50 lebih kuat dari −90.],
  ),
  [Istilah kerja Modul 01],
  "tbl:m01-istilah",
)

*Mengapa ESP32-H2?* H2 mendukung BLE 5 dan 802.15.4 (Thread/Zigbee), tetapi
tidak punya Wi-Fi maupun Bluetooth Classic. Jadi seluruh komunikasi di seri lab
ini murni BLE (dan 802.15.4 di modul lanjutan) --- bukan kebetulan, melainkan
pilihan board yang menegaskan fokus lab.

*Mengapa keluaran modul ini sedikit?* Service pada Node1 sengaja dibuat tanpa
characteristic, sehingga tidak ada data aplikasi yang dikirim. Setelah banner
boot dan pesan koneksi, kedua node hanya mencetak satu baris heartbeat tiap
5 detik. Itu bukan tanda program berhenti; itu memang bentuk keberhasilan
Modul 01. Karena heartbeat dicetak dari status *lokal* masing-masing node,
bukti tautan dua arah baru diperoleh di EXP-03.

*Sekuens protokol yang diamati*

#diagram(```
Advertiser (Node1)                Scanner (Node2)
      │ ──── Advertising ────►        │
      │ ◄─── Connect Request ────     │
      │ ════ Connection (P2P) ════►   │
```.text)

== Topologi

#diagram(```
   BOARD #1                        BOARD #2
┌──────────────┐      BLE      ┌──────────────┐
│   ESP32-H2   │◄────────────►│   ESP32-H2   │
│  DevKitM-1   │  Connection   │  DevKitM-1   │
│   Node 1     │               │   Node 2     │
│ (Peripheral/ │               │  (Central/   │
│  Advertiser) │               │   Scanner)   │
└──────────────┘               └──────────────┘
   env: node1                      env: node2
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Identitas radio]),
    [Node 1], [ESP32-H2 DevKitM-1], [`node1`], [BLE Peripheral (advertise)], [`NODE1_H2`],
    [Node 2], [ESP32-H2 DevKitM-1], [`node2`], [BLE Central (scan dan connect)], [`NODE2_H2`],
  ),
  [Peran dan identitas radio tiap node Modul 01],
  "tbl:m01-topologi",
)

Service UUID kedua node: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) dengan PlatformIO dan
pustaka NimBLE-Arduino.

#tbl(
  table(
    columns: (auto, 1fr, 1.3fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1], [2],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [3], [PC/Laptop], [PlatformIO Core/IDE, 2 port USB bebas], [1],
    [4], [Library NimBLE-Arduino], [`h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps`], [---],
    [5], [Platform PlatformIO], [pioarduino `espressif32` 55.03.311 (Arduino core 3.3.11)], [---],
    [6], [nRF Connect (opsional)], [Android/iOS --- _cross-check_ paket advertising], [1],
  ),
  [Alat dan bahan Modul 01],
  "tbl:m01-alat",
)

== Kode Program

#sumber-kode("week01_ble_p2p",
  ("platformio.ini", "src/node1/main.cpp", "src/node2/main.cpp"))

*Kunci agar dua board tidak salah flash.* Dengan dua ESP32-H2 terpasang
bersamaan, auto-detect port bisa mengirim firmware `node1` ke board yang
dimaksudkan sebagai `node2`. Pin port tiap environment, dan gunakan
`build_src_filter` untuk memilih source per node seperti pada
@lst:m01-ini-readme.

#kode(```ini
[env]
platform = https://github.com/pioarduino/platform-espressif32/releases/download/55.03.311/platform-espressif32.zip
framework = arduino
board = esp32-h2-devkitm-1
monitor_speed = 115200
lib_deps = h2zero/NimBLE-Arduino@^2.2.3

[env:node1]
build_src_filter = +<node1/*.cpp>   ; memilih src/node1/main.cpp
upload_port  = /dev/ttyACM0         ; Windows: COM3 -- board Node1
monitor_port = /dev/ttyACM0

[env:node2]
build_src_filter = +<node2/*.cpp>   ; memilih src/node2/main.cpp
upload_port  = /dev/ttyACM2         ; Windows: COM4 -- board Node2
monitor_port = /dev/ttyACM2
```.text,
  [`platformio.ini` dengan port yang dipin per environment],
  "lst:m01-ini-readme",
  bahasa: "ini",
)

Berkas `platformio.ini` pada repositori praktikum (@lst:m01-ini) tidak memin
`upload_port`, sehingga port dipilih lewat opsi `--upload-port` pada perintah
`pio run`. Gunakan salah satu cara, jangan keduanya sekaligus.

#kode-berkas("week01_ble_p2p/platformio.ini",
  [`platformio.ini` Modul 01 pada repositori],
  "lst:m01-ini",
)

#kode-berkas("week01_ble_p2p/src/node1/main.cpp",
  [`src/node1/main.cpp` --- BLE Peripheral `NODE1_H2`],
  "lst:m01-node1",
  pecah: true,
)

#kode-berkas("week01_ble_p2p/src/node2/main.cpp",
  [`src/node2/main.cpp` --- BLE Central `NODE2_H2`],
  "lst:m01-node2",
  pecah: true,
)

== Build dan Flash

#keluaran("pio device list                                  # catat port dulu
pio run -d week01_ble_p2p -e node1 -t upload
pio run -d week01_ble_p2p -e node2 -t upload -t monitor")

#penting[
  *Pilih port USB-to-UART, bukan USB native.* Setiap board ESP32-H2 muncul
  sebagai *dua* port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan
  USB-Serial/JTAG bawaan chip (`303a:1001`). Proses flash pada lab ini memakai
  *jembatan UART*, karena jalur itulah yang tersambung ke rangkaian _auto
  program_ (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan
  tombol. Pada Linux keduanya berselang-seling: port *genap* adalah UART, port
  *ganjil* adalah USB native. Dengan demikian satu board memakai
  `/dev/ttyACM0`, dua board memakai `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga
  board memakai `/dev/ttyACM0`, `/dev/ttyACM2`, dan `/dev/ttyACM4`. Verifikasi
  dengan `pio device list` dan pilih port ber-Hardware ID `1A86:55D3`.
]

*Pre-flight checklist*

#checklist((
  [Jalankan `pio device list`, catat port tiap board, isi
   `upload_port`/`monitor_port` di atas.],
  [Board ESP32-H2 pertama terhubung (akan diflash `node1`), board kedua
   terhubung (`node2`).],
  [Toolchain PlatformIO siap; firmware `node1` dan `node2` berhasil build tanpa
   galat.],
  [Serial Monitor 115200 baud dibuka *lebih dulu*, lalu tekan RESET agar
   sekuens boot terekam.],
))

== Percobaan

=== EXP-01 --- Advertising dan Scanning

Node1 advertise sebagai `NODE1_H2` membawa Service UUID. Node2 melakukan active
scan 5 detik dan mencetak hasil temuan beserta RSSI.

#diagram(```
Node1: [ADV] "NODE1_H2" + SERVICE_UUID
                 │
                 ▼
Node2: Scan 5 detik ──► onResult() ──► nama cocok? ──► stop scan
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama device yang ditemukan], [#isian],
    [Service UUID pada paket advertising], [#isian],
    [RSSI saat ditemukan (dBm)], [#isian],
    [Waktu scanning (detik)], [#isian],
    [MAC address Node1 (jika ada)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m01-exp01",
)

#buka-abstraksi[
  Sebelum lanjut, pindai `NODE1_H2` menggunakan nRF Connect dan amati isi paket
  advertising: Device Name, Service UUID, dan flags. Cocokkan tiap field dengan
  baris di `src/node1/main.cpp` --- baris kode mana yang menyetel
  masing-masing? Ini menghubungkan API NimBLE dengan byte yang benar-benar
  mengudara.
]

#checkpoint[
  Node2 mencetak `Node1 ditemukan` dan sebuah nilai RSSI. Jika tidak: pastikan
  board `node1` menyala dan filter nama di `ScanCallbacks` Node2 benar.
]

=== EXP-02 --- Pembentukan Tautan

Setelah Node1 ditemukan, Node2 menjalankan alur koneksi. Verifikasi tiap tahap
di Serial Monitor kedua node.

#diagram(```
Scan ──► Node1 ditemukan ──► Connect ──► Service check ──► Connected
```.text)

*Expected output --- Node1 (`NODE1_H2`)*

#keluaran("Node1 (BLE Peripheral) starting...
Advertise sebagai NODE1_H2, menunggu Node2...
Node2 terhubung (link P2P aktif)
Status: H2 <-> H2 terhubung")

*Expected output --- Node2 (`NODE2_H2`)*

#keluaran("Node2 (BLE Central) starting...
Scanning Node1...
Node1 ditemukan
Terhubung ke Node1
Koneksi berhasil
Status: H2 <-> H2 terhubung | RSSI: -57 dBm")

#checkpoint[
  Kedua node mencetak baris `Status: ... terhubung` berulang tiap 5 detik, dan
  baris Node2 menyertakan nilai RSSI.
]

=== EXP-03 --- Ketahanan Tautan

Modul ini belum mempertukarkan payload aplikasi. Uji ketahanan tautan dan amati
perilaku dua arahnya.

+ *Reset Node1* --- Node2 mencetak `Terputus dari Node1` setelah supervision
  timeout (± 2--3 detik), lalu berhenti mencetak status. Node1 hanya mencetak
  banner boot-nya, bukan `Node2 terputus`, karena baru restart.
+ *Reset Node2* --- Node1 mencetak `Node2 terputus, mulai advertise ulang`,
  lalu `Node2 terhubung` saat Node2 selesai boot dan scan lagi. Ini
  satu-satunya skenario yang memicu `onDisconnect` di Node1.
+ *Reconnect* --- biarkan Node2 jalan, restart Node1: koneksi tidak terbentuk
  sendiri karena Node2 hanya scan sekali (5 detik) di `setup()`. Node2 perlu
  di-reset. Hal ini akan diperbaiki di CH-4.
+ *Filter test* --- ubah filter nama di `ScanCallbacks` Node2, amati Node2 tak
  lagi menemukan Node1, lalu kembalikan kode.

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Waktu rata-rata scan sampai ditemukan (ms)], [#isian],
    [Pesan saat disconnect pada Node1], [#isian],
    [Pesan saat disconnect pada Node2], [#isian],
    [Interval cetak status (ms)], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m01-exp03",
)

#checkpoint[
  Praktikan dapat menjelaskan mengapa reset Node1 dan reset Node2 memicu pesan
  yang berbeda --- itu bukti tautan diamati dari dua sisi.
]

== Pengukuran

RSSI dibaca dari log Node2 sendiri, bukan aplikasi luar. Tambahkan cetak RSSI
koneksi pada heartbeat Node2 seperti @lst:m01-rssi.

#kode(```cpp
// Node2 - loop(), cetak tiap 5000 ms saat terhubung
if (pClient && pClient->isConnected()) {
  Serial.printf("Status: H2 <-> H2 terhubung | RSSI: %d dBm\n",
                pClient->getRssi());
}
```.text,
  [Cetak RSSI koneksi pada heartbeat Node2],
  "lst:m01-rssi",
)

nRF Connect boleh dipakai sebagai _cross-check_ opsional. Gunakan
@tbl:m01-referensi-rssi untuk menilai kualitas tautan.

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
    [< −95], [Tidak reliable --- koneksi sering gagal],
  ),
  [Referensi interpretasi RSSI],
  "tbl:m01-referensi-rssi",
)

Ukur pada beberapa jarak, diisi dari Serial Monitor Node2
(@tbl:m01-jarak-rssi).

#tbl(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Jarak], th[RSSI (dBm)], th[Latency koneksi (ms)], th[Success (ya/tidak)]),
    [1 m], [#isian], [], [],
    [3 m], [#isian], [], [],
    [5 m], [#isian], [], [],
    [10 m], [#isian], [], [],
    [15 m], [#isian], [], [],
  ),
  [Lembar pengukuran jarak, RSSI, dan keberhasilan koneksi],
  "tbl:m01-jarak-rssi",
)

Metrik turunan: latency rata-rata scan sampai connected, dan ambang RSSI saat
koneksi mulai gagal.

== Analisis

Jawab berdasarkan tabel bagian Pengukuran, bukan berdasarkan teori saja.

+ Bagaimana pengaruh jarak terhadap nilai RSSI?
+ Pada nilai RSSI berapa koneksi mulai gagal? Bandingkan dengan tabel
  referensi.
+ Berapa latency rata-rata dari scan sampai connected (ms)?
+ Apakah halangan (tembok atau tubuh) memengaruhi keberhasilan koneksi?
+ Apakah BLE P2P cocok untuk aplikasi yang butuh koneksi cepat dan hemat daya?
  Jelaskan dari data hasil pengukuran.

== Concept Check

+ Apa perbedaan Peripheral dan Central pada BLE?
+ Apa saja yang dimuat dalam paket advertising?
+ Apa beda active scan dan passive scan?
+ Mengapa Node1 harus advertise ulang setelah Node2 disconnect?
+ Apa fungsi Service UUID dalam koneksi BLE?

== Challenge (Tugas Modifikasi)

Modifikasi kode, bukan sekadar menjelaskan hasil.

#tujuan-prak(2, [Memperkuat dan mengukur tautan])[
  / CH-1 --- Interval heartbeat: Ubah interval heartbeat dari 5000 ms ke
    1000 ms; amati dampaknya pada keterbacaan log dan beban.

  / CH-2 --- Indikator koneksi: Tambahkan LED pada Node1 yang menyala saat ada
    Central terhubung.

  / CH-3 --- Latency koneksi: Ukur waktu dari Node2 start sampai
    `Koneksi berhasil` menggunakan `millis()`, 5 percobaan, lalu hitung
    rata-ratanya.
]

#tujuan-prak(3, [Tautan yang memulihkan diri])[
  / CH-4 --- Self-healing: Buat Node2 melakukan scan ulang otomatis saat
    `onDisconnect` agar tautan _self-healing_ (fondasi robustness untuk M04 dan
    M05), seperti pada @lst:m01-ch4.
]

#kode(```cpp
// CH-4 - di ClientCallbacks::onDisconnect(), picu scan ulang
void onDisconnect(NimBLEClient* c, int reason) override {
  Serial.println("Terputus - scan ulang...");
  NimBLEDevice::getScan()->start(5000, false);
}
```.text,
  [Kerangka CH-4 --- scan ulang otomatis saat terputus],
  "lst:m01-ch4",
)

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori secara ringkas.
+ Konfigurasi --- `platformio.ini`, environment, dan UUID.
+ Hasil eksperimen --- log Serial Monitor kedua node (EXP-01 sampai EXP-03
  beserta checkpoint).
+ Data pengukuran --- tabel bagian Pengukuran.
+ Analisis dan concept check.
+ Challenge --- termasuk CH-4.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
