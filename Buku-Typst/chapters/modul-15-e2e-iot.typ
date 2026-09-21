// ============================================================================
// Modul 15 — Pipeline IoT End-to-End
// Sumber: week15_e2e_iot/README.md; listing kode dibaca langsung dari
//         assets/code/week15_e2e_iot/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 15 — Pipeline IoT End-to-End", l: "bab:modul-15")

#identitas-modul(
  "Modul 15",
  [Build End-to-End IoT System --- Pipeline IoT End-to-End],
  [ESP32-H2 + ESP32-C6 · Thread ke MQTT · level Advanced · 3 × 50 menit ·
   folder kode `week15_e2e_iot`],
)

#pengantar([Gambaran Umum])[
Modul 15 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut.
Misinya merangkai seluruh vertikal --- dari sensor sampai dashboard --- dan
menunjukkan di hop mana pesan hilang apabila memang hilang. Percobaan berjalan
sebagai rantai end-to-end empat hop, diamati melalui dua Serial Monitor 115200
baud dan `mosquitto_sub` di sisi PC.
]

== Pendahuluan

Modul ini *tidak memperkenalkan protokol baru*. Seluruh komponennya sudah
dibangun: sensor Thread (M11), mesh (M12), gateway dwi-radio (M13), dan klien
MQTT (M14). Yang baru adalah menyatukannya --- dan menghadapi masalah yang
hanya muncul saat sistem punya banyak hop: *ketika data tidak sampai, hop mana
yang salah?* Karena tiap hop sudah diukur sendiri pada modul sebelumnya, angka
pembanding untuk menjawabnya sudah tersedia.

Prasyaratnya adalah M11--M12 untuk Thread beserta dataset-nya, M13 untuk
gateway dwi-radio, dan M14 untuk MQTT beserta `mosquitto_sub`. Yang dibangun di
sini adalah integrasi tiga stack pada satu gateway, pengukuran latency dan loss
per hop pada rantai empat hop, isolasi kesalahan, serta verifikasi dari sisi
luar sistem. Semuanya dipakai lagi pada M16 ketika pipeline ini menjadi
kerangka baku dan hanya protokol hop pertama yang diganti-ganti agar
perbandingannya adil.

#diagram(```
H2 → Thread → C6 → Wi-Fi → MQTT → Dashboard
```.text)

*Peta modul blok integrasi (penutup blok)*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [13], [Gateway: Thread bertemu Wi-Fi, keluar lewat HTTP],
    [14], [Sisi IP diperdalam: publish/subscribe MQTT],
    [*15 (ini)*], [*Semuanya disatukan: rantai lengkap sensor ke dashboard*],
    [16], [Hop pertama diganti BLE, Zigbee, atau Thread untuk dibandingkan],
  ),
  [Peta modul blok integrasi],
  "tbl:m15-peta",
)

*Kontrak data lab ini.* Payload `suhu:XX.X` berjalan *tanpa diubah* dari node
H2 sampai subscriber di PC --- gateway tidak mem-parsing ulang, hanya
memindahkan dari satu transport ke transport lain. Karena itu topic
`praktikum/h2/telemetri` di sini identik dengan M14, dan datanya bisa langsung
dibandingkan dengan M16.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Merangkai dan mendiagnosis pipeline IoT empat hop])[
  + Merangkai pipeline lengkap sensor Thread, gateway dwi-radio, broker MQTT,
    dan subscriber, lalu menunjukkan jejak satu pesan yang sama di keempat
    titik.
  + Mengonfigurasi ESP32-C6 menjalankan Thread Leader, Wi-Fi STA, dan klien
    MQTT bersamaan, serta menjelaskan urutan inisialisasinya.
  + Mengukur latency end-to-end pada tiga skenario jarak dan memecahnya menjadi
    kontribusi tiap hop memakai data M11--M14.
  + Mengidentifikasi hop penyebab packet loss dengan membandingkan counter di
    tiap tahap, bukan dengan menebak.
]

*Kriteria keberhasilan*

#checklist((
  [Pesan `suhu:XX.X` dari H2 muncul di subscriber MQTT tiap ± 3 detik.],
  [Latency end-to-end terukur pada tiga skenario jarak.],
  [Hop penyebab loss teridentifikasi dengan membandingkan counter tiap tahap.],
  [Satu pesan yang sama dapat ditunjukkan jejaknya di H2, C6, dan
   `mosquitto_sub`.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam
(arsitektur referensi IoT, edge dibanding cloud processing, skema QoS berlapis)
berada di buku teori terpisah. Istilah kerja dirangkum pada @tbl:m15-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Pipeline end-to-end], [Rantai lengkap sensor, WSN, gateway, backbone IP, broker, sampai konsumen data.],
    [Gateway dwi-radio], [C6 menjalankan stack Thread dan Wi-Fi bersamaan, menerjemahkan UDP multicast Thread menjadi publish MQTT.],
    [Hop], [Satu perpindahan antar tahap; rantai ini punya 4 hop yang bisa gagal secara terpisah.],
    [Transparent forwarding], [String `suhu:XX.X` diteruskan tanpa diubah sepanjang rantai.],
    [Topic], [Data masuk ke `praktikum/h2/telemetri`; konsumen cukup berlangganan tanpa tahu sensornya.],
    [QoS], [Jaminan pengiriman MQTT (0, 1, atau 2); kode ini memakai QoS 0 (batasan PubSubClient).],
  ),
  [Istilah kerja Modul 15],
  "tbl:m15-istilah",
)

*Isolasi kesalahan adalah inti modul ini.* Empat hop berarti empat tempat pesan
bisa hilang. Cara membedakannya: hitung *counter di tiap tahap* --- berapa yang
dikirim H2, berapa yang tercetak `RX via Thread` di C6, berapa yang tercetak
`Publish MQTT`, dan berapa yang muncul di `mosquitto_sub`. Selisih antar tahap
menunjuk hop yang bermasalah. Tanpa counter, semua kegagalan terlihat sama:
"datanya tidak muncul".

*Sekuens protokol yang diamati*

#diagram(```
[H2] readSensor ──► "suhu:25.3" ──► OtUdp multicast
[C6] OtUdp.parsePacket ──► "RX via Thread" ──► mqtt.publish(TOPIC_TELEM)
                                          ──► "Publish MQTT [...]"
