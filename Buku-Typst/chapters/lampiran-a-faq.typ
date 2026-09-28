// ============================================================================
// Lampiran A — Tanya Jawab (FAQ)
// Sumber: FAQ.md pada akar repositori WSN-IOT-prak.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, catatan, tip
#import "../lib/helpers.typ": tbl, th, diagram, keluaran, kode-berkas, sumber-kode, gh, gh-folder

#chapter("Tanya Jawab (FAQ)", l: "bab:lampiran-faq")

Lampiran ini merangkum pertanyaan yang berulang muncul di laboratorium beserta
jawabannya. Isinya melengkapi bagian Dasar Teori tiap modul, terutama untuk
pertanyaan yang melintasi beberapa modul sekaligus.

== Ringkasan Modul Minggu 1--16

#tbl(
  table(
    columns: (auto, auto, 1.4fr, 1fr),
    align: (center + horizon, left, left, left),
    inset: (x: 0.5em, y: 0.42em),
    stroke: 0.5pt + luma(170),
    table.header(th[Minggu], th[Modul], th[Topik], th[Keterangan]),
    [1], [`week01_ble_p2p`], [Establish a BLE Link (koneksi P2P H2 ke H2)], [BLE],
    [2], [`week02_ble_p2p_data`], [Exchange Data (notify + write dua arah)], [BLE],
    [3], [`week03_ble_client_server`], [Build a BLE Service (GATT read/write)], [BLE],
    [4], [`week04_ble_telemetry`], [Stream Telemetry (server ke client, notify)], [BLE],
    [5], [`week05_ble_multinode`], [Connect Multiple Devices (1 pusat ke banyak node)], [BLE],
    [6], [`week06_ble_mesh`], [Build a BLE Mesh (relay H2--H2--H2)], [*BLE mesh*],
    [7], [`week07_802154_p2p`], [Speak Raw 802.15.4 (frame mentah H2 ke H2)], [802.15.4 mentah],
    [8], [`week08_zigbee_p2p`], [Join a Zigbee Network (Coordinator ke End Device)], [Zigbee (di atas 802.15.4)],
    [9], [`week09_zigbee_multinode`], [Scale the Network (Coordinator ke beberapa ED)], [Zigbee (di atas 802.15.4)],
    [10], [`week10_zigbee_mesh`], [Route Through the Mesh (Coordinator--Router--ED)], [*Zigbee mesh* (di atas 802.15.4)],
    [11], [`week11_thread_p2p`], [Speak IPv6 over Thread (UDP H2 ke H2)], [Thread (di atas 802.15.4)],
    [12], [`week12_thread_mesh`], [Mesh the Internet (mesh IPv6 multi-node)], [*Thread mesh* (di atas 802.15.4)],
    [13], [`week13_thread_wifi_gateway`], [Bridge Thread to Wi-Fi (H2 ke C6 ke Wi-Fi)], [Thread + Wi-Fi],
    [14], [`week14_mqtt`], [Publish to the Cloud (C6 ke broker MQTT)], [Wi-Fi/MQTT],
    [15], [`week15_e2e_iot`], [Build End-to-End IoT System (H2 → Thread → C6 → MQTT)], [Thread + Wi-Fi/MQTT],
    [16], [`week16_comparative`], [Prove Your Protocol (benchmark BLE/Zigbee/Thread)], [BLE/Zigbee/Thread → MQTT],
  ),
  [Ringkasan topik tiap minggu praktikum],
  "tbl:faq-ringkasan",
)

Rangkuman: minggu 1--6 membahas BLE (dari P2P sampai mesh), minggu 7 membahas
802.15.4 mentah, minggu 8--10 Zigbee, minggu 11--12 Thread, minggu 13--15
integrasi gateway/MQTT/end-to-end, dan minggu 16 perbandingan protokol berbasis
data.

== Pertanyaan Umum

=== Yang hanya 802.15.4 itu minggu berapa saja?

Hanya *minggu 7* (`week07_802154_p2p`) yang memakai 802.15.4 mentah atau
telanjang. Minggu 8--10 (Zigbee) dan 11--12 (Thread) juga berjalan di atas
radio 802.15.4, tetapi sudah sebagai protokol lapisan atas.

