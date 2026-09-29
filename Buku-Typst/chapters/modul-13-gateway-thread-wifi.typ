// ============================================================================
// Modul 13 — Gateway Thread → Wi-Fi (H2 + C6)
// Sumber: week13_thread_wifi_gateway/README.md; listing kode dibaca langsung
//         dari assets/code/week13_thread_wifi_gateway/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter(
  "Modul 13 — Gateway Thread ke Wi-Fi (H2 + C6)",
  l: "bab:modul-13",
)

#identitas-modul(
  "Modul 13",
  [Bridge Thread to Wi-Fi --- Gateway Thread ke Wi-Fi (H2 + C6)],
  [ESP32-H2 + ESP32-C6 · Thread ke HTTP · level Advanced · 3 × 50 menit ·
   folder kode `week13_thread_wifi_gateway`],
)

#pengantar([Gambaran Umum])[
Modul 13 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut.
Misinya menjembatani dua radio dalam satu perangkat dan membawa data sensor
keluar ke jaringan IP. Percobaan berjalan dalam mode gateway dwi-radio, diamati
melalui dua terminal Serial Monitor pada 115200 baud beserta kode respons HTTP
sebagai bukti data benar-benar sampai.
]

== Pendahuluan

Sampai M12 data tidak pernah keluar dari jaringan 802.15.4. Modul ini adalah
*titik keluar*: ESP32-C6 menjalankan dua stack sekaligus dan meneruskan payload
apa adanya ke server HTTP. Ini juga modul pertama yang benar-benar membutuhkan
*dua jenis board* --- sebuah batasan perangkat keras, bukan firmware.

Prasyaratnya ada dua: M11--M12 untuk Active Dataset, mesh-local prefix, dan UDP
multicast; serta M04 dan M06 untuk konsep transparent forwarding. Yang dibangun
di sini adalah gateway dwi-radio yang menjalankan Thread dan Wi-Fi bersamaan,
penerusan UDP menjadi HTTP POST, pemakaian tabel partisi `huge_app.csv`, dan
penanganan saat Wi-Fi terputus. Semuanya dipakai lagi pada M14 ketika sisi IP
diganti MQTT tanpa Thread, M15 ketika kedua sisi digabung menjadi pipeline
penuh, dan M16 ketika arsitektur gateway dipakai untuk membandingkan protokol.

*Peta modul blok integrasi*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [11--12], [Thread: IPv6 dan mesh --- data masih di dalam 802.15.4],
    [*13 (ini)*], [*Gateway: Thread bertemu Wi-Fi, data keluar ke IP (HTTP)*],
    [14], [Sisi IP diperdalam: MQTT publish/subscribe di C6],
    [15], [M12, M13, dan M14 digabung: sensor ke Thread ke C6 ke MQTT ke dashboard],
  ),
  [Peta modul blok integrasi],
  "tbl:m13-peta",
)

*Kontrak data lab ini.* Payload `suhu:XX.X` diteruskan *tanpa diubah* dari
Thread ke HTTP; gateway hanya membungkusnya dalam JSON. Prinsip ini
(_transparent forwarding_, sama seperti relay M06) membuat M15 bisa mengganti
HTTP dengan MQTT tanpa menyentuh firmware node sensor sama sekali.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Menjembatani Thread dan Wi-Fi dalam satu perangkat])[
  + Mengonfigurasi satu ESP32-C6 sebagai Thread Leader *dan* Wi-Fi STA secara
    bersamaan, serta menunjukkan urutan inisialisasi keduanya di kode.
  + Menerima datagram UDP multicast Thread dari node ESP32-H2 di sisi gateway
    dan menampilkan alamat sumbernya.
  + Meneruskan payload ke server HTTP dan memverifikasi keberhasilannya dari
    kode respons (HTTP 200).
  + Menghitung packet loss pada dua hop terpisah --- Thread (H2 ke C6) dan
    Wi-Fi/HTTP (C6 ke server) --- dan menentukan hop mana yang menjadi penyebab
    bila ada data hilang.
]

*Kriteria keberhasilan*

#checklist((
  [Pesan `suhu:XX.X` dari H2 tiba di server HTTP dengan status *HTTP 200*.],
  [Latency end-to-end terukur pada tiga skenario jarak.],
  [Packet loss Thread ke gateway terhitung terpisah dari loss Wi-Fi ke
   server.],
  [Perilaku saat Wi-Fi diputus diuji dan tercatat.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (Thread
Border Router penuh, SRP/DNS-SD, NAT64, koeksistensi radio) berada di buku
teori terpisah. Istilah kerja dirangkum pada @tbl:m13-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Gateway], [Perangkat yang menghubungkan dua jaringan berbeda protokol (Thread dan Wi-Fi) dan meneruskan data antar keduanya.],
    [Border Router], [Router tepi jaringan Thread yang menyediakan konektivitas ke jaringan IP eksternal --- C6 di sini berfungsi sebagai versi sederhananya.],
    [Thread Leader], [Perangkat Thread yang mengelola dataset aktif jaringan.],
    [UDP Multicast], [Pesan dikirim ke grup IPv6 `ff03::abcd` port 5050 sehingga semua anggota grup menerimanya.],
    [Wi-Fi STA], [Mode station: C6 bergabung ke access point dan memperoleh alamat IP.],
    [HTTP POST], [Pengiriman data ke server; payload dibungkus JSON `{"sensor":"h2","data":"..."}`.],
    [`huge_app.csv`], [Tabel partisi besar; firmware Thread, Wi-Fi, dan HTTP melebihi partisi app default 1,25 MB.],
  ),
  [Istilah kerja Modul 13],
  "tbl:m13-istilah",
)

*Mengapa H2 dan C6 wajib memakai prefix mesh-local yang sama.*
`DataSet::initNew()` mengacak network key, ext PAN ID, dan *prefix mesh-local*
di tiap board. Kedua firmware karena itu menimpa field-field tersebut dengan
konstanta dan memaksa prefix lewat `otThreadSetMeshLocalPrefix()` sebelum
`OThread.start()` (@lst:m13-prefix).

#kode(```cpp
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] =
    {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};   // fdde:ad00:beef::/64