[PC] mosquitto_sub -t praktikum/h2/telemetri ──► praktikum/h2/telemetri suhu:25.3
```.text)

== Topologi

#diagram(```
   BOARD #1 (H2)              BOARD #2 (C6)                     INTERNET
+---------------+  Thread   +--------------------+  Wi-Fi   +--------------------+
|   ESP32-H2    | ────────► |     ESP32-C6       | ───────► |   Broker MQTT      |
|  DevKitM-1    | UDP mcast |    DevKitC-1       |  MQTT    | test.mosquitto.org |
| node sensor   | ff03::abcd| gateway dwi-radio  |  publish |       :1883        |
| env: h2_node  | :5050     | env: c6_gateway    |          +---------+----------+
+---------------+           +--------------------+                    │
 radio: 802.15.4             radio: 802.15.4 + Wi-Fi        +---------v----------+
                                                            |  PC: mosquitto_sub |
                                                            +--------------------+
```.text, rapat: true)

Rantai vertikal per lapis:

#diagram(```
    +--------------------+
    |    ESP32-H2        |   sensor suhu (simulasi)
    +--------------------+
              │  Thread / 802.15.4 — UDP multicast 5050
              v
    +--------------------+
    |    ESP32-C6        |   gateway dwi-radio
    +--------------------+
              │  Wi-Fi 2,4 GHz — backbone IP
              v
    +--------------------+
    |       MQTT         |   test.mosquitto.org:1883
    +--------------------+
              │  subscribe topic
              v
    +--------------------+
    |     Dashboard      |   mosquitto_sub di PC
    +--------------------+