=== Yang mesh itu minggu berapa saja?

- *Minggu 6* --- BLE mesh (relay).
- *Minggu 10* --- Zigbee mesh (routing).
- *Minggu 12* --- Thread mesh (IPv6).

=== Apa yang dilakukan minggu 7?

Minggu 7 (`week07_802154_p2p`) adalah *raw 802.15.4 P2P*: menyusun frame MAC
802.15.4 byte demi byte (Len + MHR 11 byte + payload) tanpa stack
Zigbee/Thread/BLE, lalu mengirim PING/PONG langsung antar dua ESP32-H2 lewat
API ESP-IDF `esp_ieee802154.h` (channel 15, PAN ID `0xCAFE`, short address
`0x0001`/`0x0002`), sambil mengukur RSSI, latency RTT, dan packet loss tiap
arah. Ini menjadi baseline radio untuk M16.

=== Di minggu 7 masing-masing menjadi end device?

Tidak. Minggu 7 tidak mengenal konsep Coordinator/End Device --- radio 802.15.4
dipakai telanjang tanpa stack Zigbee. Kedua ESP32-H2 adalah *peer setara*:
Node1 (`0x0001`) pengirim PING dan penerima balasan, Node2 (`0x0002`) penerima
dan pembalas PONG. Peran Coordinator dan End Device baru muncul pada minggu
8--10 (Zigbee).

=== Bukankah 802.15.4 juga mengenal end device, router, dan koordinator?

Sebagian benar; jawabannya campuran.

*Ada di 802.15.4 (tingkat PHY/MAC):* FFD (_Full Function Device_) dan RFD
(_Reduced Function Device_), serta PAN Coordinator --- perangkat yang boleh
memulai PAN. Konsep ini didefinisikan standar 802.15.4 sendiri.

*Tetapi "Router" dan End Device sebagai peran jaringan:*

- *802.15.4 murni tidak memiliki routing.* Frame hanya point-to-point (atau
  broadcast); tidak ada multi-hop. Jadi konsep "router" yang meneruskan paket
  untuk node lain *bukan* bagian 802.15.4 --- itu berada di lapisan atas.
- *Zigbee* (di atas 802.15.4) mendefinisikan ZC/ZR/ZED (Zigbee Coordinator,
  Router, End Device).
- *Thread* memiliki peran sendiri yang berbeda lagi: Leader, Router, REED, dan
  End Device (SED).

Jadi pada minggu 7 kedua board adalah RFD/FFD telanjang tanpa peran jaringan
--- karena itulah disebut "peer setara".

=== Kalau 3 device saling komunikasi, termasuk node, RFD, FFD, atau PAN Coordinator?

Bergantung lapisannya.

*Di 802.15.4 murni* (bila menerapkan standar penuh, termasuk beacon dan
association):

- Harus ada *minimal satu FFD yang menjadi PAN Coordinator* (yang memulai PAN).
- Device lain dapat berupa FFD (boleh menjadi coordinator biasa) atau RFD
  (paling sederhana: tidak boleh menjadi coordinator).
- Jadi ketiga device itu terdiri atas 1 PAN Coordinator (FFD) dan sisanya
  FFD/RFD sesuai kemampuan.

*Di lab minggu 7* (802.15.4 telanjang):

- Kode tidak memakai beacon, association, maupun role sama sekali --- semua
  device hanya dikonfigurasi channel, PAN ID, dan short address, lalu saling
  kirim. Maka ketiganya *cukup disebut node* (peer), tidak ada yang diangkat
  menjadi PAN Coordinator. Secara formal ini _peer-to-peer topology_ 802.15.4
  yang tidak memakai peran.

*Di Zigbee* (minggu 9, 3 device): peran baru dipetakan eksplisit, yaitu 1 ZC
(Coordinator) dan sisanya ZED (End Device), atau ZR bila ikut routing.

=== Tanpa ZED, hanya memakai protokol 802.15.4, apakah bisa saling komunikasi?

Bisa, dan itulah yang dibuktikan minggu 7: dua atau lebih device cukup
dikonfigurasi *channel, PAN ID, dan short address*, lalu langsung saling kirim
frame --- tanpa stack Zigbee dan tanpa ZED/ZC. ZED adalah peran lapisan Zigbee,
bukan prasyarat komunikasi 802.15.4.

