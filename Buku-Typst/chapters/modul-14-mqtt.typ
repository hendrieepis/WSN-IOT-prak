// ============================================================================
// Modul 14 — MQTT: Publish & Subscribe
// Sumber: week14_mqtt/README.md; listing kode dibaca langsung dari
//         assets/code/week14_mqtt/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan, checkpoint, buka-abstraksi, pengantar, tujuan-prak, identitas-modul
#import "../lib/helpers.typ": gbr, tbl, th, isian, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram, checklist
#import "../config.typ": edisi_buku

#chapter("Modul 14 — MQTT: Publish dan Subscribe", l: "bab:modul-14")

#identitas-modul(
  "Modul 14",
  [Publish to the Cloud --- MQTT: Publish dan Subscribe],
  [ESP32-C6 · Wi-Fi / MQTT · pub-sub · level Intermediate · 3 × 50 menit ·
   folder kode `week14_mqtt`],
)

#pengantar([Gambaran Umum])[
Modul 14 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah.
Misinya menempatkan perangkat pada sebuah broker dan membuatnya bicara dua arah
tanpa perlu tahu alamat lawan bicaranya. Percobaan berjalan dalam model
client--broker dengan pola publish/subscribe, diamati melalui Serial Monitor
115200 baud serta perintah `mosquitto_sub` dan `mosquitto_pub` di sisi PC.
]

== Pendahuluan

M13 mengeluarkan data ke jaringan IP lewat HTTP POST --- satu arah, satu tujuan
tetap, satu koneksi per pesan. MQTT membalik modelnya: perangkat menempel pada
*broker*, telemetri naik dan perintah turun lewat koneksi yang sama, dan tidak
ada pihak yang perlu tahu alamat pihak lain. Modul ini sengaja *tanpa Thread*
supaya sisi IP bisa dipelajari terpisah; keduanya baru disatukan di M15.

Prasyaratnya adalah M13: Wi-Fi STA pada ESP32-C6, konsep gateway, dan
transparent forwarding. Yang dibangun di sini adalah koneksi ke broker,
penyusunan topic hierarkis, publish berkala, subscribe beserta callback-nya,
tingkat QoS, pesan retained, dan perilaku saat koneksi tersambung ulang.
Semuanya dipakai lagi pada M15 ketika HTTP POST milik M13 diganti publish MQTT
ini, serta M16 ketika seluruh protokol bermuara ke topic yang sama agar
perbandingannya adil.

*Peta modul blok integrasi*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Fokus (yang ditumpuk di atas modul sebelumnya)]),
    [13], [Gateway: Thread bertemu Wi-Fi, data keluar lewat HTTP],
    [*14 (ini)*], [*Sisi IP diperdalam: publish/subscribe lewat broker MQTT*],
    [15], [M12, M13, dan M14 digabung: sensor ke Thread ke C6 ke MQTT ke dashboard],
    [16], [Protokol sensor diganti-ganti, muara MQTT-nya tetap sama],
  ),
  [Peta modul blok integrasi],
  "tbl:m14-peta",
)

*Kontrak data lab ini.* Topic dibagi dua: *`praktikum/h2/telemetri`* untuk data
naik dan *`praktikum/h2/perintah`* untuk perintah turun. Pemisahan ini adalah
kelanjutan langsung dari pola M03 (characteristic data dibanding characteristic
perintah) dan M08 (cluster On/Off dibanding laporan status). Topic telemetri
yang sama dipakai lagi di M15 dan M16 --- itulah yang membuat data ketiga modul
bisa dibandingkan.

== Capaian Pembelajaran

Setelah menyelesaikan modul ini, praktikan mampu:

#tujuan-prak(1, [Bicara dua arah lewat broker MQTT])[
  + Menghubungkan ESP32-C6 ke Wi-Fi dan broker MQTT dengan client ID tertentu,
    lalu membuktikan koneksinya dari sisi PC memakai `mosquitto_sub`.
  + Mem-publish telemetri berkala ke topic tertentu dan memverifikasi
    kedatangannya di subscriber eksternal, minimal 20 pesan berturut-turut.
  + Menerima perintah dari topic lain melalui callback dan menunjukkan aksi
    nyata yang dipicunya di perangkat.
  + Mengukur latency publish sampai terima dan menjelaskan perilaku sistem saat
    Wi-Fi atau broker terputus, berdasarkan log --- termasuk nasib subscription
    setelah reconnect.
]

