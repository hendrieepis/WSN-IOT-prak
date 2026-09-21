// ============================================================================
// Pendahuluan — konversi dari README.md pada akar repositori WSN-IOT-prak.
//
// Bab ini sengaja tidak diberi nomor agar Modul 00A tetap menjadi modul
// pertama. Seluruh isi dibungkus dalam satu blok konten sehingga aturan
// `set` di bawah (penomoran heading dan figure) hanya berlaku di bab ini.
// ============================================================================

#import "../lib/callouts.typ": penting, catatan
#import "../lib/helpers.typ": tbl, th, diagram, keluaran, kode-berkas, sumber-kode, gh, gh-folder, REPO

#[
#set heading(numbering: none)
// Tabel pada bab tanpa nomor diberi awalan "P" (Pendahuluan) supaya tidak
// tertulis sebagai "Tabel 0.1" akibat nomor bab yang belum berjalan.
#set figure(numbering: n => "P." + str(n))

= Pendahuluan <bab:pendahuluan>

== Tentang Lab Ini

Buku ini bukan kumpulan tutorial Arduino, melainkan buku kerja laboratorium.
Setiap minggu merupakan satu misi rekayasa dengan target sukses yang terukur,
prosedur eksperimen yang tertulis, dan data yang harus dikumpulkan sendiri oleh
praktikan.

Fokusnya adalah protokol komunikasi --- mulai dari Bluetooth Low Energy, IEEE
802.15.4, Zigbee, Thread, hingga integrasi Wi-Fi/MQTT --- di atas board
ESP32-H2 dan ESP32-C6. Kompetensi dibangun bertahap: point-to-point, kemudian
client-server, multi-node, dan mesh, pada tiga keluarga protokol, lalu ditutup
dengan integrasi end-to-end ke Internet dan proyek perbandingan protokol
berbasis data.

== Struktur Setiap Modul

Seluruh modul memakai format yang sama, terdiri atas sebelas bagian seperti
pada @tbl:p-struktur-modul.

#tbl(
  table(
    columns: (auto, auto, 1fr),
    align: (center + horizon, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Bagian], th[Isi]),
    [1], [*Pendahuluan*],
    [Identitas modul (misi, durasi, mode, level, instrumen), keterkaitan dengan modul lain, prasyarat, dan apa yang dipakai lagi sesudahnya --- seluruhnya dalam bentuk kalimat, ditutup peta blok dan kontrak data],
    [2], [*Capaian Pembelajaran*],
    [4--5 capaian *terukur* beserta kriteria keberhasilan],
    [3], [*Dasar Teori (secukupnya)*],
    [Hanya istilah yang dipakai di percobaan, beserta sekuens protokol],
    [4], [*Topologi*],
    [Diagram jaringan bernama board, peran tiap node, peta alamat],
    [5], [*Alat yang Digunakan*],
    [Platform, alat dan bahan sampai versi/port, `platformio.ini`, pre-flight, perintah deploy],
    [6], [*Percobaan*],
    [EXP-01 sampai EXP-03 dengan *CHECKPOINT* di tiap tahap, beserta log referensi hasil uji nyata],
    [7], [*Pengukuran*],
    [Tabel yang diisi sendiri dan tabel pembanding lintas modul],
    [8], [*Analisis*],
    [Pertanyaan yang hanya bisa dijawab dari tabel Pengukuran],
    [9], [*Concept Check*],
    [Pertanyaan konseptual, bukan hafalan],
    [10], [*Challenge*],
    [Tugas *modifikasi kode*, bukan "jelaskan hasilnya"],
    [11], [*Laporan*],
    [Daftar deliverable],
  ),
  [Sebelas bagian baku pada setiap modul praktikum],
  "tbl:p-struktur-modul",
)

Tiga hal membedakan format ini dari panduan praktikum biasa.

/ CHECKPOINT di tengah percobaan: Mahasiswa memverifikasi progres sebelum
  lanjut, bukan baru ketahuan salah di akhir sesi.

/ "Buka abstraksinya": Satu kotak per modul yang menyuruh mahasiswa membongkar
  satu baris kode yang tampak sepele (misalnya mengomentari `subscribe()` lalu
  melihat notify berhenti) --- menghubungkan API dengan apa yang sebenarnya
  terjadi di udara.