=== Apakah tidak saling tabrakan ketika 5 device saling komunikasi di 802.15.4 tanpa Zigbee?

Sebagian besar tidak, karena *lapisan MAC 802.15.4 sudah memiliki mekanisme
anti-tabrakan bawaan*: sebelum mengirim, radio melakukan CSMA/CA ---
mendengarkan kanal lebih dulu (CCA), bila sibuk menunggu mundur secara acak
(backoff), baru kemudian mengirim. Catatannya:

- CSMA/CA *mengurangi, bukan menghilangkan* tabrakan --- dua device yang mulai
  mengirim bersamaan tetap bisa bentrok.
- Pada minggu 7 tidak dipakai ACK maupun retransmit (frame mentah), sehingga
  frame yang bertabrakan *hilang* dan terlihat sebagai packet loss.
- Tidak ada slot terjadwal (TDMA), karena tidak ada beacon maupun koordinator.

Karena itulah pada Zigbee dan Thread terdapat lapisan tambahan berupa ACK,
retry, dan routing.

=== Apa yang harus disamakan agar 5 device saling berkomunikasi di 802.15.4 tanpa Zigbee/Thread?

Yang wajib sama: *channel radio, PAN ID, dan format frame* (Len dan MHR yang
sama). Alamat (short address) harus *berbeda* tiap device supaya penerima dapat
membedakan pengirim. Bila semua harus saling mendengar, dapat dipakai alamat
tujuan `0xFFFF` (broadcast) --- tetapi tanpa ACK. Yang *tidak* perlu disamakan:
tidak ada ZC/ZED/router, tidak ada join, dan tidak ada dataset.

=== Apakah ada mekanisme auto-join di 802.15.4?

Ada --- standar 802.15.4 sendiri mendefinisikan mekanisme _association_ (MLME):

+ *Scan*: device baru melakukan _active_ atau _passive scan_ untuk mencari
  beacon dari coordinator.
+ *Associate*: mengirim _association request_ ke coordinator yang ditemukan.
+ *Pemberian alamat*: coordinator menjawab dan memberikan short address baru,
  PAN ID, dan seterusnya --- device otomatis masuk jaringan tanpa konfigurasi
  manual.

Syaratnya, coordinator harus menjalankan _beacon-enabled mode_, dan kedua pihak
mengimplementasikan prosedur MLME (bukan sekadar API radio mentah).
`esp_ieee802154.h` pada minggu 7 *tidak* menyediakan itu --- API-nya hanya
TX/RX frame, sehingga association harus ditulis manual. Secara praktis, itulah
yang dilakukan Zigbee dan Thread: keduanya memakai asosiasi 802.15.4 sebagai
fondasi.

=== Jadi tanpa Zigbee/Thread tidak bisa otomatis join?

Tepatnya: *mekanismenya ada di standar 802.15.4* (prosedur association MLME
beserta beacon), jadi secara teori bisa tanpa Zigbee/Thread. Namun praktiknya:

- Prosedur MLME harus ditulis sendiri: beacon mode di coordinator, scan,
  association request/response, dan manajemen alamat --- ratusan baris kode
  yang rawan salah.
- API mentah (`esp_ieee802154.h`) tidak menyediakannya.

Singkatnya: bisa secara teori, tidak praktis di lapangan. Join otomatis yang
tinggal pakai memang praktisnya berasal dari Zigbee atau Thread.

=== Apakah ada proteksi keamanan standar di jaringan 802.15.4?

Ada, tetapi opsional dan berlapis.

*Di 802.15.4 (lapisan MAC):*

- Mendukung AES-128 dengan mode CCM\* (enkripsi dan autentikasi), _frame
  counter_ (anti-replay), dan MIC (cek integritas).
- Semuanya diatur lewat _security suite_ --- paket dapat dienkripsi penuh atau
  hanya diautentikasi.
- *Tetapi* default pada banyak implementasi (termasuk minggu 7) adalah *tanpa
  keamanan* --- frame dikirim polos. Manajemen kuncinya juga lemah. Jadi bila
  tidak diaktifkan, siapa pun dengan radio 802.15.4 pada channel yang sama
  *dapat menyadap*.