*Kriteria keberhasilan*

#checklist((
  [20 publish berturut-turut tiba di subscriber eksternal.],
  [Perintah dari `mosquitto_pub` memicu callback `onMessage()` dan aksi nyata
   (CH-2).],
  [Perilaku reconnect Wi-Fi dan MQTT terverifikasi dan tercatat, termasuk
   return code kegagalan.],
  [Tabel latency dan success rate terisi dari pengukuran sendiri.],
))

== Dasar Teori (Secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. Pembahasan mendalam (paket
kontrol MQTT, session state, last will and testament, MQTT 5) berada di buku
teori terpisah. Istilah kerja dirangkum pada @tbl:m14-istilah.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Istilah], th[Definisi kerja di lab ini]),
    [Broker], [Server pusat yang menerima pesan dari publisher dan meneruskannya ke subscriber topic terkait.],
    [Publish/Subscribe], [Model komunikasi tak langsung --- pengirim dan penerima tidak saling tahu alamat, hanya terikat topic.],
    [Topic], [Label hierarkis pemisah aliran data: `praktikum/h2/telemetri` (data), `praktikum/h2/perintah` (kontrol).],
    [Wildcard], [`+` cocok satu level, `#` cocok sisa level --- dipakai subscriber, bukan publisher.],
    [QoS], [Tingkat jaminan pengiriman --- 0 (at most once), 1 (at least once), 2 (exactly once).],
    [Retained], [Broker menyimpan pesan terakhir tiap topic dan mengirimkannya ke subscriber baru.],
    [Client ID], [Identitas unik klien pada broker; dua klien dengan ID sama akan saling menendang.],
    [Keep alive dan reconnect], [Klien menjaga koneksi; kode ini otomatis reconnect Wi-Fi dan MQTT bila terputus.],
  ),
  [Istilah kerja Modul 14],
  "tbl:m14-istilah",
)

#penting[
  *Batasan PubSubClient yang wajib diketahui.* Library ini hanya melakukan
  *publish QoS 0*. Argumen ketiga `mqtt.publish(topic, payload, true)` adalah
  flag _retained_, *bukan* QoS. Artinya: setiap klaim tentang QoS 1 atau 2 pada
  laporan harus berasal dari library lain (misalnya `arduino-mqtt` atau
  `AsyncMqttClient`), bukan dari percobaan ini. Menyebut "QoS 1" tanpa
  mengganti library adalah kesalahan yang sering muncul di laporan.
]

*Mengapa modul ini tanpa Thread?* Supaya kegagalan bisa dilokalisasi. Jika MQTT
dan Thread dinyalakan bersamaan sejak awal (seperti M15), pesan yang tidak
sampai bisa berasal dari mana saja. Di sini hanya ada satu hop --- sehingga
angka latency dan loss yang diperoleh adalah *milik MQTT saja*, dan dapat
dikurangkan dari angka M15 nanti.

*Sekuens protokol yang diamati*

#diagram(```
[C6] ──publish──► [Broker] ──push──► [Subscriber / dashboard]
[C6] ◄──push───── [Broker] ◄──publish── [mosquitto_pub di PC]
        callback onMessage()          route by topic
```.text)

== Topologi

#diagram(```
        BOARD #1                                  INTERNET
+----------------------+                    +----------------------+
|      ESP32-C6        |  publish  ───────► |    Broker MQTT       |
|     DevKitC-1        |  praktikum/h2/telemetri                   |
|   MQTT client        |                    | test.mosquitto.org   |
| id: esp32c6-praktikum|  subscribe ◄────── |        :1883         |
|   env: node          |  praktikum/h2/perintah                    |
+----------------------+                    +----------+-----------+
   radio: Wi-Fi 2,4 GHz                                 │
   (802.15.4 tidak dipakai                              │ Wi-Fi/Internet
    di modul ini)                            +----------v-----------+
                                             |   PC / laptop        |
                                             | mosquitto_sub / _pub |
                                             +----------------------+