/ Teori dibatasi: Panduan ini menjawab *bagaimana*; pembahasan mendalam
  (*mengapa*) berada pada buku teori terpisah. Tiap bagian Dasar Teori
  menyebut batas itu secara eksplisit.

== Keterkaitan Antar-Modul

IoT adalah stack berlapis, sehingga modulnya bukan pulau-pulau terpisah. Dua
mekanisme dipakai untuk mengikatnya.

*Pertama, rantai prasyarat.* Tiap modul menyatakan apa yang harus sudah
dikuasai, apa yang ditambahkannya, dan modul mana yang akan memakainya lagi.

#diagram(```
M01 tautan ─► M02 payload ─► M03 state+perintah ─► M04 telemetry ─► M05 multi-node ─► M06 hop
                                                                                       │
                                            ┌──────────────────────────────────────────┘
                                            ▼
                                  M07 802.15.4 telanjang
                                     │              │
                     ┌───────────────┘              └───────────────┐
                     ▼                                              ▼
        M08 ─► M09 ─► M10  (Zigbee)                     M11 ─► M12  (Thread/IPv6)
                     │                                              │
                     └──────────────┐              ┌────────────────┘
                                    ▼              ▼
                              M13 gateway ─► M14 MQTT ─► M15 pipeline end-to-end
                                                                │
                                                                ▼
                                                    M16 benchmark komparatif
```.text, rapat: true)

*Kedua, kontrak data yang konsisten.* Beberapa keputusan sengaja dipertahankan
lintas modul supaya datanya dapat dibandingkan pada M16, seperti tercantum pada
@tbl:p-kontrak-data.

#tbl(
  table(
    columns: (2fr, auto, 1.2fr),
    align: (left, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Kontrak], th[Diperkenalkan], th[Dipakai lagi di]),
    [Service UUID `4fafc201-…`], [M01], [M02--M06, M16],
    [Payload bernomor urut (`SEQ=`, `#n`) untuk menghitung loss], [M02 (CH-1)], [M04, M07, M09, M12, M13--M16],
    [Pemisahan kanal *data* dan kanal *perintah*], [M03], [M08 (cluster), M14 (topic)],
    [Penanda identitas sumber pada payload/alamat], [M05 (`A:`/`B:`)], [M09 (short addr), M12 (`NODE_ID`), M15],
    [_Transparent forwarding_ --- payload tidak diubah saat di-hop], [M06], [M13, M15, M16],
    [Radio 802.15.4 channel 15 sebagai basis bersama], [M07], [M08--M13],
    [Grup multicast `ff03::abcd` : 5050], [M11], [M12, M13, M15],
    [Topic MQTT `praktikum/h2/telemetri`], [M14], [M15, M16],
    [Variabel kontrol benchmark (payload, interval, gateway, broker)], [M15], [M16],
  ),
  [Kontrak data yang dipertahankan lintas modul],
  "tbl:p-kontrak-data",
)

Konsekuensinya, *angka pengukuran modul awal dipakai lagi di modul akhir.*
Transaksi per menit M03 dibandingkan dengan M04; latency relay M06 dengan
routing M10 dan mesh M12; latency per hop M11 dan M14 dijumlahkan lalu dicek
terhadap latency end-to-end M15. Mahasiswa yang membuang data modul lama akan
kesulitan pada M16 --- dan hal itu memang disengaja.

== Capaian Pembelajaran

Setelah menyelesaikan seluruh modul, praktikan mampu:

+ menjelaskan karakteristik protokol BLE, 802.15.4, Zigbee, Thread, dan MQTT;
+ membangun komunikasi P2P, client-server, multi-node, dan mesh antar board;
+ melakukan pengukuran RSSI, latency, dan packet loss secara ilmiah;
+ menganalisis data pengujian untuk menilai kecocokan protokol terhadap kasus;
+ membangun sistem IoT end-to-end dari sensor node hingga broker MQTT.

*Kompetensi pendukung*