*Di Zigbee:* ditambahkan enkripsi lapisan APS (network key dan link key).

*Di Thread:* ditambahkan keamanan lapisan jaringan (DTLS, enkripsi IPv6, dan
lain-lain).

=== Apakah proteksi standar itu dapat diimplementasikan di ESP32-H2?

Bisa, dengan catatan:

- *Perangkat kerasnya mendukung*: ESP32-H2 memiliki akselerator AES-128 (dipakai
  lewat mbedTLS atau `esp_aes`).
- *Tetapi API raw `esp_ieee802154.h` tidak menyediakan cara instan untuk
  mengaktifkan security* --- tidak ada fungsi untuk menyetel security suite.
  Bila menghendaki frame raw terenkripsi, AES-CCM\* (enkripsi dan MIC) harus
  diimplementasikan sendiri di perangkat lunak, lalu security header
  ditambahkan dan nilai `Len` diperhitungkan ulang --- persis seperti cara
  minggu 7 menyusun MHR secara manual.
- *Praktisnya*, Zigbee dan Thread pada ESP32-H2 sudah mengimplementasikan
  keamanan itu secara otomatis di dalam stack-nya.

=== Apakah mungkin XBee 802.15.4 berkomunikasi dengan ESP32-H2?

Secara fisik (PHY) ya, karena keduanya sama-sama IEEE 802.15.4. Secara praktis
tidak langsung, karena:

- *XBee Seri 1/802.15.4 memakai firmware Digi* dengan format payload RF sendiri
  (header 8 byte alamat, RSSI, dan options byte) di dalam frame MAC 802.15.4.
  XBee hanya dapat berkomunikasi lancar dengan sesama radio Digi.
- ESP32-H2 raw (minggu 7) menyusun frame MAC polos. Jadi komunikasi memerlukan
  replikasi format payload XBee di sisi H2, ditambah penyesuaian addressing
  64-bit, kanal, PAN, dan penonaktifan enkripsi XBee. Ini merupakan solusi yang
  rapuh dan tidak didukung vendor.
- Bila yang dipakai XBee Seri 2 (Zigbee): gunakan stack Zigbee pada ESP32-H2
  (minggu 8--10) sebagai Coordinator lalu pairing ke XBee S2 --- interop Zigbee
  resmi.

Kesimpulannya, cara yang mulus hanya XBee ke XBee, atau H2-Zigbee ke XBee S2.

=== Berapa bit payload di minggu 7?

Payload default `"PING n"` kurang lebih *7 byte = 56 bit* (contoh `PING 38`
pada dump). Nilai `Len` = 11 (MHR) + 7 (payload) + 2 (FCS) = *20 byte
(`0x14`)*. Pada CH-2 tersedia opsi memperbesar payload menjadi 40 byte.

=== Apakah ada standar maksimal payload di 802.15.4?

Ada. Standar IEEE 802.15.4 menetapkan frame PHY maksimal *127 byte* (PSDU):

- MHR minimal 11 byte (seperti minggu 7): payload maksimal kurang lebih
  127 − 11 − 2 (FCS) = *114 byte*.
- MHR maksimal 25 byte (semua field alamat extended): payload kurang lebih
  100 byte.
- Dengan security (AES-CCM\*): berkurang lagi sesuai security header dan MIC.

Jadi batasnya bukan di aplikasi, melainkan di PHY: 127 byte per frame.

=== Rentang nilai PAN ID, address, dan lainnya di minggu 7

#tbl(
  table(
    columns: (auto, auto, 1.4fr, 1fr),
    align: (left, center + horizon, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Parameter], th[Lebar], th[Range valid], th[Nilai di minggu 7]),
    [Channel], [---], [11--26 (2,4 GHz)], [15],
    [PAN ID], [16 bit], [`0x0000`--`0xFFFF` (`0xFFFF` = broadcast PAN)], [`0xCAFE`],
    [Short address], [16 bit], [`0x0000`--`0xFFFF` (`0xFFFF` = broadcast, `0xFFFE` = reserved)], [`0x0001`, `0x0002`],
    [Extended address], [64 bit], [`0x0000…`--`0xFFFF…`], [tidak dipakai],
    [Len (frame PHY)], [8 bit], [1--127 byte], [20 byte (`0x14`)],
    [FCS], [16 bit], [dihitung hardware], [otomatis],
  ),
  [Rentang nilai parameter radio 802.15.4 pada Modul 07],
  "tbl:faq-range-802154",
)