```.text, rapat: true)

#tbl(
  table(
    columns: (auto, 1.1fr, 1.1fr, 1.2fr),
    align: (left, left, left, left),
    inset: (x: 0.5em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Elemen], th[Board atau alat], th[Identitas], th[Peran]),
    [Klien MQTT], [*ESP32-C6* DevKitC-1 (env `node`)], [client ID `esp32c6-praktikum`],
    [publish telemetri dan subscribe perintah],
    [Broker], [layanan publik], [`test.mosquitto.org:1883`], [routing berbasis topic],
    [Verifikator], [PC/laptop], [`mosquitto_sub` dan `mosquitto_pub`],
    [pembuktian independen dari sisi luar],
  ),
  [Elemen sistem Modul 14],
  "tbl:m14-topologi",
)

*Mengapa ESP32-C6, bukan H2?* ESP32-H2 tidak punya radio Wi-Fi sama sekali,
jadi ia tidak bisa menjadi klien MQTT. Modul ini hanya memakai kaki Wi-Fi C6
--- radio 802.15.4-nya menganggur, dan baru dipakai bersamaan di M15.

== Alat yang Digunakan

Modul ini dijalankan di atas ESP32-C6 (Arduino core 3.x) dengan Wi-Fi dan
PubSubClient.

#tbl(
  table(
    columns: (auto, 1fr, 1.6fr, auto),
    align: (center + horizon, left, left, center + horizon),
    inset: (x: 0.55em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Spesifikasi], th[Jumlah]),
    [1], [Board ESP32-C6], [DevKitC-1], [1],
    [2], [Kabel USB data], [kabel data, bukan _charge-only_], [1],
    [3], [PC/Laptop], [PlatformIO Core/IDE dan paket `mosquitto-clients`], [1],
    [4], [Wi-Fi atau hotspot], [*2,4 GHz*, ada akses internet], [1],
    [5], [Broker MQTT], [`test.mosquitto.org:1883` (publik) atau Mosquitto lokal], [1],
    [6], [Library PubSubClient], [`knolleary/PubSubClient@^2.8` --- otomatis via `lib_deps`], [---],
  ),
  [Alat dan bahan Modul 14],
  "tbl:m14-alat",
)

*Konfigurasi*

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Nilai]),
    [Client ID], [`esp32c6-praktikum`],
    [Topic telemetri (publish)], [`praktikum/h2/telemetri`],
    [Topic perintah (subscribe)], [`praktikum/h2/perintah`],
    [Interval publish], [5000 ms],
    [QoS efektif], [0 (batasan PubSubClient)],
  ),
  [Konfigurasi MQTT Modul 14],
  "tbl:m14-konfig",
)

== Kode Program

#sumber-kode("week14_mqtt", ("platformio.ini", "src/main.cpp"))

#kode-berkas("week14_mqtt/platformio.ini",
  [`platformio.ini` Modul 14 pada repositori],
  "lst:m14-ini",
)

#kode-berkas("week14_mqtt/src/main.cpp",
  [`src/main.cpp` --- klien MQTT di ESP32-C6],
  "lst:m14-main",
  pecah: true,
)

== Build dan Flash

#keluaran("# terminal 1 - subscriber, jalankan lebih dulu
mosquitto_sub -h test.mosquitto.org -t \"praktikum/h2/telemetri\" -v

# terminal 2 - flash & monitor
pio run -d week14_mqtt -e node -t upload -t monitor")

*Pre-flight checklist*

#checklist((
  [ESP32-C6 terhubung ke PC via kabel USB, port dicatat lewat
   `pio device list`.],
  [`WIFI_SSID` dan `WIFI_PASS` pada `src/main.cpp` sudah disesuaikan (hotspot
   *2,4 GHz*).],
  [Hotspot atau Wi-Fi aktif dan board memperoleh akses internet.],
  [Broker dapat dijangkau dari PC:
   `mosquitto_sub -h test.mosquitto.org -t "praktikum/#" -v`.],
  [Firmware environment `node` berhasil di-build (`pio run -e node`).],
  [Serial Monitor 115200 baud dibuka.],
  [*Ganti prefix topic* menjadi unik per kelompok bila memakai broker publik
   (lihat catatan keamanan di bagian Concept Check).],
))

== Percobaan

=== EXP-01 --- Koneksi Wi-Fi dan Broker

Deploy firmware `node` ke ESP32-C6. Node terhubung ke Wi-Fi (`reconnectWiFi`),
lalu melakukan koneksi MQTT dengan client ID `esp32c6-praktikum` dan subscribe
topic perintah.

#diagram(```
[C6] ──► WiFi.begin ──► IP didapat ──► mqtt.connect("esp32c6-praktikum")
     ──► subscribe TOPIC_CMD