```.text,
  [Prefix mesh-local yang wajib identik di H2 dan C6],
  "lst:m13-prefix",
)

Tanpa itu H2 dan C6 tetap attach dan Serial Monitor keduanya tampak sehat,
tetapi gateway tidak pernah mencetak satu pun baris `RX via Thread` --- paket
multicast `ff03::abcd` tidak diteruskan antar prefix mesh-local yang berbeda.
Pemeriksaan cepat: awalan Mesh-Local EID kedua board harus sama persis.

*Sekuens protokol yang diamati*

#diagram(```
[ H2 sensor ] ──(Thread UDP)──► [ C6 gateway ] ──(HTTP POST JSON)──► [ Server ]
   readSensor      OtUdp            parsePacket       HTTPClient
   "suhu:25.3"     multicast        forwardToWifi()   http.POST()
```.text)

== Topologi

#diagram(```
    BOARD #1 (H2)                        BOARD #2 (C6)
+-----------------+   Thread / 802.15.4   +------------------+     Wi-Fi / HTTP      +---------------+
|    ESP32-H2     | --------------------> |    ESP32-C6      | --------------------> | Server HTTP   |
|   DevKitM-1     |  "suhu:XX.X" ke       |   DevKitC-1      |  POST JSON            | (httpbin.org) |
|  node sensor    |  ff03::abcd:5050      | gateway Thread + |  {sensor,data}        +---------------+
|  env: h2_node   |  ch 15, PAN 0xABCD    | Wi-Fi STA        |
+-----------------+                       | env: c6_gateway  |
                                          +------------------+
   radio: 802.15.4 saja                     radio: 802.15.4 + Wi-Fi 2,4 GHz
   ML prefix fdde:ad00:beef::/64            ML prefix fdde:ad00:beef::/64
```.text, rapat: true)

#tbl(
  table(
    columns: (auto, auto, auto, 1fr, 1.2fr),
    align: (left, left, left, left, left),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran], th[Aksi]),
    [Node sensor], [*ESP32-H2* DevKitM-1], [`h2_node`], [Thread node (Child)],
    [TX `suhu:XX.X` multicast tiap 3 s],
    [Gateway], [*ESP32-C6* DevKitC-1], [`c6_gateway`], [Thread Leader dan Wi-Fi STA],
    [RX Thread lalu HTTP POST],
  ),
  [Peran tiap node Modul 13],
  "tbl:m13-topologi",
)

*Inilah modul pertama yang benar-benar butuh dua jenis board.* ESP32-H2 punya
radio 802.15.4 tetapi *tidak punya Wi-Fi*; ESP32-C6 punya keduanya, sehingga
hanya C6 yang bisa memegang kaki Thread dan kaki Wi-Fi sekaligus. Menukar peran
(H2 sebagai gateway) tidak mungkin --- bukan soal firmware, tetapi soal radio
yang tersedia di chip. Karena itu `platformio.ini` modul ini memakai `board`
berbeda per environment (`esp32-h2-devkitm-1` dibanding
`esp32-c6-devkitc-1`), tidak seperti Modul 01--12 yang seragam ESP32-H2.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (node Thread) dan ESP32-C6 (gateway
Thread dan Wi-Fi).

#tbl(
  table(
    columns: (auto, 1fr, 1.7fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1 --- node sensor Thread], [1],
    [2], [Board ESP32-C6], [DevKitC-1 --- gateway Thread ke Wi-Fi], [1],
    [3], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [4], [PC/Laptop], [PlatformIO Core/IDE, 2 port USB bebas], [1],
    [5], [Wi-Fi atau hotspot], [2,4 GHz, ada akses internet (C6 tidak mendukung 5 GHz)], [1],
    [6], [Server HTTP tujuan], [default `http://httpbin.org/post`, atau server lokal (`http_sink.py`)], [1],
  ),
  [Alat dan bahan Modul 13],
  "tbl:m13-alat",
)

*Konfigurasi jaringan*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Nilai]),
    [Thread network], [`ESP_OT_GW`, channel 15, PAN `0xABCD`],
    [Mesh-local prefix], [`fdde:ad00:beef::/64` (identik di H2 dan C6)],
    [Grup multicast dan port], [`ff03::abcd` : 5050],
    [Interval telemetri], [3000 ms],
    [Topic atau URL tujuan], [`SERVER_URL` di `src/c6_gateway/main.cpp`],
  ),
  [Konfigurasi jaringan Modul 13],
  "tbl:m13-konfig",
)

== Kode Program

#sumber-kode("week13_thread_wifi_gateway",
  ("platformio.ini", "http_sink.py", "src/h2_node/main.cpp",
   "src/c6_gateway/main.cpp"))

*Dua board berbeda dalam satu proyek* (@lst:m13-ini-readme).