Short address `0xFFFF` dipakai pada CH-4 (broadcast) untuk mengirim ke semua
node.

== Matter

=== Apa itu Matter?

Matter adalah *standar smart home bersama* (CSA --- Apple, Google, Amazon,
Samsung, dan lain-lain) yang menyatukan protokol rumah pintar di atas IP.

- *Jalur transport utama*: Thread (di atas 802.15.4) untuk perangkat low-power,
  ditambah Wi-Fi untuk perangkat kaya sumber daya, dan BLE hanya untuk
  _commissioning_ (onboarding awal).
- BLE dipakai sekali saat setup (kode QR atau pairing), setelah itu perangkat
  berkomunikasi via Thread atau Wi-Fi.
- Thread pada ESP32-H2 (minggu 11--13) adalah fondasi yang dipakai Matter ---
  gateway Thread ke Wi-Fi pada minggu 13 analog dengan _Thread Border Router_
  dalam ekosistem Matter.
- Di atasnya, Matter memakai IPv6, mDNS, dan CoAP (bukan MQTT seperti pada
  lab).

=== Layer Matter --- diagram stack

#diagram(```
┌───────────────────────────────────────────────────────────────┐
│  APLIKASI Smart Home (control, light, thermostat, sensor)     │
├───────────────────────────────────────────────────────────────┤
│  MATTER Application Layer (clusters, data model)              │
│  Interaction Model + Action Framing                           │
│  Security (Message Layer: encryption, node ID)                │
│  Transport: UDP (reliable via ACK layer) / TCP                │
├───────────────────────────────────────────────────────────────┤
│  IPv6  (mDNS discovery, per-node IPv6)                        │
├──────────────────┬────────────────────┬───────────┬───────────┤
│  THREAD          │      Wi-Fi         │ Ethernet  │    BLE    │
│  (IPv6 + 6LoWPAN)│    (IPv6)          │  (IPv6)   │ (hanya    │
│  ─────────────── │                    │           │  commis-  │
│  802.15.4 PHY/MAC│  802.11 PHY/MAC    │           │  sioning) │
└──────────────────┴────────────────────┴───────────┴───────────┘
```.text)

Posisi Matter adalah *lapisan aplikasi/protokol di atas IP*, tidak mengikat
satu radio:

- *Di atas Thread* (Thread = IPv6 di atas 6LoWPAN di atas 802.15.4) --- jalur
  utama perangkat low-power.
- *Di atas Wi-Fi* --- perangkat bertenaga listrik.
- *BLE* hanya saat commissioning, bukan jalur data.
- *Zigbee tidak ada di stack Matter* --- ia protokol saudara pada radio yang
  sama (802.15.4) dan masuk lewat _bridge_ Matter--Zigbee bila diperlukan.

Dibandingkan dengan lab: minggu 11--13 (Thread dan gateway) kurang lebih
merupakan dasar Matter; minggu 14 (MQTT) adalah jalur alternatif yang tidak
dipakai Matter --- Matter memilih CoAP/IP langsung.

=== Mengapa Zigbee tidak digambar di stack Matter?

Karena Zigbee memang bukan bagian dari stack Matter --- ia merupakan jalur
paralel.

#diagram(```
   ┌──────────────────────────────┐
   │        APLIKASI Smart Home   │
   ├──────────────────────────────┤
   │       MATTER (CSA)           │
   │  Application clusters        │
   │  Interaction Model / Framing │
   │  Message Layer (security)    │
   │  Transport UDP/TCP           │
   ├──────────────────────────────┤
   │        IPv6 + mDNS           │
   └──────┬───────────┬───────────┘
           │           │
  ┌───────┴─────┐ ┌───┴───────────────┐   ┌──────────────┐
  │   THREAD    │ │      Wi-Fi        │   │   BLE        │
  │ UDP/CoAP    │ │   UDP/TCP         │   │ GATT         │
  │ 6LoWPAN     │ │   802.11 PHY/MAC  │   │ (commissioning│
  │ mesh route  │ │                  │   │  saja)        │
  │ 802.15.4    │ │                  │   │              │
  └──────┬──────┘ └──────────────────┘   └──────────────┘
         │
  ┌──────┴──────────┐      ┌───────────────────────────┐
  │ IEEE 802.15.4   │◄────►│        ZIGBEE (jalur lain)│
  │ PHY/MAC bersama │      │ APS security              │
  │ (channel,PAN,   │      │ NWK routing (ZC/ZR/ZED)   │
  │  CSMA-CA, AES)  │      │ 802.15.4 PHY/MAC (sama)   │
  └─────────────────┘      └────────────┬──────────────┘
                                        │
                                  ┌─────┴─────┐
                                  │  Zigbee   │
                                  │ End Device│
                                  │ (lampu,dst│
                                  └───────────┘

  Hubungan Zigbee ↔ Matter: lewat BRIDGE
  ┌──────────────┐        ┌──────────────────────────┐
  │ Matter device│ ◄────► │  Bridge (Zigbee + Matter) │
  └──────────────┘        └─────────────┬────────────┘
                                        │
                                  ┌─────┴─────┐
                                  │ Zigbee    │
                                  │ network   │
                                  └───────────┘
```.text)

Di mata Matter, Zigbee bukan jalur IP --- perangkat Matter asli tidak pernah
berbicara Zigbee. Zigbee masuk hanya sebagai *jaringan lama yang dijembatani*
(bridge mengubah Zigbee cluster menjadi Matter cluster dan sebaliknya).
Sementara itu Thread, Wi-Fi, Ethernet, dan BLE seluruhnya didukung resmi dalam
satu stack yang sama. Dalam konteks lab, minggu 8--10 (Zigbee) dan 11--13
(Thread) berbagi *radio 802.15.4 yang sama* --- tetapi hanya jalur Thread yang
menjadi fondasi Matter.

=== Apakah ESP32-H2 mendukung Matter?

Ya. ESP32-H2 justru chip yang ideal untuk Matter, karena radio yang dimilikinya
(BLE dan IEEE 802.15.4/Thread) persis yang dibutuhkan Matter:

- *Thread* sebagai jalur komunikasi utama (Matter over Thread, IPv6).
- *BLE* untuk commissioning (pairing kode QR pertama kali).
- Espressif menyediakan *ESP-Matter SDK* (berbasis connectedhomeip/CHIP) dengan
  ESP32-H2 sebagai salah satu chip resmi yang didukung.

#catatan[
  Karena H2 tidak memiliki Wi-Fi, ia hanya bisa menjadi *Matter End Device over
  Thread* --- bukan Thread Border Router, karena peran itu membutuhkan Wi-Fi
  atau Ethernet, misalnya ESP32-C6 yang memiliki Wi-Fi dan 802.15.4 sekaligus,
  persis kombinasi yang dipakai pada minggu 13 dan 15.
]

=== Apakah sudah ada library Matter untuk ESP32-C6/ESP32-H2?

Ya, resmi dari Espressif:

- *ESP-Matter SDK* (`espressif/esp_matter`, komponen di ESP-IDF Component
  Registry). Berbasis connectedhomeip (CHIP) dari CSA, dan resmi mendukung
  ESP32-H2 (Matter over Thread) serta ESP32-C6 (Thread dan Wi-Fi, dapat menjadi
  Border Router).
- Tersedia pula *ESP Thread Border Router* (`esp-thread-br`) untuk C6 sebagai
  border router.
- Contoh siap pakai terdapat pada repositori `esp-matter` (light, switch,
  thermostat, sensor) dengan contoh khusus `esp32h2` dan `esp32c6`.

#penting[
  Belum ada library Matter resmi untuk Arduino core --- ESP-Matter berjalan di
  atas ESP-IDF, bukan PlatformIO/Arduino. Jadi untuk mencoba Matter, jalurnya
  berpindah ke proyek ESP-IDF dengan komponen `esp_matter`, bukan menambah
  library pada `platformio.ini`.
]

=== Apakah masalah minggu 15 dapat diperbaiki dengan Matter?

Persoalan M15 bukan terletak pada Thread, melainkan pada gateway C6 yang hanya
memiliki satu chip dan satu antena --- Wi-Fi dan 802.15.4 berebut airtime
(end-to-end 0--36 %, pada AP-3 hanya 5 %), ditambah MQTT QoS 0 yang membuat
`publish()` tampak sukses padahal belum tentu sampai. Hop Thread sendiri selalu
0 % loss.

Apakah Matter memperbaikinya? Sebagian ya, tetapi inti masalahnya tidak.

*Yang diperbaiki Matter:*

- *Hop Thread H2 ke C6.* M15 memakai UDP multicast tanpa ACK sehingga paket
  yang bertabrakan hilang. Matter memakai unicast dengan ACK layer (MAC ACK,
  retry Thread, dan ACK pada Message Layer) sehingga tabrakan dipulihkan, bukan
  dibuang. Di sisi sensor, H2 Matter over Thread bahkan tidak membutuhkan Wi-Fi
  sama sekali, sehingga tidak ada persoalan koeksistensi pada node sensor.
- *Hop MQTT hilang dari jalur utama.* Matter tidak memakai MQTT (memakai
  CoAP/UDP dengan ACK pada application layer), sehingga masalah "publish sukses
  palsu" menjadi tidak relevan.

*Yang tidak diperbaiki Matter:*

- *Inti masalah M15: satu antena C6 membagi airtime Thread dan Wi-Fi.* Border
  router Matter pada C6 tetap menjalankan Thread dan Wi-Fi bersamaan, sehingga
  masalah fisik yang sama tetap ada. Matter tidak mengubah perangkat keras.
- Bila dashboard atau cloud tetap menjadi tujuan akhir, tetap diperlukan
  jembatan keluar Wi-Fi --- hop yang sama tetap ada.

*Kesimpulan:* Matter bukan perbaikan langsung, melainkan mengubah arsitektur ke
arah yang lebih benar --- pengiriman unicast yang andal menggantikan multicast
tanpa ACK. Perbaikan nyata untuk M15 yang direkomendasikan tetap berlaku:
border router dua chip (atau gateway khusus), bukan stack pengganti.

== Parameter Radio dan 6LoWPAN

=== Efek parameter PAN ID, channel, dan broadcast --- dapatkah diubah dari program saja?

Ya, hampir semuanya cukup dengan mengganti empat `#define` pada
`src/nodeX/main.cpp` (`CHANNEL`, `PAN_ID`, `MY_ADDR`, `PEER_ADDR`), tanpa
mengubah logika program.

#tbl(
  table(
    columns: (auto, 1fr, 1.4fr),
    align: (left, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Eksperimen], th[Yang diubah], th[Efek yang terlihat]),
    [PAN ID sama], [`PAN_ID` sama (misalnya `0xCAFE` pada dua node)], [komunikasi normal],
    [PAN ID beda], [`PAN_ID` pada salah satu node dibedakan], [TX tetap jalan, RX sunyi --- frame *disaring hardware* (promiscuous dimatikan), tidak ada callback],
    [Channel sama], [`CHANNEL` sama], [komunikasi normal],
    [Channel beda], [`CHANNEL` salah satu node dibedakan], [RX sunyi total --- radio *tuli*, tidak mendengar apa pun],
    [Broadcast], [`PEER_ADDR = 0xFFFF`], [semua node pada channel dan PAN yang sama menerima frame yang sama],
  ),
  [Efek perubahan parameter radio pada Modul 07],
  "tbl:faq-efek-parameter",
)