```.text)

*Data capture*

#tbl(
  table(
    columns: (1.4fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [SSID yang digunakan], [#isian],
    [IP Wi-Fi C6], [#isian],
    [Alamat dan port broker], [#isian],
    [RSSI Wi-Fi (`WiFi.RSSI()`)], [#isian],
    [Topic yang di-subscribe], [#isian],
    [Waktu boot sampai `MQTT terhubung` (s)], [#isian],
  ),
  [Lembar pengamatan EXP-01],
  "tbl:m14-exp01",
)

#checkpoint[
  Serial Monitor mencetak `Wi-Fi OK, IP: ...` *lalu* `MQTT terhubung`. Jika
  berhenti di titik-titik Wi-Fi, periksa apakah hotspot 2,4 GHz (C6 tidak
  mendukung 5 GHz). Jika Wi-Fi OK tetapi MQTT gagal, catat `rc=` yang tercetak
  --- angka itu jawaban soal analisis.
]

=== EXP-02 --- Publish Berkala

Pada `loop()`, setiap 5 detik node membaca sensor (simulasi suhu 20--40 °C) dan
melakukan `mqtt.publish(TOPIC_TELEM, "XX.X")`. Ukur interval publish aktual
pada log.

#diagram(```
loop() ──► millis()-last > 5000 ──► readSensor() ──► mqtt.publish
       ──► "TX MQTT [praktikum/h2/telemetri]: 26.4"