- Menggunakan PlatformIO/Arduino core 3.x untuk ESP32-H2/C6.
- Membaca Serial Monitor sebagai instrumen pengukuran, bukan sekadar log.
- Merancang eksperimen jarak--RSSI--packet loss dan mencatatnya secara
  sistematis.
- Bekerja berpasangan atau berkelompok dengan pembagian peran perangkat.

== Arsitektur Sistem Lab

#diagram(```
            ┌─────────────────────────────────────────────┐
            │                INTERNET / MQTT              │
            └──────────────────────▲──────────────────────┘
                                   │ Wi-Fi
            ┌──────────────────────┴──────────────────────┐
            │              ESP32-C6 Gateway               │
            └──────────────────────▲──────────────────────┘
                                   │ Thread (IPv6)
   BLE / Zigbee / 802.15.4         │
┌─────────┐ ┌─────────┐ ┌─────────┴───┐ ┌─────────┐ ┌─────────┐
│ ESP32-H2│ │ ESP32-H2│ │  ESP32-H2   │ │ ESP32-H2│ │ ESP32-H2│
│  node   │ │  node   │ │    node     │ │  node   │ │  node   │
└─────────┘ └─────────┘ └─────────────┘ └─────────┘ └─────────┘
```.text)

#tbl(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Blok], th[Modul], th[Cakupan]),
    [BLE], [01--06], [P2P, pertukaran data, GATT client-server, telemetry, multi-node, mesh/relay],
    [802.15.4], [07], [Raw frame di atas radio telanjang],
    [Zigbee], [08--10], [P2P, multi-node, mesh routing],
    [Thread], [11--12], [P2P IPv6, mesh IPv6],
    [Integrasi], [13--15], [Gateway Thread ke Wi-Fi, MQTT, pipeline end-to-end],
    [Proyek], [16], [Benchmark komparatif BLE/Zigbee/Thread],
  ),
  [Pembagian blok protokol sepanjang satu semester],
  "tbl:p-blok-protokol",
)

== Daftar Modul

#tbl(
  table(
    columns: (auto, auto, 1.3fr, 1fr, auto, auto),
    align: (center + horizon, left, left, left, left, left),
    inset: (x: 0.5em, y: 0.42em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Folder], th[Misi], th[Link komunikasi], th[Board], th[Level]),
    [00A], [`week00_blinky`], [Verify the Toolchain], [--- (single node)], [ESP32-H2], [Basic],
    [00B], [`week00_btn`], [Read the First Input], [--- (single node)], [ESP32-H2], [Basic],
    [01], [`week01_ble_p2p`], [Establish a BLE Link], [koneksi H2 ke H2], [ESP32-H2], [Basic],
    [02], [`week02_ble_p2p_data`], [Exchange Data], [dua arah (notify + write)], [ESP32-H2], [Basic],
    [03], [`week03_ble_client_server`], [Build a BLE Service], [GATT read/write], [ESP32-H2], [Intermediate],
    [04], [`week04_ble_telemetry`], [Stream Telemetry], [server ke client (notify)], [ESP32-H2], [Intermediate],
    [05], [`week05_ble_multinode`], [Connect Multiple Devices], [1 pusat ke beberapa node], [ESP32-H2], [Intermediate],
    [05B], [`week05b_ble_multinode_project`], [Build a Smart Sensor System], [2 sensor bukaan ke 1 hub], [ESP32-H2], [Intermediate],
    [05C], [`week05c_ble_pager`], [Notify One Device, Not All], [1 controller ke N pager], [ESP32-H2], [Intermediate],
    [06], [`week06_ble_mesh`], [Build a BLE Mesh], [relay H2--H2--H2], [ESP32-H2], [Intermediate],
    [07], [`week07_802154_p2p`], [Speak Raw 802.15.4], [raw frame H2 ke H2], [ESP32-H2], [Intermediate],
    [08], [`week08_zigbee_p2p`], [Join a Zigbee Network], [Coordinator ke End Device], [ESP32-H2], [Advanced],
    [09], [`week09_zigbee_multinode`], [Scale the Network], [Coordinator ke beberapa ED], [ESP32-H2], [Intermediate],
    [10], [`week10_zigbee_mesh`], [Route Through the Mesh], [Coordinator ke Router ke ED], [ESP32-H2], [Advanced],
    [11], [`week11_thread_p2p`], [Speak IPv6 over Thread], [UDP IPv6 H2 ke H2], [ESP32-H2], [Intermediate],
    [12], [`week12_thread_mesh`], [Mesh the Internet], [IPv6 mesh multi-node], [ESP32-H2], [Advanced],
    [13], [`week13_thread_wifi_gateway`], [Bridge Thread to Wi-Fi], [H2 ke C6 ke Wi-Fi], [H2 + C6], [Advanced],
    [14], [`week14_mqtt`], [Publish to the Cloud], [C6 ke MQTT broker], [ESP32-C6], [Intermediate],
    [15], [`week15_e2e_iot`], [Build an End-to-End IoT System], [H2 → Thread → C6 → MQTT], [H2 + C6], [Advanced],
    [16], [`week16_comparative`], [Prove Your Protocol], [BLE/Zigbee/Thread → MQTT], [H2 + C6], [Project],
  ),
  [Daftar modul praktikum beserta folder kode sumbernya],
  "tbl:p-daftar-modul",
)

#catatan[
  *Modul 00A dan 00B adalah warm-up* yang dikerjakan sebelum M01. Keduanya
  tidak memuat protokol komunikasi; fungsinya memastikan toolchain, board, dan
  rantai build--flash--monitor sudah terbukti bekerja, sehingga kegagalan pada
  modul komunikasi tidak lagi bercampur dengan masalah dasar.
]

#catatan[
  *Modul 05B adalah mini project*, bukan modul inti --- 16 modul utama tetap
  01--16. Isinya menerapkan topologi bintang M05 pada kasus nyata: dua smart
  sensor bukaan (jendela dan pintu, tombol BOOT sebagai proximity switch
  simulasi) melapor ke satu hub. Di sinilah trafik berubah dari periodik
  menjadi _event-driven_.
]

#catatan[
  *Modul 05C adalah mini project* yang melanjutkan M05 dari arah sebaliknya:
  pusat mengirim perintah ke *satu* node terpilih (sistem pager restoran).
  Titik ajarnya adalah bahwa pengiriman terarah pada BLE bukan broadcast,
  melainkan penulisan ke satu objek koneksi tertentu.
]

Rantai sistem end-to-end pada Modul 15 adalah sebagai berikut.

#diagram(```
H2 → Thread → C6 → Wi-Fi → MQTT → Dashboard
```.text)

#penting[
  *Modul 16 bukan sekadar demo.* Praktikan harus membuktikan dengan data,
  protokol mana yang paling sesuai untuk skenario IoT tertentu.
]

== Status Verifikasi Perangkat Keras

Modul 02--16 sudah dikompilasi *dan* dijalankan pada perangkat nyata (2 buah
ESP32-H2 DevKitM-1 dan 1 buah ESP32-C6 DevKitC-1, dengan capture Serial Monitor
otomatis per modul). Log referensi hasil uji terdapat pada bagian "Verifikasi
hardware" di masing-masing modul.

#tbl(
  table(
    columns: (auto, auto, 1.1fr, auto, 1.3fr),
    align: (center + horizon, center + horizon, left, left, left),
    inset: (x: 0.5em, y: 0.42em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Build], th[Uji perangkat], th[Board dipakai], th[Catatan]),
    [02], [lulus], [lulus --- 0 % loss dua arah], [2 × ESP32-H2], [---],
    [03], [lulus], [lulus --- read/write 100 %], [2 × ESP32-H2], [---],
    [04], [lulus], [lulus --- 24/24 notify], [2 × ESP32-H2], [---],
    [05], [lulus], [lulus --- 2 koneksi simultan], [3 × ESP32-H2], [laju A 30/mnt, B 20/mnt],
    [05B], [lulus], [lulus --- 8/8 kejadian + reconnect], [3 × ESP32-H2], [pulih 4,6 s (cepat) atau 28,3 s (via scan ulang); kedip LED belum diverifikasi],
    [05C], [lulus], [lulus --- panggilan terarah + ACK], [4 × ESP32-H2], [0 baris bocor ke pager lain; *batas 2 koneksi serentak* ditemukan di sini; buzzer belum diuji akustik],
    [06], [lulus], [lulus --- relay A ke B ke C, 9/9], [3 × ESP32-H2], [---],
    [07], [lulus], [lulus --- 12/12 PING--PONG], [2 × ESP32-H2], [perlu tiga perbaikan kode],
    [08], [lulus], [lulus --- 13/13 perintah], [2 × ESP32-H2], [erase NVS sebelum flash],
    [09], [lulus], [lulus --- 2 light, 14/14], [3 × ESP32-H2], [`short addr 0xFFFF` itu normal],
    [10], [lulus], [lulus --- 15/15 ke ZR dan ZED], [3 × ESP32-H2], [multi-hop perlu formasi garis],
    [11], [lulus], [lulus --- 12/12 PING--PONG], [2 × ESP32-H2], [perlu prefix mesh-local tetap],
    [12], [lulus], [lulus --- 3 node saling terima], [3 × ESP32-H2], [perlu prefix mesh-local tetap],
    [13], [lulus], [lulus --- rantai penuh], [H2 + *C6*], [POST sampai server; balasan HTTP kadang timeout (`-11`)],
    [14], [lulus], [lulus --- publish + perintah], [*C6*], [8/8 publish, 3/3 perintah; broker lokal],
    [15], [lulus], [sebagian --- rantai jalan, hop Wi-Fi rapuh], [H2 + *C6*], [end-to-end 0--36 % tergantung AP (koeksistensi)],
    [16], [lulus], [lulus --- BLE ke MQTT], [H2 + *C6*], [47/48 notify, 47/47 publish tiba; end-to-end 98 %],
  ),
  [Status verifikasi tiap modul pada perangkat nyata],
  "tbl:p-status-verifikasi",
)

#catatan[
  Pada berkas sumber, kolom Build dan Uji perangkat ditandai dengan lambang
  centang dan lambang peringatan. Di buku ini lambang tersebut ditulis sebagai
  kata "lulus" dan "sebagian" agar tetap terbaca ketika dokumen dicetak
  hitam-putih. Isi penilaiannya tidak diubah.
]

Perbaikan kode yang lahir dari pengujian ini dirangkum pada
@tbl:p-perbaikan-h2.

#tbl(
  table(
    columns: (auto, 1.2fr, 1.4fr),
    align: (center + horizon, left, left),
    inset: (x: 0.5em, y: 0.42em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Masalah di perangkat nyata], th[Perbaikan]),
    [05C], [Controller reboot saat koneksi BLE ketiga (`npl_freertos_callout_init`)],
    [Controller ESP32-H2 hanya mencadangkan memori untuk dua koneksi dan tidak dapat dinaikkan lewat build flag; koneksi dibuka saat memanggil lalu dilepas setelah ACK],
    [07], [Node2 tidak pernah menerima frame], [`esp_ieee802154_receive()` dipanggil di `setup()`],
    [07], [Payload sesekali berisi sampah RAM], [buffer TX dijadikan `static` (transmit bersifat asinkron)],
    [07], [Panjang frame salah], [byte `Len` kini menghitung 2 byte FCS],
    [11, 12, 13, 15], [Node attach tetapi tidak ada paket multicast yang tiba],
    [prefix mesh-local dipaksa sama (`otThreadSetMeshLocalPrefix()`), dataset selalu di-commit ulang],
  ),
  [Perbaikan kode hasil pengujian pada ESP32-H2],
  "tbl:p-perbaikan-h2",
)

== Koeksistensi Wi-Fi dan 802.15.4 pada ESP32-C6

Menjalankan Thread dan Wi-Fi bersamaan pada satu chip (Modul 13 dan 15)
membutuhkan tiga hal yang tidak ada pada kode awal: *urutan inisialisasi*
(Wi-Fi disambungkan di antara `OThread.begin()` dan `OThread.start()`),
*prioritas radio* (`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`), dan *timer
retry MQTT yang terpisah* dari timer retry Wi-Fi. Tanpa ketiganya, C6
mendapatkan IP yang benar tetapi seluruh TCP keluar gagal.

Setelah diperbaiki, rantai penuh Modul 13 dan 15 terbukti berjalan --- tetapi
hop Wi-Fi tetap tidak andal. Hasil pengujian pada tiga access point diberikan
pada @tbl:p-ap-uji.

#tbl(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center + horizon, center + horizon, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[AP uji], th[Kanal Wi-Fi], th[RSSI], th[M15 end-to-end]),
    [AP-1], [1], [−82 dBm], [0 %],
    [AP-2], [12], [−81 dBm], [36 %],
    [AP-3], [9], [−71 dBm], [5 %],
  ),
  [Keberhasilan rantai end-to-end Modul 15 pada tiga access point],
  "tbl:p-ap-uji",
)

Sinyal terkuat justru bukan yang terbaik, dan mengganti channel 802.15.4 (15 ke
25 ke 11) tidak menolong --- jadi persoalannya bukan link budget melainkan
pembagian airtime satu antena. Pembanding yang menentukan, pada access point
dan jarak yang sama, diberikan pada @tbl:p-pipeline.

#tbl(
  table(
    columns: (1.2fr, auto, auto, auto, auto),
    align: (left, center + horizon, center + horizon, center + horizon, center + horizon),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Pipeline], th[Modul], th[Hop sensor], th[Hop Wi-Fi/MQTT], th[End-to-end]),
    [BLE → C6 → MQTT], [16], [47/48 (98 %)], [47/47 (100 %)], [*98 %*],
    [Thread → C6 → MQTT], [15], [30/39 (77 %)], [2/7 (29 %)], [*5 %*],
  ),
  [Perbandingan dua pipeline end-to-end pada kondisi uji yang sama],
  "tbl:p-pipeline",
)

Kombinasi BLE dan Wi-Fi nyaris tanpa ongkos koeksistensi, sedangkan Thread dan
Wi-Fi sangat mahal. Angka ini menjadi bahan utama analisis Modul 16.

#penting[
  *Catatan metodologi yang lahir dari sini:* `mqtt.publish()` yang
  mengembalikan `true` bukan bukti pesan sampai, karena QoS 0 hanya menulis ke
  buffer socket. Semua tabel "broker menerima" pada lab ini wajib diisi dari
  log broker atau subscriber.
]

Perbaikan kode tambahan dari uji ESP32-C6 dirangkum pada @tbl:p-perbaikan-c6.

#tbl(
  table(
    columns: (auto, 1.2fr, 1.3fr),
    align: (center + horizon, left, left),
    inset: (x: 0.5em, y: 0.42em),
    stroke: 0.5pt + luma(170),
    table.header(th[Modul], th[Masalah di perangkat nyata], th[Perbaikan]),
    [13, 15], [C6 panic: `Failed to create OpentThread event loop`, lalu `assert failed: otTaskletsSignalPending`],
    [`OThread.begin()` dipanggil sebelum Wi-Fi],
    [13, 15], [Wi-Fi tidak pernah asosiasi bila `OThread.start()` sudah berjalan],
    [Wi-Fi disambungkan di antara `OThread.begin()` dan `OThread.start()`],
    [13--16], [`while (WiFi.status() != WL_CONNECTED)` menggantung selamanya],
    [dibatasi `WIFI_TIMEOUT_MS`, lalu lanjut dan dicoba ulang berkala],
    [14], [`reconnectMQTT()` memblokir `loop()` tanpa batas],
    [dibatasi `MQTT_TIMEOUT_MS`, keluar bila Wi-Fi belum siap],
    [15, 16], [`mqtt.connect()` dipanggil tiap iterasi `loop()` sehingga banjir `DNS Failed` menenggelamkan log],
    [`maintainNetwork()` dengan jeda dan pemeriksaan Wi-Fi lebih dulu],
    [13, 15, 16], [`WiFi.disconnect()` tiap retry membatalkan asosiasi yang sedang berjalan],
    [hanya `WiFi.begin()` ulang, dengan jeda lebih panjang],
    [13, 15], [Seluruh TCP keluar gagal saat stack Thread aktif],
    [`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)` sebelum `OThread.start()`],
    [13], [Balasan HTTP timeout padahal data sudah sampai server],
    [`http.setConnectTimeout(8000)` dan `setTimeout(8000)`],
    [15, 16], [Retry MQTT ikut terkunci jeda retry Wi-Fi (20 s) padahal Wi-Fi sehat],
    [timer `WIFI_RETRY_MS` dan `MQTT_RETRY_MS` dipisah],
    [15], [Baris `Publish MQTT [...]` dicetak walau broker tidak terhubung --- laporan palsu],
    [publish hanya bila `mqtt.connected()`, kegagalan dicetak apa adanya],
  ),
  [Perbaikan kode hasil pengujian pada ESP32-C6],
  "tbl:p-perbaikan-c6",
)

Perkakas pendukung pada folder `tools/` lahir karena jaringan uji memblokir
port 1883 dan port 80 keluar.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Berkas], th[Guna]),
    [`tools/mqtt_broker.py`], [Broker MQTT 3.1.1 lokal, Python murni tanpa install atau sudo; sekaligus pengganti `mosquitto_sub -v`],
    [`tools/http_sink.py`], [Server penerima POST lokal, pengganti `httpbin.org` untuk Modul 13],
  ),
  [Perkakas pendukung pada folder `tools/`],
  "tbl:p-tools",
)

== Perangkat Keras

#tbl(
  table(
    columns: (auto, 1fr, auto, 1fr),
    align: (center + horizon, left, center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[No], th[Peralatan], th[Jumlah], th[Keterangan]),
    [1], [ESP32-H2 DevKitM-1], [≥ 3], [node sensor / BLE / Zigbee / Thread],
    [2], [ESP32-C6 DevKitC-1], [≥ 1], [gateway Wi-Fi / MQTT],
    [3], [Kabel USB data], [sesuai board], [flash dan serial monitor],
    [4], [PC/Laptop], [1 per kelompok], [terinstal PlatformIO],
    [5], [Akses Wi-Fi/hotspot], [1], [modul 13--16],
    [6], [Broker MQTT (tes/lokal)], [1], [modul 14--16],
  ),
  [Perangkat keras yang diperlukan sepanjang satu semester],
  "tbl:p-perangkat-keras",
)

== Perangkat Lunak

- PlatformIO dengan platform *pioarduino* `espressif32` 55.03.311 (Arduino core
  *3.3.11*, ESP-IDF 5.5.5). Platform resmi `platformio/espressif32` *tidak
  menyediakan board ESP32-H2*, sehingga tiap `platformio.ini` memakai URL rilis
  pioarduino secara eksplisit. Toolchain terunduh otomatis pada build pertama.
- Modul 13, 15, dan 16 memakai `board_build.partitions = huge_app.csv` pada
  gateway ESP32-C6 --- firmware Thread/BLE + Wi-Fi + MQTT/HTTP melebihi partisi
  app default 1,25 MB.
- Zigbee dan OpenThread *bawaan* Arduino core 3.x; mode Zigbee diatur lewat
  `build_flags` (`-DZIGBEE_MODE_ED`, `-DZIGBEE_MODE_ZCZR`).
- Modul 07 dan 11--13 memakai API ESP-IDF (`esp_ieee802154.h`, `OThread`) yang
  dapat dipanggil langsung dari Arduino core 3.x.
- Serial Monitor 115200 baud.
- Library: NimBLE-Arduino (BLE) dan PubSubClient (MQTT).
- Perkakas lokal pada `tools/` bila jaringan memblokir broker atau HTTP publik
  --- lihat `tools/README.md`.

*Deploy per modul*

#keluaran("# contoh: upload dua role pada Module 02
pio run -d week02_ble_p2p_data -e node1 -t upload
pio run -d week02_ble_p2p_data -e node2 -t upload")

== Kode Sumber dan Repositori

Buku ini dirancang agar dapat dipakai berdiri sendiri: *seluruh berkas sumber
setiap modul dimuat lengkap di dalamnya*, bukan sekadar potongan. Setiap
`platformio.ini`, tiap `main.cpp` per peran, tabel partisi Zigbee, maupun skrip
bantu Python tercetak utuh pada bagian Kode Program bab yang bersangkutan.
Listing-listing itu dibaca langsung dari salinan berkas aslinya saat buku
dibangun, sehingga isinya dijamin identik dengan yang dijalankan di perangkat
--- tidak ada transkripsi manual yang bisa menyimpang.

Meski begitu, mengetik ulang kode dari halaman cetak bukan cara yang
dianjurkan. Salinan daring seluruh kode tersedia pada repositori praktikum, dan
setiap bab memuat kotak *KODE SUMBER* berisi tautan ke folder modul beserta
tiap berkasnya.

#tbl(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Keterangan], th[Alamat]),
    [Repositori], [#link(REPO)[#raw(REPO)]],
    [Kode per modul], [#gh-folder("week01_ble_p2p") dan seterusnya],
    [Perkakas pendukung], [#gh-folder("tools")],
    [Skematik board], [#gh-folder("skematik")],
  ),
  [Alamat repositori kode sumber praktikum],
  "tbl:p-repositori",
)

*Mengunduh seluruh kode*

#keluaran("git clone https://github.com/hendrieepis/WSN-IOT-prak.git
cd WSN-IOT-prak
pio run -d week00_blinky -e node -t upload     # uji rantai kerja lebih dulu")

Praktikan yang tidak memakai Git dapat mengunduh arsip ZIP repositori lewat
tombol _Code_ pada halaman GitHub, lalu mengekstraknya ke folder kerja.

#catatan[
  Bila isi repositori berbeda dengan listing di buku ini, repositori yang
  berlaku --- kode di sana diperbarui mengikuti hasil pengujian perangkat
  terbaru. Cantumkan _commit_ yang dipakai pada bagian konfigurasi laporan agar
  hasil pengukuran dapat ditelusuri kembali.
]

== Aturan Laboratorium dan Keselamatan

+ Kabel USB dicabut atau diamankan saat memindah posisi board (eksperimen
  jarak).
+ Antena board tidak ditempelkan ke permukaan logam saat pengukuran.
+ Gunakan daya dari PC atau laptop; hindari power bank bila tidak perlu.
+ Data pengukuran wajib hasil eksperimen sendiri, bukan salinan kelompok lain.
+ Laporan dan analisis ditulis dengan bahasa sendiri; menyalin teori atau kode
  tanpa pemahaman dinilai nol pada bagian analisis.

== Sistem Penilaian

#tbl(
  table(
    columns: (1.4fr, auto, 1fr),
    align: (left, center + horizon, left),
    inset: (x: 0.6em, y: 0.45em),
    stroke: 0.5pt + luma(170),
    table.header(th[Komponen], th[Bobot], th[Sumber penilaian]),
    [Persiapan dan eksekusi percobaan (semua CHECKPOINT terlewati)], [25 %], [bagian Alat yang Digunakan dan Percobaan],
    [Data pengukuran], [20 %], [bagian Pengukuran],
    [Analisis berbasis data], [20 %], [bagian Analisis],
    [Challenge (modifikasi kode)], [15 %], [bagian Challenge],
    [Concept check], [10 %], [bagian Concept Check],
    [Laporan akhir dan kesimpulan], [10 %], [bagian Laporan],
  ),
  [Bobot penilaian praktikum],
  "tbl:p-penilaian",
)

Catatan penilaian:

- *Capaian pembelajaran adalah rubriknya.* Tiap capaian ditulis agar dapat
  dinilai lulus atau tidak dari bukti yang dilampirkan, bukan dari kesan.
- *Angka tanpa asal-usul dianggap tidak ada.* Setiap sel tabel pengukuran harus
  dapat ditunjuk log atau kondisi ukurnya --- hal inilah yang diuji
  habis-habisan pada Modul 16.
- *Challenge dinilai dari kode yang berubah*, bukan dari penjelasan tentang
  kode yang tidak diubah.

#catatan[
  Setiap modul berada pada folder `weekNN_nama` berisi `platformio.ini`, kode
  sumber per peran (role), dan `README.md`. Buku ini adalah hasil konversi
  berkas `README.md` tersebut, dengan seluruh kode sumber tiap modul dimuat
  lengkap di bagian Kode Program masing-masing bab. Log serial mentah hasil uji
  perangkat tetap berada pada repositori praktikum.
]

#v(1em)

#align(right)[
  September 2026

  *Akhmad Hendriawan*
]
]