Catatan praktis:

+ *Tiap perubahan harus diikuti unggah ulang node yang diubah*, karena
  parameter dikompilasi, bukan diatur saat runtime. Isi tabel "channel
  sama/PAN beda, apa gejalanya" dan "channel beda/PAN sama, apa gejalanya"
  pada laporan agar perbedaannya terlihat: yang satu _heard but filtered_
  (terdengar tetapi disaring), yang satu _never heard_ (tidak pernah
  terdengar).
+ *Broadcast memerlukan node ketiga* (`src/node3`, `MY_ADDR 0x0003`) supaya
  efeknya nyata --- bukan sekadar sama saja dengan unicast.
+ *Filter PAN tidak aktif dengan sendirinya.* Driver ESP-IDF menyalakan
  promiscuous mode secara default, sehingga tanpa
  `esp_ieee802154_set_promiscuous(false)` di `setup()` node dengan PAN ID
  berbeda tetap saling menerima --- berbeda dengan XBee yang selalu menyaring.
+ EXP-05 (promiscuous mode): `esp_ieee802154_set_promiscuous(true)` membuat semua
  frame diterima walaupun PAN atau alamatnya berbeda; ini membuktikan
  penyaringan terjadi di *hardware*, bukan di kode.

=== Apakah 6LoWPAN didukung ESP32-H2?