```.text)

*Expected output*

#keluaran("MQTT Node (C6) starting...
Konek Wi-Fi SprH-3...
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -70 dBm
Konek MQTT 192.168.1.5:1884 ...
MQTT terhubung
Subscribe: praktikum/h2/perintah
TX MQTT [praktikum/h2/telemetri]: 25.3
TX MQTT [praktikum/h2/telemetri]: 25.5")

Verifikasi di PC:

#keluaran("mosquitto_sub -h test.mosquitto.org -t \"praktikum/h2/telemetri\" -v")

#buka-abstraksi[
  Jalankan subscriber dengan wildcard
  `mosquitto_sub -h test.mosquitto.org -t "praktikum/#" -v`. Data kelompok lain
  --- bahkan data orang asing --- mungkin ikut terlihat pada broker publik yang
  sama. Jelaskan dari sini: apa yang *tidak* dikerjakan broker, dan mengapa
  produksi nyata tidak pernah memakai broker publik tanpa autentikasi.
]

#checkpoint[
  Baris yang muncul di `mosquitto_sub` *sama persis* dengan baris `TX MQTT` di
  Serial Monitor, termasuk nilainya. Jika Serial mencetak tetapi subscriber
  diam, publish gagal di sisi jaringan --- bukan di sisi kode.
]

=== EXP-03 --- Perintah Turun dan Pemulihan

Injeksi perintah dari PC:

#keluaran("mosquitto_pub -h test.mosquitto.org -t \"praktikum/h2/perintah\" -m \"LED_ON\"")

Verifikasi callback `onMessage()`:

#keluaran("RX MQTT [praktikum/h2/perintah]: LED_ON")

Variasi wajib:

+ Kirim beberapa perintah berbeda (`LED_ON`, `LED_OFF`, `RESET`) dan amati
  callback.
+ *Matikan hotspot ± 10 detik* lalu nyalakan lagi; amati `reconnectWiFi` dan
  `reconnectMQTT` beserta keluaran `Gagal (rc=...)`.
+ Setelah reconnect, kirim perintah lagi --- apakah masih diterima? Ini menguji
  apakah subscription bertahan.

*Data capture*

#tbl(
  table(
    columns: (1.5fr, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil]),
    [Perintah terkirim dibanding diterima], [#isian],
    [Delay kirim sampai `RX MQTT` (ms)], [#isian],
    [Perilaku saat Wi-Fi terputus], [#isian],
    [Return code saat gagal connect], [#isian],
    [Apakah subscription bertahan setelah reconnect?], [#isian],
  ),
  [Lembar pengamatan EXP-03],
  "tbl:m14-exp03",
)

#checkpoint[
  Setelah hotspot dinyalakan lagi, perintah baru *tetap* sampai ke perangkat.
  Jika tidak, subscription hilang saat reconnect --- temuan penting, dan
  jawabannya ada di apakah `subscribe()` dipanggil ulang di dalam fungsi
  reconnect.
]

== Verifikasi Hardware --- Log Referensi

Dijalankan pada *ESP32-C6 DevKitC-1* asli dengan broker lokal
(`tools/mqtt_broker.py`) karena `test.mosquitto.org:1883` diblokir jaringan
uji.

#keluaran("# ESP32-C6 (env node)                       # Broker (tools/mqtt_broker.py)
[0.200] MQTT Node (C6) starting...          CONNECT   id=esp32c6-praktikum
[2.405] Konek Wi-Fi myrouter....                      from 192.168.110.197
[2.405] Wi-Fi OK, IP: 192.168.110.197       SUBSCRIBE id=esp32c6-praktikum
        | RSSI: -83 dBm                               -> praktikum/h2/perintah
[2.606] MQTT terhubung                      PUBLISH   praktikum/h2/telemetri 25.4
[2.606] Subscribe: praktikum/h2/perintah    PUBLISH   praktikum/h2/telemetri 24.5
[5.210] TX MQTT [praktikum/h2/telemetri]: 25.4
[6.009] RX MQTT [praktikum/h2/perintah]: LED_ON     <- dari mosquitto_pub/paho di PC
[10.215] RX MQTT [praktikum/h2/perintah]: LED_OFF
[13.219] RX MQTT [praktikum/h2/perintah]: RESET")

#tbl(
  table(
    columns: (1.5fr, 1.2fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Hasil terukur]),
    [Waktu boot sampai `Wi-Fi OK`], [2,4 s (RSSI −83 dBm)],
    [Waktu boot sampai `MQTT terhubung`], [2,6 s],
    [Publish dikirim / tiba di broker], [8 / 8 (0 % loss)],
    [Interval publish terukur], [5,00 s ± 0,01],
    [Perintah dikirim / memicu `onMessage()`], [3 / 3 (`LED_ON`, `LED_OFF`, `RESET`)],
    [Subscription bertahan setelah reboot board], [ya, re-subscribe 0,2 s setelah connect],
  ),
  [Hasil verifikasi hardware Modul 14],
  "tbl:m14-verifikasi",
)

#catatan[
  *`test.mosquitto.org` sering tidak terjangkau dari jaringan kampus* (port
  1883 keluar diblokir). Gejalanya: `Gagal (rc=-2)` disertai
  `hostByName(): DNS Failed` dan `Host is unreachable`. Solusinya ada di
  `tools/README.md` --- jalankan broker lokal dan arahkan `MQTT_BROKER` ke IP
  laptop.
  #if edisi_buku == "dosen" [Berkas broker lokal itu dimuat lengkap pada
  @bab:lampiran-perkakas.]
]

*Perbaikan kode yang lahir dari uji ini*

#tbl(
  table(
    columns: (1.3fr, 1.2fr),
    align: (left, left),
    inset: (x: 0.55em, y: 0.5em),
    stroke: 0.5pt + luma(170),
    table.header(th[Masalah di perangkat nyata], th[Perbaikan]),
    [`while (WiFi.status() != WL_CONNECTED)` menggantung selamanya bila SSID atau password salah],
    [penantian dibatasi `WIFI_TIMEOUT_MS`, lalu lanjut dan dicoba ulang di `loop()`],
    [`reconnectMQTT()` memblokir `loop()` tanpa batas saat broker tak terjangkau, board tampak hang],
    [dibatasi `MQTT_TIMEOUT_MS` dan langsung keluar bila Wi-Fi belum siap],
  ),
  [Perbaikan kode hasil pengujian perangkat nyata],
  "tbl:m14-perbaikan",
)


// Log serial lengkap dari week14_mqtt/logserial.md. Hanya dicetak pada
// edisi dosen agar tidak disalin mahasiswa sebagai hasil laporan
// (lihat config.typ).
#if edisi_buku == "dosen" [
  === Log Serial Terverifikasi

  Log serial lengkap hasil uji pada board nyata, bukan contoh. Bagian ini
  hanya dicetak pada edisi dosen.

  Hasil aktual dari board nyata ESP32-C6. Baud 115200.

  *Board & Port*

  #tbl(
    table(
      columns: (auto, auto, 1fr, auto),
      align: (left, left, left, left),
      inset: (x: 0.6em, y: 0.45em),
      stroke: 0.5pt + luma(170),
      table.header(th[Node], th[Board], th[Peran], th[Port serial (UART)]),
      [node], [ESP32-C6 DevKitC-1], [Klien MQTT (publish + subscribe)], [`/dev/ttyACM6`],
    ),
    [Board dan port pada rekaman log serial Modul 14],
    "tbl:m14-log-1",
  )

  Konfigurasi: Wi-Fi `SprH-3`, broker MQTT lokal `192.168.1.5:1884` (Mosquitto), client ID `esp32c6-praktikum`.

  *Node (C6) — `/dev/ttyACM6`*

  #keluaran("ESP-ROM:esp32c6-20220919
Build:Sep 19 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:2
load:0x40875730,len:0x1278
load:0x4086b910,len:0xc58
load:0x4086e610,len:0x31c0
entry 0x4086b910
MQTT Node (C6) starting...
Konek Wi-Fi SprH-3...
Wi-Fi OK, IP: 192.168.1.39 | RSSI: -70 dBm
Konek MQTT 192.168.1.5:1884 ...
MQTT terhubung
Subscribe: praktikum/h2/perintah
TX MQTT [praktikum/h2/telemetri]: 25.3
TX MQTT [praktikum/h2/telemetri]: 25.5
TX MQTT [praktikum/h2/telemetri]: 25.1
TX MQTT [praktikum/h2/telemetri]: 26.0
TX MQTT [praktikum/h2/telemetri]: 25.4
TX MQTT [praktikum/h2/telemetri]: 25.8", pecah: true)

  *Verifikasi dari sisi broker (PC)*

  Subscriber di PC (`mosquitto_sub -h 192.168.1.5 -p 1884 -t "praktikum/#" -v`):

  #keluaran("praktikum/h2/telemetri 25.9
praktikum/h2/telemetri 25.3")

  Perintah dari PC ke node (`mosquitto_pub -h 192.168.1.5 -p 1884 -t "praktikum/h2/perintah" -m "LED_ON"`), diterima node:

  #keluaran("RX MQTT [praktikum/h2/perintah]: LED_ON")

  *Catatan*

  - Node terhubung ke Wi-Fi `SprH-3` (2,4 GHz) dan mendapat IP `192.168.1.39`.
  - Node connect ke broker lokal `192.168.1.5:1884` (Mosquitto, port 1884 karena instance sistem terikat loopback; dipakai instance terpisah yang listen 0.0.0.0).
  - Publish `praktikum/h2/telemetri` tiap 5 detik; subscribe `praktikum/h2/perintah`.
  - Komunikasi dua arah terbukti: publish terbaca `mosquitto_sub`, dan perintah `LED_ON` dari `mosquitto_pub` diterima node (`RX MQTT`).
  - Baris `ESP-ROM:esp32c6-…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
]