```.text)

#tbl(
  table(
    columns: (auto, auto, auto, 1.4fr),
    align: (left, left, left, left),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Node], th[Board], th[Environment], th[Peran]),
    [Sensor], [*ESP32-H2* DevKitM-1], [`h2_node`],
    [Sensor Thread, TX `suhu:XX.X` tiap 3 s],
    [Gateway], [*ESP32-C6* DevKitC-1], [`c6_gateway`],
    [Thread Leader, Wi-Fi STA, dan klien MQTT (`esp32c6-gateway`)],
    [Konsumen], [PC/laptop], [---], [`mosquitto_sub`, verifikasi independen],
  ),
  [Peran tiap elemen Modul 15],
  "tbl:m15-topologi",
)

Sama seperti M13, *dua jenis board wajib*: ESP32-H2 tidak punya Wi-Fi, jadi
hanya ESP32-C6 yang bisa memegang Thread dan Wi-Fi sekaligus.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (sensor Thread) dan ESP32-C6 (gateway
Thread dan Wi-Fi/MQTT).

#tbl(
  table(
    columns: (auto, 1fr, 1.6fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-H2], [DevKitM-1 --- node sensor Thread], [1],
    [2], [Board ESP32-C6], [DevKitC-1 --- gateway Thread ke MQTT], [1],
    [3], [Kabel USB data], [kabel data, bukan _charge-only_], [2],
    [4], [PC/Laptop], [PlatformIO Core/IDE dan `mosquitto-clients`], [1],
    [5], [Wi-Fi atau hotspot], [*2,4 GHz*, ada akses internet], [1],
    [6], [Broker MQTT], [`test.mosquitto.org:1883` atau Mosquitto lokal], [1],
    [7], [Library PubSubClient], [`knolleary/PubSubClient@^2.8` via `lib_deps`], [---],
  ),
  [Alat dan bahan Modul 15],
  "tbl:m15-alat",
)

*Konfigurasi jaringan*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Nilai]),
    [Thread network], [`ESP_OT_E2E`, channel 15, PAN `0xABCD`],
    [Mesh-local prefix], [`fdde:ad00:beef::/64` (identik di H2 dan C6)],
    [Grup multicast dan port], [`ff03::abcd` : 5050],
    [Topic MQTT], [`praktikum/h2/telemetri`],
    [Client ID gateway], [`esp32c6-gateway`],
    [Interval telemetri], [3000 ms],
  ),
  [Konfigurasi jaringan Modul 15],
  "tbl:m15-konfig",
)

== Kode Program

#sumber-kode("week15_e2e_iot",
  ("platformio.ini", "src/h2_node/main.cpp", "src/c6_gateway/main.cpp"))

#kode-berkas("week15_e2e_iot/platformio.ini",
  [`platformio.ini` Modul 15 pada repositori],
  "lst:m15-ini",
)

#kode-berkas("week15_e2e_iot/src/h2_node/main.cpp",
  [`src/h2_node/main.cpp` --- node sensor Thread di ESP32-H2],
  "lst:m15-h2",
  pecah: true,
)

#kode-berkas("week15_e2e_iot/src/c6_gateway/main.cpp",
  [`src/c6_gateway/main.cpp` --- gateway Thread, Wi-Fi, dan MQTT],
  "lst:m15-c6",
  pecah: true,
)

== Build dan Flash

#keluaran("# terminal 1 - subscriber, jalankan lebih dulu
mosquitto_sub -h test.mosquitto.org -t \"praktikum/h2/telemetri\" -v

# terminal 2 & 3 - gateway dulu, baru node sensor
pio run -d week15_e2e_iot -e c6_gateway -t upload -t monitor
pio run -d week15_e2e_iot -e h2_node    -t upload -t monitor")

*Pre-flight checklist*

#checklist((
  [ESP32-H2 dan ESP32-C6 terhubung ke PC via kabel USB, port dicatat.],
  [`WIFI_SSID` dan `WIFI_PASS` pada `src/c6_gateway/main.cpp` sudah disesuaikan
   (hotspot *2,4 GHz*).],
  [Broker MQTT dapat dijangkau dari PC (tes dengan `mosquitto_sub`).],
  [Firmware `h2_node` dan `c6_gateway` berhasil di-build.],
  [Env gateway memakai `board_build.partitions = huge_app.csv` (firmware lebih
   dari 1,25 MB).],
  [Dua Serial Monitor (115200) dibuka, satu untuk tiap board.],
  [Prefix mesh-local kedua firmware sama: `fdde:ad00:beef::/64`.],
  [Data latency dan loss dari M11 (Thread) dan M14 (MQTT) sudah di tangan
   sebagai pembanding per hop.],
))

== Percobaan

=== EXP-01 --- Inisialisasi Gateway

Deploy firmware kedua board. Gateway melakukan tiga tahap setup: konek Wi-Fi,
konek MQTT (client ID `esp32c6-gateway`), lalu membentuk jaringan Thread
`ESP_OT_E2E` sebagai Leader dan join grup multicast. Ukur waktu total setup.

#diagram(```
[C6 setup] WiFi.begin ──► mqtt.connect ──► OThread dataset ──► leader
           ──► beginMulticast(ff03::abcd, 5050)
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [SSID dan IP Wi-Fi gateway], [#isian],
    [Broker dan port], [#isian],
    [Nama jaringan Thread], [#isian],
    [Role C6 setelah attach], [#isian],
    [Awalan Mesh-Local EID H2 dan C6 sama?], [#isian],
    [Waktu total setup hingga `Gateway siap`], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m15-exp01",
)

#buka-abstraksi[
  Gateway ini menjalankan *tiga* stack di satu chip: Thread, Wi-Fi, dan MQTT.
  Bandingkan ukuran firmware `c6_gateway` modul ini dengan `c6_gateway` M13
  (Thread, Wi-Fi, dan HTTP) dari ringkasan `pio run`, lalu periksa
  `huge_app.csv` untuk melihat berapa besar partisi app yang tersedia. Jawab:
  berapa persen partisi sudah terpakai, dan apa yang akan terjadi bila
  ditambahkan satu stack lagi (misalnya BLE seperti di M16)? Ini metrik yang
  jarang diukur orang tetapi menentukan apakah sebuah gateway bisa dikembangkan
  lagi.
]

#checkpoint[
  Gateway mencetak *ketiga* tanda kesiapan berurutan: `Wi-Fi OK, IP: ...`,
  `MQTT terhubung`, dan `Thread attached as: leader`. Jika salah satu tidak
  muncul, hentikan di sini --- mendiagnosis satu stack jauh lebih mudah
  daripada mendiagnosis tiga sekaligus.
]

=== EXP-02 --- Thread TX lalu Forward MQTT

H2 mengirim `suhu:XX.X` tiap 3 detik; C6 menerima paket dan langsung
mem-publish payload yang sama ke broker.

#diagram(```
[H2] ──3 s──► "TX via Thread: suhu:25.3"
[C6] ──► "RX via Thread: suhu:25.3" ──► "Publish MQTT [praktikum/h2/telemetri]: suhu:25.3"
```.text, rapat: true)

*Expected output --- H2*

#keluaran("Sensor H2 (Thread node) starting...
Menunggu join ke gateway (C6)...
Attached as: Child
TX via Thread: suhu:25.2")

*Expected output --- C6*

#keluaran("Konek Wi-Fi SprH-3......
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -67 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Leader
Default netif dikembalikan ke Wi-Fi STA (err=0)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
MQTT belum terhubung. Lanjut; dicoba ulang di loop().
Gateway siap (H2 -> Thread -> C6 -> MQTT).
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:25.8
Publish MQTT GAGAL (mqtt=-2): suhu:25.8")

#catatan[
  Log di atas direkam *tanpa board H2*: baris `SIM sensor (Thread): ...`
  berasal dari simulasi sensor di firmware gateway. Bila board H2 terpasang,
  baris `RX via Thread: suhu:...` ikut muncul. Pada rekaman ini hop MQTT gagal
  total (`rc=-2`, koneksi TCP keluar tidak terbentuk), sehingga setiap nilai
  dicetak `Publish MQTT GAGAL`. Saat MQTT tersambung, baris yang sama menjadi
  `Publish MQTT [praktikum/h2/telemetri]: suhu:...`.
]

#checkpoint[
  Untuk *satu* nilai suhu yang sama (misalnya `25.2`), tiga baris log
  berurutan harus dapat ditunjuk: `TX via Thread` di H2, `RX via Thread` di C6,
  dan `Publish MQTT` di C6. Jika baris kedua ada tetapi ketiga tidak,
  masalahnya di MQTT --- bukan di Thread.
]

=== EXP-03 --- Verifikasi End-to-End

Jalankan subscriber di PC:

#keluaran("mosquitto_sub -h test.mosquitto.org -t \"praktikum/h2/telemetri\" -v")

Verifikasi bahwa tiap ± 3 detik muncul:

#keluaran("praktikum/h2/telemetri suhu:25.2")

Variasi wajib:

+ Jauhkan H2 dari C6 (1 m, 5 m, lalu di balik dinding) dan hitung pesan yang
  sampai ke subscriber.
+ Matikan hotspot sesaat untuk melihat reconnect MQTT (kode melakukan
  `mqtt.connect` ulang di `loop`). Catat berapa pesan Thread yang datang selama
  itu dan apa nasibnya.
+ Reset H2 saat sistem berjalan; ukur berapa lama sampai data muncul lagi di
  subscriber.

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Interval pesan di subscriber (s)], [#isian],
    [Jumlah pesan per 2 menit], [#isian],
    [RSSI Wi-Fi gateway], [#isian],
    [Perilaku saat MQTT terputus], [#isian],
    [Waktu pulih setelah H2 di-reset], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m15-exp03",
)

#checkpoint[
  Nilai suhu yang muncul di `mosquitto_sub` sama persis dengan yang dicetak H2.
  Jika berbeda atau tertukar urutannya, ada pihak lain yang mem-publish ke
  topic yang sama --- ganti prefix topic menjadi unik per kelompok.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada *ESP32-H2 DevKitM-1* dan *ESP32-C6 DevKitC-1* asli.

#keluaran("# H2 (env h2_node)                # C6 (env c6_gateway)
[1.002] Attached as: Router       [2.003] Wi-Fi OK, IP: 192.168.110.197 | RSSI: -84 dBm
[3.406] TX via Thread: suhu:24.7  [3.004] Thread attached as: Router
[6.412] TX via Thread: suhu:24.5  [3.004] Default netif dikembalikan ke Wi-Fi STA (err=0)
                                  [18.025] RX via Thread: suhu:23.4
                                  [18.025] Publish MQTT GAGAL (mqtt=-2) ...")

#tbl(
  table(
    columns: (1.5fr, 1.3fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Bagian rantai], th[Status]),
    [Build `h2_node` dan `c6_gateway` (`huge_app.csv`)], [berhasil],
    [C6 attach ke Thread `ESP_OT_E2E`], [berhasil, 3,0 s sejak boot],
    [Hop Thread H2 ke C6 (`RX via Thread`)], [berhasil, seluruh paket, 0 % loss],
    [C6 asosiasi Wi-Fi sambil Thread jalan], [berhasil, 2,0 s (setelah perbaikan urutan)],
    [Publish MQTT ke broker], [berjalan tetapi tidak andal (0--36 % end-to-end, tergantung AP)],
  ),
  [Hasil verifikasi hardware Modul 15],
  "tbl:m15-verifikasi",
)

=== Rantai Penuh Terbukti --- dengan Satu Syarat Wajib

Pipeline H2, Thread, C6, Wi-Fi, MQTT, hingga subscriber berhasil dijalankan
utuh, *tetapi hanya setelah prioritas radio diberikan ke Wi-Fi* sebelum stack
802.15.4 dinyalakan (@lst:m15-coex).

#kode(```cpp
#include "esp_coexist.h"
...
esp_coex_preference_set(ESP_COEX_PREFER_WIFI);   // sebelum OThread.start()
```.text,
  [Prioritas radio ke Wi-Fi sebelum stack Thread dinyalakan],
  "lst:m15-coex",
)

Tanpa baris itu, C6 tetap asosiasi Wi-Fi dan dapat IP, tetapi *seluruh TCP
keluar gagal* --- bahkan ke router sendiri (probe timeout 4 detik berulang).

*Diuji pada tiga jaringan Wi-Fi berbeda.* Hop Thread selalu sehat; hop
Wi-Fi/MQTT yang bervariasi dan selalu menjadi penyumbang kerugian
(@tbl:m15-tiga-ap).

#tbl(
  table(
    columns: (auto, auto, auto, 1.1fr, 1fr, auto),
    align: (left, left, left, left, left, left),
    inset: (x: 0.4em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[AP uji], th[Kanal], th[RSSI], th[H2 TX ke C6 RX],
      th[Publish ke broker], th[End-to-end],
    ),
    [AP-1], [1 (2412 MHz)], [−82 dBm], [berhasil], [0], [0 %],
    [AP-2], [12 (2467 MHz)], [−81 dBm], [32/33 (97 %)], [12/12], [*36 %*],
    [AP-3], [9 (2452 MHz)], [−71 dBm], [30/39 (77 %)], [2/7], [*5 %*],
  ),
  [Hasil uji pada tiga access point berbeda],
  "tbl:m15-tiga-ap",
)

Sinyal yang lebih kuat (AP-3) *tidak* menghasilkan hasil terbaik --- jadi
penyebabnya bukan link budget, melainkan pembagian airtime antara Wi-Fi dan
802.15.4 pada satu antena. Mengganti channel 802.15.4 (15 menjadi 25, dan 15
menjadi 11 untuk menjauh maksimum dari kanal Wi-Fi AP-3) juga tidak menolong.

#penting[
  *Pelajaran penting dari AP-3: `publish()` bernilai `true` bukan bukti
  sampai.* Pada run itu gateway mencetak 7 baris `Publish MQTT [...]` sementara
  broker hanya menerima *2*. Pada QoS 0, `PubSubClient::publish()` hanya
  menulis ke buffer socket; bila koneksi TCP sudah setengah mati, tidak ada
  yang memberi tahu. Karena itu bagian Pengukuran mewajibkan kolom "Broker
  menerima" diisi dari *log broker*, bukan dari log gateway. Ini juga jawaban
  konkret untuk Concept Check nomor 3.
]

*Pembanding yang paling menentukan.* Modul 16 (BLE dan Wi-Fi, bukan Thread dan
Wi-Fi) diukur pada AP-3, jarak, dan broker yang sama persis (@tbl:m15-banding).

#tbl(
  table(
    columns: (1.3fr, auto, 1.1fr, 1.1fr, auto),
    align: (left, left, left, left, left),
    inset: (x: 0.45em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Pipeline], th[Modul], th[Hop sensor], th[Hop Wi-Fi/MQTT],
      th[End-to-end],
    ),
    [BLE ke C6 ke MQTT], [M16], [47/48 (98 %)], [47/47 (100 %)], [*98 %*],
    [Thread ke C6 ke MQTT], [M15], [30/39 (77 %)], [2/7 (29 %)], [*5 %*],
  ),
  [Pembanding pipeline BLE dan Thread pada kondisi jaringan identik],
  "tbl:m15-banding",
)

Kondisi jaringan identik; yang berbeda hanya radio hop pertama. Ini bahan utama
untuk analisis Modul 16: pada gateway satu-chip satu-antena, *BLE dengan Wi-Fi
nyaris tanpa ongkos koeksistensi, sedangkan Thread dengan Wi-Fi sangat mahal*.
Kesimpulan yang tepat bukan "Thread lebih buruk dari BLE", melainkan bahwa
arsitektur gateway satu-chip tidak cocok untuk Thread dan Wi-Fi --- border
router dua-chip akan mengubah angka ini sepenuhnya.

*Yang sudah dicoba dan tidak menyelesaikan:* mengganti channel 802.15.4 (15
menjadi 25), memakai AP di kanal Wi-Fi yang tidak bertetangga,
`WiFi.setSleep()` kedua nilainya, dan memaksa default netif ke Wi-Fi STA. Yang
*berhasil* hanya kombinasi urutan inisialisasi, `esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`,
dan memisahkan jeda retry MQTT dari jeda retry Wi-Fi. Bahkan setelah itu, hop
Wi-Fi tetap tidak andal --- laporkan angkanya apa adanya.

*Yang harus dilakukan praktikan:* catat RSSI Wi-Fi gateway di laporan dan isi
tabel counter per tahap di bagian Pengukuran. Rantai yang bocor di satu hop
dengan sebab yang dapat ditunjuk bernilai lebih tinggi daripada demo mulus
tanpa data.

=== Perbaikan Kode yang Lahir dari Uji Ini

#tbl(
  table(
    columns: (1.3fr, 1.3fr),
    align: (left, left),
    inset: (x: 0.55em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Masalah di perangkat nyata], th[Perbaikan]),
    [C6 *panic* saat boot (`Failed to create OpentThread event loop`, lalu `assert failed: otTaskletsSignalPending`)],
    [`OThread.begin()` dipanggil *sebelum* Wi-Fi; wrapper OpenThread tidak mentoleransi event loop default yang sudah dibuat Wi-Fi],
    [Wi-Fi tidak pernah asosiasi bila `OThread.start()` sudah jalan],
    [Wi-Fi disambungkan *di antara* `OThread.begin()` dan `OThread.start()`, sehingga asosiasi selesai sebelum radio 802.15.4 aktif],
    [`while (WiFi.status() != WL_CONNECTED)` dan loop MQTT menggantung selamanya],
    [dibatasi `WIFI_TIMEOUT_MS` dan `MQTT_TIMEOUT_MS`, lalu lanjut dan dicoba ulang berkala],
    [`mqtt.connect()` dipanggil tiap iterasi `loop()`, sehingga banjir `DNS Failed` menenggelamkan log],
    [`maintainNetwork()` dengan jeda `WIFI_RETRY_MS` dan cek Wi-Fi lebih dulu],
    [`WiFi.disconnect()` di tiap percobaan ulang membatalkan asosiasi yang sedang berjalan],
    [hanya `WiFi.begin()` ulang, dengan jeda lebih panjang dari durasi asosiasi],
    [`Publish MQTT [...]` dicetak walau broker tidak terhubung --- *laporan palsu*],
    [publish hanya bila `mqtt.connected()`, kegagalan dicetak apa adanya beserta `mqtt.state()`],
    [Seluruh TCP keluar gagal saat stack Thread aktif, padahal Wi-Fi sudah dapat IP],
    [`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)` dipanggil sebelum `OThread.start()`],
    [Percobaan MQTT ikut terkunci jeda retry Wi-Fi (20 s) padahal Wi-Fi sudah sehat],
    [timer retry Wi-Fi dan MQTT dipisah (`WIFI_RETRY_MS` dibanding `MQTT_RETRY_MS`)],
  ),
  [Perbaikan kode hasil pengujian perangkat nyata Modul 15],
  "tbl:m15-perbaikan",
)


// Log serial lengkap dari week15_e2e_iot/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata ESP32-C6. Baud 115200. Sensor H2 *disimulasikan* di dalam firmware gateway (tidak ada board H2 fisik).

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, 1fr, auto),
      align: (left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Board], th[Peran], th[Port serial (UART)]),
      [Gateway], [ESP32-C6 DevKitC-1], [Thread Leader + Wi-Fi STA + MQTT publisher], [`/dev/ttyACM6`],
    ),
    [Board dan port pada rekaman log serial Modul 15],
    "tbl:m15-log-1",
  )

  Konfigurasi: Wi-Fi `SprH-3`, broker MQTT lokal `192.168.1.5:1884` (Mosquitto), topic `praktikum/h2/telemetri`, client ID `esp32c6-gateway`, Thread `ESP_OT_E2E`.

  *Gateway (C6) — `/dev/ttyACM6`*

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
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -67 dBm
coex preference = WIFI (err=0)
Menunggu attach Thread...
Thread attached as: Leader
Default netif dikembalikan ke Wi-Fi STA (err=0)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
Konek MQTT 192.168.1.5:1884 ...
Gagal (rc=-2)
MQTT belum terhubung. Lanjut; dicoba ulang di loop().
Gateway siap (H2 -> Thread -> C6 -> MQTT).
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:25.8
Publish MQTT GAGAL (mqtt=-2): suhu:25.8
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:26.6
Publish MQTT GAGAL (mqtt=-2): suhu:26.6
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:27.0
Publish MQTT GAGAL (mqtt=-2): suhu:27.0
MQTT gagal (rc=-2), coba lagi 4 detik
SIM sensor (Thread): suhu:27.3
Publish MQTT GAGAL (mqtt=-2): suhu:27.3
MQTT gagal (rc=-4), coba lagi 4 detik
SIM sensor (Thread): suhu:26.3
Publish MQTT GAGAL (mqtt=-4): suhu:26.3", pecah: true)

  *Verifikasi dari sisi broker (PC)*

  `mosquitto_sub -h 192.168.1.5 -p 1884 -t "praktikum/h2/telemetri" -v`:

  #keluaran("(0 pesan diterima selama pengamatan)")

  *Catatan*

  - Gateway menjalankan *tiga stack* di satu chip: Thread, Wi-Fi, dan MQTT.
  - Thread dan Wi-Fi masing-masing sehat: attach sebagai *Leader* dan Wi-Fi memperoleh IP `192.168.1.39` (RSSI −67 dBm).
  - *Hop Wi-Fi/MQTT gagal total* di jaringan `SprH-3`: `mqtt.connect()` terus gagal `rc=-2` (koneksi TCP keluar tidak terbentuk) meskipun prioritas radio sudah diberikan ke Wi-Fi (`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`). Ini persis kasus "AP-1" pada log referensi README (0 % end-to-end), bukan kegagalan konfigurasi.
  - Sensor *disimulasikan* (`SIM sensor (Thread): suhu:XX.X`); karena MQTT tidak pernah terhubung, tiap publish dicetak `Publish MQTT GAGAL (mqtt=-2)`.
  - Pembanding penting (modul 16): pipeline *BLE* + Wi-Fi + MQTT pada gateway satu-chip yang sama nyaris tanpa ongkos koeksistensi, sedangkan *Thread* + Wi-Fi sangat mahal — lihat log week16.
  - Baris `ESP-ROM:esp32c6-…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

#tbl(
  table(
    columns: (1.2fr, 1fr, 1.6fr, 1fr),
    align: (left, left, left, left),
    inset: (x: 0.45em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Skenario / Jarak H2--C6], th[RSSI Wi-Fi (C6)],
      th[Latency end-to-end (TX H2 ke subscriber, ms)], th[Success / 40 pesan],
    ),
    [1 m, garis pandang], [#isian], [], [],
    [5 m, garis pandang], [#isian], [], [],
    [5 m + penghalang dinding], [#isian], [], [],
  ),
  [Lembar pengukuran end-to-end Modul 15],
  "tbl:m15-ukur",
)

Latency end-to-end diukur dari cap waktu `TX via Thread` pada H2 dibandingkan
kemunculan pesan di `mosquitto_sub` (gunakan `mosquitto_sub -F '%t %p'` atau
timestamp terminal).

*Tabel counter per tahap --- inti modul ini.* Amati 2 menit (kira-kira 40
pesan).

#tbl(
  table(
    columns: (1.1fr, 1.2fr, auto, 1.2fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Tahap], th[Baris log yang dihitung], th[Jumlah],
      th[Loss terhadap tahap sebelumnya],
    ),
    [1. H2 mengirim], [`TX via Thread`], [#isian], [---],
    [2. C6 menerima], [`RX via Thread`], [#isian], [],
    [3. C6 mem-publish], [`Publish MQTT`], [#isian], [],
    [4. Subscriber menerima], [baris di `mosquitto_sub`], [#isian], [],
  ),
  [Lembar counter per tahap Modul 15],
  "tbl:m15-counter",
)

*Dekomposisi latency --- wajib.* Isi dari data modul sebelumnya.

#tbl(
  table(
    columns: (1.4fr, 1.1fr, 1fr),
    align: (left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Hop], th[Modul sumber angka], th[Latency]),
    [H2 ke C6 (Thread)], [M11], [#isian],
    [C6 ke broker (MQTT)], [M14], [#isian],
    [Jumlah keduanya], [---], [#isian],
    [Latency end-to-end terukur (M15)], [modul ini], [#isian],
    [Selisih (overhead integrasi)], [---], [#isian],
  ),
  [Lembar dekomposisi latency per hop],
  "tbl:m15-dekomposisi",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Apa peran gateway C6 dalam pipeline ini, dan protokol apa saja yang ia
  jalankan bersamaan?
+ Berapa latency tambahan karena hop Thread ke MQTT dibanding pengiriman Thread
  satu hop (M11 dan M13)? Gunakan tabel dekomposisi latency.
+ Apakah payload berubah di sepanjang rantai? Jelaskan desain transparent
  forwarding ini dan apa untungnya untuk M16.
+ Bagian mana dari rantai yang paling banyak kehilangan pesan? Tunjukkan dari
  tabel counter per tahap --- bukan dari dugaan.
+ Bandingkan arsitektur end-to-end ini dengan node sensor Wi-Fi dan MQTT
  langsung (M14) dari sisi konsumsi daya, jangkauan, dan jumlah node yang bisa
  dilayani.

== Concept Check

+ Gambarkan kembali arsitektur H2, Thread, C6, dan MQTT lalu jelaskan fungsi
  tiap elemen.
+ Mengapa gateway melakukan publish dengan payload asli, bukan mem-parsing
  ulang datanya?
+ Apa yang terjadi pada data Thread yang sedang dikirim saat koneksi MQTT
  gateway terputus?
+ Bagaimana cara memonitor topic ini dari dashboard (misalnya MQTT Explorer)
  dan apa yang perlu disiapkan?
+ Keuntungan apa yang diperoleh dengan memisahkan jaringan sensor (Thread) dan
  backbone (Wi-Fi/MQTT), dibanding satu jaringan Wi-Fi untuk semuanya?

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Menambah sumber dan menaikkan jaminan pengiriman])[
  / CH-1 --- Dua sensor: Tambahkan node Thread H2 kedua dengan payload ber-ID
    (`suhu:25.3,node2`) sehingga sumber data dapat dibedakan di subscriber.
    Diskusikan alternatifnya: memberi ID di payload dibanding memberi topic
    sendiri per node.

  / CH-2 --- QoS sungguhan: PubSubClient hanya mendukung publish QoS 0. Ganti
    library gateway ke yang mendukung QoS 1 (misalnya `arduino-mqtt`), ukur
    apakah success rate meningkat, dan bandingkan overhead-nya (ukuran
    firmware, latency).
]

#tujuan-prak(3, [Isolasi loss per hop dan dashboard sungguhan])[
  / CH-3 --- Loss per hop (wajib): Hitung packet loss end-to-end dengan
    sequence number (`suhu:25.3,#42`). Contoh: H2 mengirim 100, subscriber
    menerima 94, sehingga loss = 6 %. Identifikasi hop penyebab dengan
    membandingkan counter `RX via Thread` dan `Publish MQTT` di C6.

  / CH-4 --- Dashboard sungguhan: Sambungkan topic ini ke MQTT Explorer,
    Node-RED, atau Grafana, lalu tampilkan grafik suhu terhadap waktu.
    Lampirkan tangkapan layarnya di laporan.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (pipeline IoT, gateway dwi-radio, transparent forwarding,
  isolasi kesalahan per hop).
+ Konfigurasi --- dataset Thread `ESP_OT_E2E`, SSID, broker, topic, client ID,
  dan PubSubClient.
+ Hasil eksperimen --- log H2, C6, dan `mosquitto_sub`, termasuk jejak satu
  pesan yang sama di tiga titik.
+ Data pengukuran --- tabel jarak, *tabel counter per tahap*, dan tabel
  dekomposisi latency.
+ Analisis dan concept check.
+ Challenge --- minimal CH-3.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