Ya. ESP32-H2 mendukung 6LoWPAN --- bukan sebagai library terpisah, melainkan
terintegrasi di stack OpenThread yang dipakai pada minggu 11--13.
`OThread`/ESP-IDF menyediakan IPv6 dan 6LoWPAN (kompresi header dan fragmentasi
802.15.4) di atas radio 802.15.4. Buktinya, UDP IPv6 multicast
`ff03::abcd:5050` pada minggu 11--13 berjalan di atas 6LoWPAN.

#catatan[
  6LoWPAN *tidak* tersedia lewat API radio mentah `esp_ieee802154.h` (minggu 7)
  --- API itu hanya PHY/MAC telanjang. Bila menghendaki 6LoWPAN murni (tanpa
  stack Thread penuh), jalur normalnya tetap melalui OpenThread.
]

== Zigbee

=== Di minggu 8 (Zigbee P2P) haruskah 1 End Device + 1 Coordinator? Bagaimana kombinasi lain?

*Pertama, haruskah 1 ZC + 1 ZED pada minggu 8?* Ya, sesuai desain modul ---
bukan sekadar kebiasaan. Jaringan Zigbee *wajib memiliki tepat satu Coordinator
(ZC)* untuk membentuk PAN; tanpa ZC tidak ada jaringan yang dapat di-join.
Minggu 8 juga memakai _find-and-bind_ yang dikelola coordinator. Ini adalah
topologi paling umum di dunia nyata (hub dan perangkat).