== Pengukuran

#tbl(
  table(
    columns: (1.1fr, 0.9fr, 0.8fr, 1.3fr, 1fr),
    align: (left, left, left, left, left),
    inset: (x: 0.4em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(
      th[Skenario], th[Interval (s)], th[QoS],
      th[Latency publish ke terima (ms)], th[Success / 20 pesan],
    ),
    [Dekat AP (1 m)], [5], [0 (default)], [#isian], [],
    [Jauh AP (5 m)], [5], [0], [#isian], [],
    [Jauh AP + dinding], [5], [0], [#isian], [],
    [Interval 1 s (modifikasi)], [1], [0], [#isian], [],
  ),
  [Lembar pengukuran latency dan success rate Modul 14],
  "tbl:m14-ukur",
)

Latency diukur dengan cap waktu log publish C6 dibandingkan kemunculan pesan
pada `mosquitto_sub` (gunakan `mosquitto_sub -F '%t %p'` atau timestamp
terminal).

*Tabel pembanding transport --- wajib.* Isi kolom M13 dari data modul
sebelumnya.

#tbl(
  table(
    columns: (1.4fr, 1fr, 1fr),
    align: (left, left, left),
    inset: (x: 0.5em, y: 0.55em),
    stroke: 0.5pt + luma(170),
    table.header(th[Aspek], th[HTTP POST (M13)], th[MQTT publish (M14)]),
    [Koneksi per pesan], [#isian], [],
    [Arah komunikasi], [#isian], [],
    [Perlu tahu alamat penerima?], [#isian], [],
    [Latency rata-rata], [#isian], [],
    [Perilaku saat jaringan putus], [#isian], [],
  ),
  [Tabel pembanding HTTP POST dan MQTT publish],
  "tbl:m14-banding",
)

== Analisis

Jawab berdasarkan tabel bagian Pengukuran.

+ Mengapa model publish/subscribe lebih cocok untuk telemetri IoT dibanding
  HTTP request/response? Dukung dengan tabel pembanding transport.
+ Apa fungsi broker dalam sistem ini dan apa yang terjadi jika broker tidak
  dapat dijangkau?
+ Bagaimana pengaruh RSSI Wi-Fi terhadap latency dan keberhasilan publish?
+ Apa perbedaan QoS 0, 1, dan 2 --- dan QoS berapa yang *sebenarnya* dipakai
  kode ini? Jelaskan batasan PubSubClient.
+ Mengapa topic telemetri dan perintah dipisah, bukan digabung satu topic?
  Kaitkan dengan pola yang sama di M03 dan M08.

== Concept Check

+ Jelaskan perbedaan pesan MQTT dan pesan HTTP dari sisi overhead dan arah
  komunikasi.
+ Apa yang dimaksud topic hierarkis, dan bagaimana wildcard `#` dan `+`
  bekerja?
+ Apa fungsi client ID `esp32c6-praktikum` pada `mqtt.connect()`, dan apa yang
  terjadi bila dua board memakai ID sama?
+ Apa yang terjadi pada subscription bila koneksi MQTT terputus lalu reconnect?
+ Mengapa praktikum ini menggunakan broker publik, dan apa risikonya? Sebutkan
  minimal dua, beserta cara menguranginya.

== Challenge (Tugas Modifikasi)

#tujuan-prak(2, [Retained message dan aksi nyata])[
  / CH-1 --- Retained message: Aktifkan flag _retained_
    (`mqtt.publish(topic, payload, true)`), lalu jalankan subscriber *setelah*
    publish berjalan dan amati apakah pesan terakhir langsung diterima.
    Catatan: argumen ketiga adalah `retained`, *bukan* QoS. Untuk menguji QoS 1
    diperlukan library lain (misalnya `arduino-mqtt` atau `AsyncMqttClient`);
    jelaskan konsekuensinya di laporan.

  / CH-2 --- Aksi nyata: Tambahkan aksi pada perintah: toggle LED bawaan
    berdasarkan `LED_ON` dan `LED_OFF`, lalu publish balik status LED ke
    `praktikum/h2/status`. Ini melengkapi lingkaran perintah, aksi, dan
    laporan.
]

#tujuan-prak(3, [Menghitung loss dan menskalakan topic])[
  / CH-3 --- Packet loss (wajib): Hitung packet loss dengan sequence number
    pada payload (`26.4,#15`). Contoh: 50 publish, 48 diterima subscriber,
    sehingga loss = (50 − 48)/50 × 100 % = 4 %.

  / CH-4 --- Topic per perangkat: Ubah topic menjadi
    `praktikum/<client_id>/telemetri` dan subscribe dengan wildcard
    `praktikum/+/telemetri` di PC. Diskusikan bagaimana skema ini menskalakan
    ke 50 perangkat.
]

== Laporan

*Deliverable*

+ Misi dan capaian pembelajaran.
+ Dasar teori ringkas (MQTT, broker, publish/subscribe, topic, QoS, retained,
  batasan PubSubClient).
+ Konfigurasi --- SSID, broker, client ID, topic, dan library PubSubClient.
+ Hasil eksperimen --- log Serial Monitor *dan* log `mosquitto_sub` serta
  `mosquitto_pub` (EXP-01 sampai EXP-03 beserta checkpoint).
+ Data pengukuran --- tabel bagian Pengukuran *dan* tabel pembanding HTTP
  dengan MQTT.
+ Analisis dan concept check.
+ Challenge --- minimal CH-2 dan CH-3.
+ Kesimpulan yang ditulis sendiri berdasarkan hasil pengujian.