#kode(```ini
[env:h2_node]
board = esp32-h2-devkitm-1
build_src_filter = +<h2_node/*.cpp>
upload_port  = /dev/ttyACM0

[env:c6_gateway]
board = esp32-c6-devkitc-1
board_build.partitions = huge_app.csv    ; firmware Thread+Wi-Fi+HTTP > 1,25 MB
build_src_filter = +<c6_gateway/*.cpp>
upload_port  = /dev/ttyACM2
```.text,
  [Potongan `platformio.ini` --- dua jenis board dalam satu proyek],
  "lst:m13-ini-readme",
  bahasa: "ini",
)

#kode-berkas("week13_thread_wifi_gateway/platformio.ini",
  [`platformio.ini` Modul 13 pada repositori],
  "lst:m13-ini",
)

#kode-berkas("week13_thread_wifi_gateway/src/h2_node/main.cpp",
  [`src/h2_node/main.cpp` --- node sensor Thread di ESP32-H2],
  "lst:m13-h2",
  pecah: true,
)

#kode-berkas("week13_thread_wifi_gateway/src/c6_gateway/main.cpp",
  [`src/c6_gateway/main.cpp` --- gateway dwi-radio di ESP32-C6],
  "lst:m13-c6",
  pecah: true,
)

=== Server HTTP Lokal --- `http_sink.py`

Bila `httpbin.org` terblokir (gejala di Serial Monitor: `HTTP -1`), gunakan
server HTTP lokal yang sudah disertakan di folder modul ini
(@lst:m13-http-sink). Server ini mendengarkan POST di `0.0.0.0:8080`, mencetak
tiap POST yang masuk dengan timestamp, lalu membalas HTTP 200 beserta JSON ---
berfungsi sebagai pengganti `httpbin.org` sekaligus bukti bahwa hop Wi-Fi/HTTP
benar-benar sampai.

#kode-berkas("week13_thread_wifi_gateway/http_sink.py",
  [`http_sink.py` --- server HTTP lokal penerima POST],
  "lst:m13-http-sink",
  pecah: true,
)

#keluaran("# 1. cari IP laptop di Wi-Fi yang sama dengan board
ip -4 addr show | grep inet        # mis. 192.168.1.5

# 2. jalankan server (dengar di 0.0.0.0:8080)
python3 http_sink.py")

Arahkan `SERVER_URL` di `src/c6_gateway/main.cpp` ke IP laptop.

#kode(```cpp
const char *SERVER_URL = "http://192.168.1.5:8080/post";
```.text,
  [Mengarahkan gateway ke server HTTP lokal],
  "lst:m13-url",
)

Contoh keluaran setiap POST yang sampai:

#keluaran("[   0.000] http_sink siap di 0.0.0.0:8080 (POST -> HTTP 200)
[ 480.308] #1    POST /post from 192.168.1.39  ->  {\"sensor\":\"h2\",\"data\":\"suhu:23.1\"}")

#catatan[
  Karena hop Wi-Fi/HTTP di gateway dwi-radio ini paling rapuh (koeksistensi
  Thread dan Wi-Fi), sebagian besar POST bisa tercetak `HTTP -1` di Serial
  Monitor sedangkan server tidak menerima apa pun. Tugas pada modul ini
  menghitung berapa `RX via Thread` yang berhasil sampai ke server (lihat
  bagian Pengukuran).
]

== Build dan Flash

#keluaran("pio run -d week13_thread_wifi_gateway -e c6_gateway -t upload -t monitor
pio run -d week13_thread_wifi_gateway -e h2_node    -t upload")

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
  [ESP32-H2 dan ESP32-C6 terhubung ke PC via kabel USB, port dicatat lewat
   `pio device list`.],
  [`WIFI_SSID`, `WIFI_PASS`, dan `SERVER_URL` pada `src/c6_gateway/main.cpp`
   sudah disesuaikan.],
  [Hotspot atau Wi-Fi *2,4 GHz* aktif dan kedua board berada dalam jangkauan
   sinyal.],
  [Server HTTP tujuan dapat diakses (cek `httpbin.org` dari browser, atau
   jalankan `python3 http_sink.py` untuk server lokal).],
  [Firmware `h2_node` dan `c6_gateway` berhasil di-build.],
  [Env gateway memakai `board_build.partitions = huge_app.csv`.],
  [Serial Monitor 115200 dibuka untuk masing-masing board.],
))

== Percobaan

=== EXP-01 --- Menyalakan Jaringan Thread

Deploy firmware `h2_node` ke ESP32-H2 dan `c6_gateway` ke ESP32-C6. Kedua board
memakai dataset Thread identik. Gateway menjadi Leader, node menunggu hingga
role mencapai Child.

#diagram(```
+--------+   dataset sama: ESP_OT_GW / ch15 / 0xABCD   +----------+
|   H2   | <------------- attach as Child ------------>|    C6    |
| (node) |                                             | (leader) |
+--------+                                             +----------+
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1.1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Nama jaringan Thread], [#isian],
    [Channel dan PAN ID], [#isian],
    [Role H2 setelah attach], [#isian],
    [Role C6 setelah attach], [#isian],
    [Awalan Mesh-Local EID H2 dan C6 sama?], [… (harus `fdde:ad00:beef:0:`)],
    [Waktu hingga attach (± detik)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m13-exp01",
)

#checkpoint[
  Kedua board mencetak `Attached as: ...` *dan* awalan EID keduanya sama. Jika
  berbeda, gateway tidak akan pernah menerima apa pun meski keduanya tampak
  "terhubung" --- perbaiki dulu.
]

=== EXP-02 --- Telemetri lewat Thread

Setelah attach, H2 mengirim `suhu:XX.X` ke grup multicast tiap 3 detik. Amati
pasangan TX dan RX pada kedua Serial Monitor.

#diagram(```
[H2 loop] ──tiap 3 s──► OtUdp.beginPacket(GROUP,5050) ──► "TX via Thread: suhu:25.3"
[C6 loop] ────────────► OtUdp.parsePacket()           ──► "RX via Thread [<EID sumber>]: suhu:25.3"
```.text, rapat: true)

Alamat yang tercetak gateway adalah `OtUdp.remoteIP()` --- mesh-local EID *node
pengirim* (`fdde:ad00:...`), bukan alamat grup `ff03::abcd` yang dituju.

*Expected output --- H2* (dari uji di board; alamat, peran, dan IP di board
Anda akan berbeda)

#keluaran("Sensor H2 (Thread node) starting...
Menunggu join ke gateway (C6)...
Attached as: Leader        <- bisa juga Child, tergantung urutan boot
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_GW
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C00
  Extended addr  : D6:48:6C:1E:E0:BC:16:6B
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:7c1b:2b3:3487:1195
TX via Thread: suhu:24.4
TX via Thread: suhu:25.0")

*Expected output --- C6*

#keluaran("Konek Wi-Fi SprH-3......
Wi-Fi OK, IP: 192.168.1.109 | RSSI: -63 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Child
Default netif dikembalikan ke Wi-Fi STA (err=0)
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_GW
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C01
  Extended addr  : BE:21:63:FE:AC:75:5F:60
  EUI-64         : 40:4C:CA:FF:FE:5E:C5:40
  Mesh-Local EID : fdde:ad00:beef:0:15c:9037:1e71:3135
Info network Wi-Fi:
  SSID           : SprH-3
  IP             : 192.168.1.109
  RSSI           : -64 dBm
  Channel Wi-Fi  : 8
  BSSID (AP)     : 24:C0:13:CB:4B:27
  MAC            : 40:4C:CA:5E:C5:40
Gateway siap (Thread -> Wi-Fi).
SIM sensor (Thread): suhu:25.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1", pecah: true)

Baris `SIM sensor (Thread): ...` berasal dari simulasi sensor di firmware
gateway (`readSensor()`), yang memanggil jalur `forwardToWifi()` yang sama
dengan data Thread asli; baris `RX via Thread [...]` adalah telemetri H2 yang
sebenarnya.

#catatan[
  *Membaca info network.* Kedua board harus sama pada *Network name, Channel,
  PAN ID, dan Extended PAN ID* Thread. Peran dipilih jaringan: pada uji ini H2
  attach lebih dulu dan menjadi *Leader* (`RLOC16 0x6C00`), gateway C6 menjadi
  *Child*-nya (`0x6C01`) --- gateway tidak harus Leader. Dua hal khusus modul
  ini:

  - *EUI-64 C6 diturunkan dari MAC Wi-Fi-nya*: MAC `40:4C:CA:5E:C5:40` →
    EUI-64 `40:4C:CA:FF:FE:5E:C5:40` (disisipi `FF:FE` di tengah). Satu chip,
    satu identitas pabrik untuk kedua radio.
  - *Channel Wi-Fi vs channel Thread.* Wi-Fi memakai channel AP (di sini 8,
    ±2447 MHz), Thread channel 15 (2425 MHz). Walau frekuensinya tidak
    bertumpuk, keduanya tetap *berbagi satu radio dan satu antena* di C6 ---
    itu sumber masalah koeksistensi, bukan tumpang tindih frekuensi.
]

#catatan[
  *Mengapa banyak telemetri H2 hilang.* Pada rekaman ini `SERVER_URL` tidak
  menunjuk ke server yang hidup, sehingga setiap `http.POST()` gagal
  (`HTTP -1`) setelah timeout ±8 s. Selama itu `loop()` gateway tertahan dan
  tidak membaca socket UDP: hanya satu paket yang tertampung, sisanya dibuang.
  Hasilnya hanya 8 dari 22 telemetri H2 yang tercetak `RX via Thread`,
  masing-masing tertunda beberapa detik. Kehilangan ini terjadi di *aplikasi
  gateway*, bukan di radio Thread --- hop Thread-nya sendiri sehat. Jalankan
  `http_sink.py` dan arahkan `SERVER_URL` ke IP laptop untuk melihat
  perbedaannya.
]

#buka-abstraksi[
  Perhatikan urutan di `setup()` gateway: `OThread.begin()` dulu, lalu Wi-Fi,
  baru `OThread.start()`. Coba dua variasi, flash, dan catat gejalanya
  masing-masing.

  + Pindahkan blok Wi-Fi ke paling atas, maka board *panic*
    (`Failed to create OpentThread event loop`, lalu
    `assert failed: otTaskletsSignalPending`).
  + Pindahkan blok Wi-Fi ke bawah `OThread.start()`, maka board hidup tetapi
    Wi-Fi *tidak pernah* asosiasi (`status=6` terus).

  Telusuri sebab pertama hingga menemukan `esp_event_loop_create_default()`:
  siapa yang membuatnya lebih dulu, dan mengapa satu stack menerima kondisi
  "sudah ada" sedangkan yang lain menganggapnya fatal? Untuk yang kedua,
  kaitkan dengan _radio coexistence_: kedua radio berbagi satu antena
  2,4 GHz.
]

#checkpoint[
  Jumlah baris `TX via Thread` di H2 dan `RX via Thread` di C6 harus sama dalam
  periode pengamatan yang sama. Selisihnya adalah loss hop Thread --- catat,
  jangan diabaikan.
]

=== EXP-03 --- Penerusan ke Wi-Fi (HTTP POST)

Setiap pesan yang diterima diteruskan gateway ke `SERVER_URL` sebagai JSON
`{"sensor":"h2","data":"suhu:XX.X"}` dengan header
`Content-Type: application/json`. Verifikasi kode respons HTTP (200 berarti
sukses). Biarkan sistem berjalan 2--3 menit.

#diagram(```
"RX via Thread" ──► forwardToWifi(buf) ──► HTTPClient ──► http.POST(JSON)
                ──► "Forward via Wi-Fi ... | HTTP 200"
```.text)

#keluaran("Forward via Wi-Fi -> http://httpbin.org/post | HTTP 200")

Variasi wajib: *matikan hotspot ± 15 detik* saat sistem berjalan. Amati baris
`Wi-Fi terputus, skip forward` dan catat apakah data Thread yang datang selama
itu hilang atau tertahan.

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [IP Wi-Fi gateway], [#isian],
    [URL server tujuan], [#isian],
    [HTTP status code yang diterima], [#isian],
    [RSSI Wi-Fi gateway (`WiFi.RSSI()`)], [#isian],
    [Paket Thread diterima dibanding di-POST (2 menit)], [#isian],
    [Nasib data saat Wi-Fi putus], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m13-exp03",
)

#checkpoint[
  Tersedia *tiga* angka untuk periode yang sama: paket dikirim H2, paket
  diterima C6, dan POST berhasil (HTTP 200). Selisih antar ketiganya
  menunjukkan hop mana yang bermasalah --- inilah yang membedakan laporan yang
  bisa dipertanggungjawabkan dari sekadar "sistem berjalan".
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada *ESP32-H2 DevKitM-1* dan *ESP32-C6 DevKitC-1* asli.

#keluaran("# H2 (env h2_node)                # C6 (env c6_gateway)
[0.401] Sensor H2 starting...     [2.004] Konek Wi-Fi ...
[1.203] Attached as: Router       [2.004] Wi-Fi OK, IP: 192.168.110.197 | RSSI: -83 dBm
[3.407] TX via Thread: suhu:25.6  [2.805] Thread attached as: Router
                                  [2.805] Default netif dikembalikan ke Wi-Fi STA (err=0)
                                  [3.406] RX via Thread [fdde:ad00:beef:0:385a:...]: suhu:25.6
                                  [8.413] Forward via Wi-Fi -> ... | HTTP -1")

#tbl(
  table(
    columns: (1.5fr, 1.2fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Bagian rantai], th[Status]),
    [Build `h2_node` dan `c6_gateway` (`huge_app.csv`)], [berhasil],
    [C6 attach ke Thread `ESP_OT_GW`], [berhasil, 2,8 s sejak boot],
    [Telemetri `suhu:XX.X` H2 ke C6 lewat Thread], [berhasil, 13/13 paket, 0 % loss],
    [C6 asosiasi Wi-Fi sambil Thread jalan], [berhasil, 2,0 s (setelah perbaikan urutan)],
    [HTTP POST ke server], [sampai di server, tetapi balasan sering timeout (`HTTP -11`)],
    [Penanganan Wi-Fi gagal], [berhasil, `setup()` lanjut dan dicoba ulang berkala di `loop()`],
  ),
  [Hasil verifikasi hardware Modul 13],
  "tbl:m13-verifikasi",
)

=== Koeksistensi Wi-Fi dan 802.15.4

Gateway ini menjalankan dua radio pada satu antena 2,4 GHz. Tanpa penanganan
khusus, C6 tetap asosiasi Wi-Fi dan dapat IP yang benar, tetapi *seluruh TCP
keluar gagal* --- bahkan ke router sendiri.

#keluaran("diag: status=3 rssi=-82 ip=... gw=...
diag: tcp ke router = 0 (4002 ms)     <- paket tidak lewat sama sekali")

Dua hal yang menyelesaikannya, keduanya sudah ada di kode: *urutan
inisialisasi* --- Wi-Fi disambungkan di antara `OThread.begin()` dan
`OThread.start()`; serta *prioritas radio ke Wi-Fi* sebelum 802.15.4 aktif
seperti @lst:m13-coex.

#kode(```cpp
#include "esp_coexist.h"
esp_coex_preference_set(ESP_COEX_PREFER_WIFI);   // sebelum OThread.start()
```.text,
  [Memberi prioritas radio kepada Wi-Fi sebelum stack Thread aktif],
  "lst:m13-coex",
)

Setelah keduanya diterapkan, POST benar-benar sampai di server
(`{"sensor":"h2","data":"suhu:22.9"}` tercatat di server penerima). Namun hop
Wi-Fi tetap yang paling rapuh: *balasan* HTTP sering tidak kembali tepat waktu,
tercetak sebagai `HTTP -11` (read timeout) walaupun datanya sudah diterima
server. Karena itu `http.setConnectTimeout()` dan `setTimeout()` dinaikkan ke
8 detik.

*Yang sudah dicoba dan tidak menyelesaikan:* mengganti channel 802.15.4 (15
menjadi 25), memakai AP di kanal Wi-Fi yang tidak bertetangga,
`WiFi.setSleep()` kedua nilainya, dan memaksa default netif ke Wi-Fi STA.

*Cara membaca kegagalan HTTP*

#tbl(
  table(
    columns: (auto, 1fr, 1.4fr),
    align: (left, left, left),
    inset: (x: 0.55em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Kode], th[Arti], th[Tindakan]),
    [`200`], [POST diterima server], [---],
    [`-1`], [koneksi TCP gagal terbentuk],
    [periksa server terjangkau; bila server lokal, pastikan satu subnet],
    [`-11`], [request terkirim, *balasan* timeout],
    [perbesar `http.setTimeout()`; cek apakah data sudah masuk di sisi server],
  ),
  [Arti kode kegagalan HTTP pada gateway],
  "tbl:m13-http",
)

*Yang harus dilakukan praktikan:* catat RSSI Wi-Fi gateway, dan isi tabel loss
per hop di bagian Pengukuran dengan membandingkan `RX via Thread`, kode HTTP,
dan log di sisi server. Bila `RX via Thread` normal tetapi POST bocor, itu
bukan kegagalan praktikum --- itu justru data yang diminta bagian Analisis
nomor 1.

=== Delapan Perbaikan Kode yang Lahir dari Uji Ini

#tbl(
  table(
    columns: (1.3fr, 1.2fr),
    align: (left, left),
    inset: (x: 0.55em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Masalah di perangkat nyata], th[Perbaikan]),
    [C6 *panic* saat boot: `Failed to create OpentThread event loop` lalu `assert failed: otTaskletsSignalPending`],
    [`OThread.begin()` dipanggil *sebelum* Wi-Fi],
    [Wi-Fi tidak pernah asosiasi bila `OThread.start()` sudah jalan],
    [Wi-Fi disambungkan *di antara* `OThread.begin()` dan `OThread.start()`],
    [`while (WiFi.status() != WL_CONNECTED)` menggantung selamanya bila SSID atau password salah],
    [dibatasi `WIFI_TIMEOUT_MS`, `setup()` lanjut, dicoba ulang di `loop()`],
    [Gateway tidak pernah pulih setelah AP sempat mati],
    [`maintainWifi()` menyambung ulang berkala],
    [`WiFi.disconnect()` tiap percobaan ulang membatalkan asosiasi yang sedang berjalan],
    [hanya `WiFi.begin()` ulang, jeda `WIFI_RETRY_MS` lebih panjang dari durasi asosiasi],
    [Dua netif aktif (Wi-Fi dan OpenThread) tanpa default yang pasti],
    [`restoreWifiAsDefaultNetif()` memastikan rute IPv4 lewat Wi-Fi STA],
    [Seluruh TCP keluar gagal saat stack Thread aktif],
    [`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)` sebelum `OThread.start()`],
    [Balasan HTTP timeout (`HTTP -11`) padahal data sudah sampai server],
    [`http.setConnectTimeout(8000)` dan `http.setTimeout(8000)`],
  ),
  [Delapan perbaikan kode hasil pengujian perangkat nyata],
  "tbl:m13-perbaikan",
)

*Urutan inisialisasi yang benar* --- inilah hasil terpenting modul ini.

#diagram(```
1. OThread.begin(false)      // OT membuat event loop default
2. commit dataset + ML prefix
3. WiFi.mode()/begin()       // asosiasi selesai selagi radio 802.15.4 belum aktif
4. OThread.networkInterfaceUp() + OThread.start()
```.text)

Membalik langkah 1 dan 3 membuat board *panic*; menaruh langkah 3 setelah
langkah 4 membuat Wi-Fi *tidak pernah* asosiasi.


// Log serial lengkap dari week13_thread_wifi_gateway/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata. Baud 115200, gateway *ESP32-C6 DevKitC-1* dan node sensor *ESP32-H2 DevKitM-1*, firmware versi terbaru: setelah attach, kedua board mencetak info network Thread (peran, network name, channel, PAN ID, Extended PAN ID, RLOC16, Extended Address, EUI-64, Mesh-Local EID), dan gateway juga mencetak info Wi-Fi (SSID, IP, RSSI, channel, BSSID, MAC). Log direkam 90 detik dengan `monitor_serial.py` (kedua port dalam satu komputer, satu sumbu waktu) lewat port UART CH343 di Windows.

  Kedua board di-`erase` lalu di-flash; monitor me-reset keduanya saat port dibuka. Board H2 lain yang masih tercolok di-`erase` agar tidak ikut bergabung (firmware M12 memakai channel, PAN ID, dan network key yang sama). `SERVER_URL` firmware menunjuk `http://192.168.1.5:8080/post`, sedangkan `http_sink.py` *tidak* dijalankan — rekaman ini sengaja memperlihatkan perilaku gateway saat server tidak terjangkau.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: (left, left, left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Board], th[Peran (terpilih)], th[RLOC16], th[EUI-64 (pabrik)], th[Port serial (UART)]),
      [Gateway], [ESP32-C6 DevKitC-1], [Child + Wi-Fi STA, forward ke HTTP], [`0x6C01`], [`40:4C:CA:FF:` \ `FE:5E:C5:40`], [`COM9`],
      [SensorH2], [ESP32-H2 DevKitM-1], [*Leader*, kirim telemetri tiap 3 s], [`0x6C00`], [`74:4D:BD:FF:` \ `FE:61:E6:2C`], [`COM5`],
    ),
    [Board dan port pada rekaman log serial Modul 13],
    "tbl:m13-log-1",
  )

  Thread `ESP_OT_GW`, channel *15*, PAN ID *`0xABCD`*, Extended PAN ID *`DE:AD:00:BE:EF:00:CA:FE`* — sama di kedua board. Wi-Fi gateway: SSID `SprH-3`, channel *8*, IP `192.168.1.109`, RSSI −63 dBm.

  *Gateway (C6) --- COM9*

  #keluaran("ESP-ROM:esp32c6-20220919
Build:Sep 19 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:2
load:0x40875730,len:0x1278
load:0x4086b910,len:0xc58
load:0x4086e610,len:0x31c0
entry 0x4086b910
Konek Wi-Fi SprH-3......
Wi-Fi OK, IP: 192.168.1.109 | RSSI: -63 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Child
Default netif dikembalikan ke Wi-Fi STA (err=0)
Info network Thread:
  Peran          : Child
  Network name   : ESP_OT_GW
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C01
  Extended addr  : BE:21:63:FE:AC:75:5F:60
  EUI-64         : 40:4C:CA:FF:FE:5E:C5:40
  Mesh-Local EID : fdde:ad00:beef:0:15c:9037:1e71:3135
Info network Wi-Fi:
  SSID           : SprH-3
  IP             : 192.168.1.109
  RSSI           : -64 dBm
  Channel Wi-Fi  : 8
  BSSID (AP)     : 24:C0:13:CB:4B:27
  MAC            : 40:4C:CA:5E:C5:40
Gateway siap (Thread -> Wi-Fi).
SIM sensor (Thread): suhu:25.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.0
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.6
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.4
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:23.4
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:21.6
Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:22.3", pecah: true)

  *SensorH2 --- COM5*

  #keluaran("ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Sensor H2 (Thread node) starting...
Menunggu join ke gateway (C6)...
Attached as: Leader
Info network Thread:
  Peran          : Leader
  Network name   : ESP_OT_GW
  Channel        : 15
  PAN ID         : 0xABCD
  Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
  RLOC16         : 0x6C00
  Extended addr  : D6:48:6C:1E:E0:BC:16:6B
  EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
  Mesh-Local EID : fdde:ad00:beef:0:7c1b:2b3:3487:1195
TX via Thread: suhu:24.4
TX via Thread: suhu:25.0
TX via Thread: suhu:24.3
TX via Thread: suhu:24.8
TX via Thread: suhu:24.0
TX via Thread: suhu:24.2
TX via Thread: suhu:24.5
TX via Thread: suhu:24.8
TX via Thread: suhu:23.8
TX via Thread: suhu:24.5
TX via Thread: suhu:24.6
TX via Thread: suhu:25.0
TX via Thread: suhu:24.4
TX via Thread: suhu:23.4
TX via Thread: suhu:24.2
TX via Thread: suhu:23.4
TX via Thread: suhu:23.5
TX via Thread: suhu:22.5
TX via Thread: suhu:21.6
TX via Thread: suhu:21.9
TX via Thread: suhu:22.3
TX via Thread: suhu:22.1
TX via Thread: suhu:21.4
TX via Thread: suhu:21.8
TX via Thread: suhu:21.5", pecah: true)

  *Urutan gabungan (satu sumbu waktu, log ROM boot dihilangkan)*

  #keluaran("[   0.750] SensorH2 | Sensor H2 (Thread node) starting...
[   0.750] SensorH2 | Menunggu join ke gateway (C6)...
[   3.849] Gateway  | Konek Wi-Fi SprH-3......
[   3.849] Gateway  | Wi-Fi OK, IP: 192.168.1.109 | RSSI: -63 dBm
[   3.849] Gateway  | coex preference = WIFI (err=0)
[   3.849] Gateway  | Menunggu attach Thread...
[  15.556] SensorH2 | Attached as: Leader
[  15.556] SensorH2 | Info network Thread:
[  15.556] SensorH2 |   Peran          : Leader
[  15.556] SensorH2 |   Network name   : ESP_OT_GW
[  15.556] SensorH2 |   Channel        : 15
[  15.556] SensorH2 |   PAN ID         : 0xABCD
[  15.556] SensorH2 |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  15.556] SensorH2 |   RLOC16         : 0x6C00
[  15.769] SensorH2 |   Extended addr  : D6:48:6C:1E:E0:BC:16:6B
[  15.769] SensorH2 |   EUI-64         : 74:4D:BD:FF:FE:61:E6:2C
[  15.770] SensorH2 |   Mesh-Local EID : fdde:ad00:beef:0:7c1b:2b3:3487:1195
[  15.770] SensorH2 | TX via Thread: suhu:24.4
[  18.772] SensorH2 | TX via Thread: suhu:25.0
[  21.780] SensorH2 | TX via Thread: suhu:24.3
[  22.907] Gateway  | Thread attached as: Child
[  22.907] Gateway  | Default netif dikembalikan ke Wi-Fi STA (err=0)
[  22.907] Gateway  | Info network Thread:
[  22.907] Gateway  |   Peran          : Child
[  22.907] Gateway  |   Network name   : ESP_OT_GW
[  22.907] Gateway  |   Channel        : 15
[  22.907] Gateway  |   PAN ID         : 0xABCD
[  22.908] Gateway  |   Extended PAN ID: DE:AD:00:BE:EF:00:CA:FE
[  22.930] Gateway  |   RLOC16         : 0x6C01
[  22.930] Gateway  |   Extended addr  : BE:21:63:FE:AC:75:5F:60
[  22.930] Gateway  |   EUI-64         : 40:4C:CA:FF:FE:5E:C5:40
[  22.930] Gateway  |   Mesh-Local EID : fdde:ad00:beef:0:15c:9037:1e71:3135
[  22.930] Gateway  | Info network Wi-Fi:
[  22.930] Gateway  |   SSID           : SprH-3
[  22.930] Gateway  |   IP             : 192.168.1.109
[  23.161] Gateway  |   RSSI           : -64 dBm
[  23.161] Gateway  |   Channel Wi-Fi  : 8
[  23.161] Gateway  |   BSSID (AP)     : 24:C0:13:CB:4B:27
[  23.161] Gateway  |   MAC            : 40:4C:CA:5E:C5:40
[  23.161] Gateway  | Gateway siap (Thread -> Wi-Fi).
[  23.161] Gateway  | SIM sensor (Thread): suhu:25.8
[  24.772] SensorH2 | TX via Thread: suhu:24.8
[  27.797] SensorH2 | TX via Thread: suhu:24.0
[  30.810] SensorH2 | TX via Thread: suhu:24.2
[  31.146] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  31.146] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
[  33.814] SensorH2 | TX via Thread: suhu:24.5
[  36.810] SensorH2 | TX via Thread: suhu:24.8
[  39.158] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  39.158] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.0
[  39.816] SensorH2 | TX via Thread: suhu:23.8
[  42.817] SensorH2 | TX via Thread: suhu:24.5
[  45.806] SensorH2 | TX via Thread: suhu:24.6
[  47.151] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  47.151] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.8
[  48.834] SensorH2 | TX via Thread: suhu:25.0
[  51.825] SensorH2 | TX via Thread: suhu:24.4
[  54.833] SensorH2 | TX via Thread: suhu:23.4
[  55.168] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  55.169] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.6
[  57.836] SensorH2 | TX via Thread: suhu:24.2
[  60.852] SensorH2 | TX via Thread: suhu:23.4
[  63.167] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  63.167] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:24.4
[  63.867] SensorH2 | TX via Thread: suhu:23.5
[  66.854] SensorH2 | TX via Thread: suhu:22.5
[  69.862] SensorH2 | TX via Thread: suhu:21.6
[  71.168] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  71.168] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:23.4
[  72.864] SensorH2 | TX via Thread: suhu:21.9
[  75.882] SensorH2 | TX via Thread: suhu:22.3
[  78.884] SensorH2 | TX via Thread: suhu:22.1
[  79.169] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  79.170] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:21.6
[  81.897] SensorH2 | TX via Thread: suhu:21.4
[  84.881] SensorH2 | TX via Thread: suhu:21.8
[  87.167] Gateway  | Forward via Wi-Fi -> http://192.168.1.5:8080/post | HTTP -1
[  87.168] Gateway  | RX via Thread [fdde:ad00:beef:0:7c1b:2b3:3487:1195]: suhu:22.3
[  87.894] SensorH2 | TX via Thread: suhu:21.5", pecah: true)

  *Ringkasan `monitor_serial.py`*

  #keluaran("Durasi: 90.2 s
  Gateway  Child   COM9             50 baris, boot 1x, attach Thread 22.54 s sejak boot
           Wi-Fi: IP 192.168.1.109, 3.5 s sejak boot, RSSI -63 dBm
           Wi-Fi channel 8, SSID SprH-3, MAC 40:4C:CA:5E:C5:40
           Thread ESP_OT_GW, channel 15, PAN 0xABCD, RLOC16 0x6C01, EUI-64 40:4C:CA:FF:FE:5E:C5:40
  SensorH2 Leader  COM5             47 baris, boot 1x, attach Thread 15.19 s sejak boot
           Thread ESP_OT_GW, channel 15, PAN 0xABCD, RLOC16 0x6C00, EUI-64 74:4D:BD:FF:FE:61:E6:2C
  Network name/Channel/PAN ID/Extended PAN ID Thread: sama (satu network)

Hop                                   dikirim  diterima    loss
----------------------------------------------------------------
Thread  (H2 TX -> C6 RX)                   22         8    63.6%
Wi-Fi   (C6 -> server, telemetri)           7         0   100.0%
Wi-Fi   (C6 -> server, SIM sensor)          1         0   100.0%
End-to-end (H2 TX -> HTTP 2xx)             22         0   100.0%

Kode HTTP: -1: 8x
Lama POST: rata2 8.00 s (7.99..8.02) — dari baris sumber sampai baris Forward, timestamp PC
Telemetri H2 yang tidak sampai ke gateway: suhu:24.2 @ 30.8 s, suhu:24.5 @ 33.8 s, suhu:23.8 @ 39.8 s, suhu:24.5 @ 42.8 s, suhu:25.0 @ 48.8 s, suhu:23.4 @ 54.8 s, suhu:24.2 @ 57.8 s, suhu:23.5 @ 63.9 s ...

Bandingkan jumlah HTTP 2xx dengan jumlah POST yang tercatat di http_sink.py.", pecah: true)

  *Catatan*

  - *Info network Thread cocok di kedua board* (network name, channel, PAN ID, Extended PAN ID dari dataset yang ditulis kode).
  - *Peran dipilih jaringan.* H2 attach lebih dulu (15,2 s) dan menjadi *Leader* `0x6C00`; gateway C6 attach 22,5 s sebagai *Child* `0x6C01` — Router ID sama, jadi parent gateway adalah H2. Gateway tidak harus Leader.
  - *EUI-64 C6 diturunkan dari MAC Wi-Fi-nya*: MAC `40:4C:CA:5E:C5:40` → EUI-64 `40:4C:CA:FF:FE:5E:C5:40` (disisipi `FF:FE`). Extended addr Thread tetap diacak dan berbeda dari keduanya.
  - *Channel Wi-Fi 8 (±2447 MHz) vs Thread channel 15 (2425 MHz)*: frekuensinya tidak bertumpuk, tetapi keduanya berbagi satu radio dan satu antena di C6.
  - *Loss terbesar ada di aplikasi gateway, bukan radio Thread.* Setiap `http.POST()` gagal (`HTTP -1`) setelah ±8 s karena server tidak terjangkau; selama itu `loop()` tertahan dan socket UDP tidak dibaca. Hanya satu paket yang tertampung per periode, sehingga H2 mengirim 25 telemetri (22 setelah gateway siap) tetapi gateway hanya mencetak *8* `RX via Thread`, masing- masing tertunda beberapa detik. Semua POST gagal, jadi end-to-end 0 %.
  - Untuk rekaman dengan server hidup, jalankan `http_sink.py` dan arahkan `SERVER_URL` ke IP laptop di jaringan Wi-Fi yang sama.
  - `E (…) OT_STATE: … Failed to get the active dataset` adalah peringatan non-fatal saat transisi role.
  - Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

#tbl(
  table(
    columns: (1.2fr, 1fr, 1.5fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.45em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Skenario / Jarak H2--C6], th[RSSI Wi-Fi (C6)],
      th[Latency end-to-end (TX ke HTTP, ms)], th[Success (paket / 40)],
    ),
    [1 m, garis pandang], [#isian], [], [],
    [5 m, garis pandang], [#isian], [], [],
    [5 m + penghalang dinding], [#isian], [], [],
  ),
  [Lembar pengukuran end-to-end Modul 13],
  "tbl:m13-ukur",
)

Latency diukur manual: cap waktu baris `TX via Thread` pada H2 dibandingkan
`Forward via Wi-Fi ... HTTP 200` pada C6.

*Tabel loss per hop --- wajib.* Inilah yang membedakan modul ini dari sekadar
demo.

#tbl(
  table(
    columns: (1.4fr, 1fr, 1fr, auto),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Hop], th[Dikirim], th[Diterima], th[Loss (%)]),
    [H2 ke C6 (Thread)], [#isian], [], [],
    [C6 ke server (Wi-Fi/HTTP)], [#isian], [], [],
    [H2 ke server (ujung-ke-ujung)], [#isian], [], [],
  ),
  [Lembar pengukuran loss per hop Modul 13],
  "tbl:m13-perhop",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Mengapa ESP32-C6 dapat menjadi Thread Leader dan Wi-Fi STA secara bersamaan,
  dan apa konsekuensinya (ukuran firmware, pembagian waktu radio)?
+ Bagaimana pengaruh jarak atau penghalang terhadap jumlah paket Thread yang
  diterima gateway?
+ Berapa latency tambahan yang diperkenalkan hop Wi-Fi/HTTP dibanding bila data
  berhenti di gateway? Bandingkan dengan latency Thread murni M11.
+ Apa yang terjadi pada baris `Wi-Fi terputus, skip forward` --- dan apakah
  data Thread tersebut hilang? Bagaimana cara memperbaikinya?
+ Kapan arsitektur gateway Thread ke Wi-Fi lebih tepat dipakai dibanding node
  sensor Wi-Fi langsung? Jawab dari sisi daya, jangkauan, dan jumlah node.

== Concept Check

+ Apa perbedaan gateway dan border router dalam konteks jaringan Thread?
+ Mengapa komunikasi Thread pada praktikum ini memakai UDP multicast, bukan
  unicast?
+ Apa fungsi dataset (channel, PAN ID, network key, mesh-local prefix) dalam
  pembentukan jaringan Thread?
+ Bagaimana gateway mengetahui alamat sumber pesan Thread? Perhatikan keluaran
  `remoteIP`.
+ Apa kelemahan forwarding via HTTP POST dibanding MQTT untuk telemetri
  periodik? Jawaban ini adalah jembatan ke Modul 14.

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Memperkaya payload dan menambah sumber])[
  / CH-1 --- Dua sensor: Tambahkan node Thread H2 kedua dengan payload berbeda
    (misalnya `hum:XX`) dan pastikan gateway mem-forward keduanya. Bagaimana
    server membedakan sumbernya?

  / CH-2 --- Payload lebih kaya: Sertakan RSSI Thread dan nomor urut di dalam
    payload (`suhu:25.3,rssi:-62,#42`). Diskusikan: apakah ini masih
    _transparent forwarding_?
]

#tujuan-prak(3, [Menghitung loss per hop dan menyelamatkan data])[
  / CH-3 --- Loss per hop (wajib): Hitung packet loss dengan sequence number
    pada payload. Contoh: 100 paket dikirim H2, 97 diterima gateway, sehingga
    loss Thread = 3 %. Lalu bandingkan dengan jumlah HTTP 200 untuk mendapatkan
    loss hop Wi-Fi.

  / CH-4 --- Buffer saat Wi-Fi putus: Ubah gateway agar menyimpan pesan Thread
    yang datang saat Wi-Fi mati (misalnya antrean 20 pesan) dan mengirimkannya
    setelah koneksi pulih. Ukur berapa pesan yang berhasil diselamatkan.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (gateway, border router, Thread, Wi-Fi STA, UDP
  multicast, mesh-local prefix).
+ Konfigurasi --- dataset Thread, SSID, URL server, port, dan `huge_app.csv`.
+ Hasil eksperimen --- log kedua board (EXP-01 sampai EXP-03 beserta
  checkpoint), termasuk uji Wi-Fi diputus.
+ Data pengukuran --- tabel bagian Pengukuran *dan* tabel loss per hop.
+ Analisis dan concept check.
+ Challenge --- minimal CH-3.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