*Kedua, dua End Device saling komunikasi?* Tidak bisa begitu saja:

- Dua ZED *tidak dapat membentuk jaringan* --- ZED adalah daun (leaf), tidak
  boleh memiliki anak atau meneruskan trafik.
- Keduanya baru dapat berkomunikasi bila *sama-sama join ke jaringan yang sama*
  (sehingga ZC tetap wajib ada), dan trafiknya melewati orang tua (topologi
  bintang). Sebagai demo P2P, cara ini tidak disarankan.

*Ketiga, 1 ZED + 1 Router?* Bisa dan umum di dunia nyata (router dengan sensor
tidur), tetapi:

- *Router (ZR) tetap membutuhkan jaringan* --- ZED dan ZR saja tanpa ZC tidak
  dapat berdiri sendiri.
- Pada Arduino core 3.x, peran ZC dan ZR digabung dalam satu build flag
  `-DZIGBEE_MODE_ZCZR`: firmware tersebut *membentuk network sebagai ZC bila
  belum ada*, atau *join sebagai ZR bila network sudah ada*. Jadi kombinasi
  ZCZR dan ED otomatis menjadi ZC--ZED di lab, sedangkan dua board ZCZR akan
  menjadi ZC--ZR.

#tbl(
  table(
    columns: (auto, auto, auto, 1.2fr),
    align: (left, left, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Kombinasi], th[Bisa?], th[Umum?], th[Catatan]),
    [ZC + ZED], [ya, wajib sebagai dasar], [paling umum], [dipakai minggu 8],
    [ZED + ZED], [hanya lewat ZC/parent], [tidak disarankan], [dua daun tidak saling bicara langsung],
    [ZR + ZED], [ya, setelah ada ZC], [umum di lapangan], [pada kode praktikum berarti ZCZR + ED],
  ),
  [Kombinasi peran perangkat Zigbee],
  "tbl:faq-kombinasi-zigbee",
)
