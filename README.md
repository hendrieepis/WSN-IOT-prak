```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
                  LAB HANDBOOK


          WIRELESS SENSOR NETWORK
         & INTERNET OF THINGS


   ESP32-H2 + ESP32-C6  •  16 MODUL  •  1 SEMESTER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Protocol stack yang dikerjakan:** BLE · IEEE 802.15.4 · Zigbee · Thread · Wi-Fi/MQTT

## Tentang lab ini

Ini bukan kumpulan tutorial Arduino. Ini buku kerja laboratorium: setiap
minggu adalah satu **misi rekayasa** dengan target sukses terukur, prosedur
eksperimen, dan data yang harus dikumpulkan sendiri.

Fokusnya **protokol komunikasi** — dari Bluetooth Low Energy, IEEE 802.15.4,
Zigbee, Thread, hingga integrasi Wi-Fi/MQTT — di atas board ESP32-H2 dan
ESP32-C6. Kompetensi dibangun bertahap: point-to-point → client-server →
multi-node → mesh, pada tiga keluarga protokol, lalu ditutup dengan integrasi
end-to-end ke Internet dan proyek perbandingan protokol berbasis data.

## Struktur setiap modul

Seluruh 16 modul memakai format yang sama, 12 bagian:

| # | Bagian | Isi |
|---|---|---|
| 1 | **Informasi Modul** | Misi, platform, durasi, mode, level, instrumen |
| 2 | **Keterkaitan Antar-Modul** | Prasyarat, yang dibangun di sini, yang memakainya nanti + peta blok |
| 3 | **Capaian Pembelajaran** | 4–5 capaian **terukur** + kriteria keberhasilan |
| 4 | **Dasar Teori (secukupnya)** | Hanya istilah yang dipakai di percobaan + sekuens protokol |
| 5 | **Topologi** | Diagram jaringan bernama board, peran tiap node, peta alamat |
| 6 | **Persiapan** | Alat & bahan sampai versi/port, `platformio.ini`, pre-flight, perintah deploy |
| 7 | **Percobaan** | EXP-01…03 dengan **CHECKPOINT** di tiap tahap + log referensi hasil uji nyata |
| 8 | **Pengukuran** | Tabel yang diisi sendiri + tabel pembanding lintas modul |
| 9 | **Analisis** | Pertanyaan yang hanya bisa dijawab dari tabel Bagian 8 |
| 10 | **Concept Check** | Pertanyaan konseptual, bukan hafalan |
| 11 | **Challenge** | Tugas **modifikasi kode**, bukan "jelaskan hasilnya" |
| 12 | **Laporan** | Daftar deliverable |

Tiga hal yang membedakan format ini dari panduan praktikum biasa:

- **CHECKPOINT di tengah percobaan.** Mahasiswa memverifikasi progres sebelum
  lanjut, bukan baru ketahuan salah di akhir sesi.
- **"Buka abstraksinya".** Satu kotak per modul yang menyuruh mahasiswa
  membongkar satu baris kode yang tampak sepele (mis. mengomentari `subscribe()`
  lalu melihat notify berhenti) — menghubungkan API dengan apa yang sebenarnya
  terjadi di udara.
- **Teori dibatasi.** Panduan ini menjawab **"bagaimana"**; pembahasan mendalam
  ("mengapa") ada di buku teori terpisah. Tiap Bagian 4 menyebut batas itu
  secara eksplisit.

## Keterkaitan antar-modul

IoT adalah stack berlapis, jadi modulnya bukan pulau-pulau terpisah. Dua
mekanisme dipakai untuk mengikatnya.

**1. Rantai prasyarat.** Tiap modul menyatakan apa yang harus sudah dikuasai,
apa yang ditambahkannya, dan modul mana yang akan memakainya lagi:

```
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
```

**2. Kontrak data yang konsisten.** Beberapa keputusan sengaja dipertahankan
lintas modul supaya datanya bisa dibandingkan di M16:

| Kontrak | Diperkenalkan | Dipakai lagi di |
|---|---|---|
| Service UUID `4fafc201-…` | M01 | M02–M06, M16 |
| Payload bernomor urut (`SEQ=`, `#n`) untuk hitung loss | M02 (CH-1) | M04, M07, M09, M12, M13–M16 |
| Pemisahan kanal **data** vs kanal **perintah** | M03 | M08 (cluster), M14 (topic) |
| Penanda identitas sumber pada payload/alamat | M05 (`A:`/`B:`) | M09 (short addr), M12 (`NODE_ID`), M15 |
| *Transparent forwarding* — payload tak diubah saat di-hop | M06 | M13, M15, M16 |
| Radio 802.15.4 channel 15 sebagai basis bersama | M07 | M08–M13 |
| Grup multicast `ff03::abcd` : 5050 | M11 | M12, M13, M15 |
| Topic MQTT `praktikum/h2/telemetri` | M14 | M15, M16 |
| Variabel kontrol benchmark (payload, interval, gateway, broker) | M15 | M16 |

Konsekuensinya: **angka pengukuran modul awal dipakai lagi di modul akhir.**
Transaksi/menit M03 dibandingkan dengan M04; latency relay M06 dengan routing
M10 dan mesh M12; latency per hop M11 dan M14 dijumlahkan lalu dicek terhadap
latency end-to-end M15. Mahasiswa yang membuang data modul lama akan kesulitan
di M16 — dan itu memang disengaja.

## Capaian pembelajaran

Setelah menyelesaikan seluruh modul, praktikan mampu:

1. menjelaskan karakteristik protokol BLE, 802.15.4, Zigbee, Thread, dan MQTT;
2. membangun komunikasi P2P, client-server, multi-node, dan mesh antar board;
3. melakukan pengukuran RSSI, latency, dan packet loss secara ilmiah;
4. menganalisis data pengujian untuk menilai kecocokan protokol terhadap kasus;
5. membangun sistem IoT end-to-end dari sensor node hingga broker MQTT.

**Kompetensi pendukung**

- Menggunakan PlatformIO/Arduino core 3.x untuk ESP32-H2/C6.
- Membaca Serial Monitor sebagai instrumen pengukuran, bukan sekadar log.
- Merancang eksperimen jarak–RSSI–packet loss dan mencatatnya sistematis.
- Bekerja berpasangan/berkelompok dengan pembagian peran perangkat.

## Arsitektur sistem lab

```
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
```

| Blok | Modul | Cakupan |
|---|---|---|
| BLE | 01–06 | P2P, pertukaran data, GATT client-server, telemetry, multi-node, mesh/relay |
| 802.15.4 | 07 | Raw frame di atas radio telanjang |
| Zigbee | 08–10 | P2P, multi-node, mesh routing |
| Thread | 11–12 | P2P IPv6, mesh IPv6 |
| Integrasi | 13–15 | Gateway Thread→Wi-Fi, MQTT, pipeline end-to-end |
| Proyek | 16 | Benchmark komparatif BLE/Zigbee/Thread |

## Mission roster

| Module | Folder | MISSION | Link komunikasi | Board | Level |
|------|--------|---------|------------|-------|-------|
| 00A | `week00_blinky` | Verify the Toolchain | — (single node) | ESP32-H2 | Basic |
| 00B | `week00_btn` | Read the First Input | — (single node) | ESP32-H2 | Basic |
| 01 | `week01_ble_p2p` | Establish a BLE Link | koneksi H2 ↔ H2 | ESP32-H2 | Basic |
| 02 | `week02_ble_p2p_data` | Exchange Data | dua arah (notify + write) | ESP32-H2 | Basic |
| 03 | `week03_ble_client_server` | Build a BLE Service | GATT read/write | ESP32-H2 | Intermediate |
| 04 | `week04_ble_telemetry` | Stream Telemetry | server → client (notify) | ESP32-H2 | Intermediate |
| 05 | `week05_ble_multinode` | Connect Multiple Devices | 1 pusat ↔ beberapa node | ESP32-H2 | Intermediate |
| 05B | `week05b_ble_multinode_project` | Build a Smart Sensor System | 2 sensor bukaan ↔ 1 hub | ESP32-H2 | Intermediate |
| 06 | `week06_ble_mesh` | Build a BLE Mesh | relay H2 ↔ H2 ↔ H2 | ESP32-H2 | Intermediate |
| 07 | `week07_802154_p2p` | Speak Raw 802.15.4 | raw frame H2 ↔ H2 | ESP32-H2 | Intermediate |
| 08 | `week08_zigbee_p2p` | Join a Zigbee Network | Coordinator ↔ End Device | ESP32-H2 | Advanced |
| 09 | `week09_zigbee_multinode` | Scale the Network | Coordinator ↔ beberapa ED | ESP32-H2 | Intermediate |
| 10 | `week10_zigbee_mesh` | Route Through the Mesh | Coordinator ↔ Router ↔ ED | ESP32-H2 | Advanced |
| 11 | `week11_thread_p2p` | Speak IPv6 over Thread | UDP IPv6 H2 ↔ H2 | ESP32-H2 | Intermediate |
| 12 | `week12_thread_mesh` | Mesh the Internet | IPv6 mesh multi-node | ESP32-H2 | Advanced |
| 13 | `week13_thread_wifi_gateway` | Bridge Thread to Wi-Fi | H2 → C6 → Wi-Fi | H2 + C6 | Advanced |
| 14 | `week14_mqtt` | Publish to the Cloud | C6 → MQTT broker | ESP32-C6 | Intermediate |
| 15 | `week15_e2e_iot` | Build an End-to-End IoT System | H2 → Thread → C6 → MQTT | H2 + C6 | Advanced |
| 16 | `week16_comparative` | Prove Your Protocol | BLE/Zigbee/Thread → MQTT | H2 + C6 | Project |

> **MODUL 00A dan 00B adalah warm-up** yang dikerjakan sebelum M01. Keduanya
> tidak memuat protokol komunikasi; fungsinya memastikan toolchain, board, dan
> rantai build–flash–monitor sudah terbukti bekerja, sehingga kegagalan pada
> modul komunikasi tidak lagi bercampur dengan masalah dasar.

> **MODUL 05B adalah mini project**, bukan modul inti — 16 modul utama tetap
> 01–16. Isinya menerapkan topologi bintang M05 pada kasus nyata: dua smart
> sensor bukaan (jendela dan pintu, tombol BOOT sebagai proximity switch
> simulasi) melapor ke satu hub. Di sinilah trafik berubah dari periodik
> menjadi *event-driven*.

**MODULE 15 — rantai sistem end-to-end:**

```
H2 → Thread → C6 → Wi-Fi → MQTT → Dashboard
```

> **MODULE 16 bukan sekadar demo.** Praktikan harus membuktikan dengan data
> protokol mana yang paling sesuai untuk skenario IoT tertentu.

## Status verifikasi perangkat keras

Modul 02–16 sudah dikompilasi **dan** dijalankan di perangkat nyata
(2 × ESP32-H2 DevKitM-1 + 1 × ESP32-C6 DevKitC-1, capture Serial Monitor
otomatis per modul). Log referensi hasil uji ada di bagian "Verifikasi
hardware" pada README masing-masing modul.

| Modul | Build | Uji perangkat | Board dipakai | Catatan |
|---|---|---|---|---|
| 02 | ✅ | ✅ 0 % loss dua arah | 2 × ESP32-H2 | — |
| 03 | ✅ | ✅ read/write 100 % | 2 × ESP32-H2 | — |
| 04 | ✅ | ✅ 24/24 notify | 2 × ESP32-H2 | — |
| 05 | ✅ | ✅ 2 koneksi simultan | 3 × ESP32-H2 | laju A 30/mnt, B 20/mnt |
| 05B | ✅ | ✅ 8/8 kejadian + reconnect | 3 × ESP32-H2 | pulih 4,6 s (cepat) / 28,3 s (via scan ulang); kedip LED belum diverifikasi |
| 06 | ✅ | ✅ relay A→B→C 9/9 | 3 × ESP32-H2 | — |
| 07 | ✅ | ✅ 12/12 PING–PONG | 2 × ESP32-H2 | perlu 3 perbaikan kode (lihat di bawah) |
| 08 | ✅ | ✅ 13/13 perintah | 2 × ESP32-H2 | erase NVS sebelum flash |
| 09 | ✅ | ✅ 2 light, 14/14 | 3 × ESP32-H2 | `short addr 0xFFFF` itu normal |
| 10 | ✅ | ✅ 15/15 ke ZR + ZED | 3 × ESP32-H2 | multi-hop perlu formasi garis |
| 11 | ✅ | ✅ 12/12 PING–PONG | 2 × ESP32-H2 | perlu prefix mesh-local tetap |
| 12 | ✅ | ✅ 3 node saling terima | 3 × ESP32-H2 | perlu prefix mesh-local tetap |
| 13 | ✅ | ✅ rantai penuh | H2 + **C6** | POST sampai server; balasan HTTP kadang timeout (`-11`) |
| 14 | ✅ | ✅ publish + perintah | **C6** | 8/8 publish, 3/3 perintah; broker lokal |
| 15 | ✅ | ⚠️ rantai jalan, hop Wi-Fi rapuh | H2 + **C6** | end-to-end 0–36 % tergantung AP (koeksistensi) |
| 16 | ✅ | ✅ BLE → MQTT | H2 + **C6** | 47/48 notify, 47/47 publish tiba; end-to-end 98 % |

**Perbaikan kode yang lahir dari pengujian ini**

| Modul | Masalah di perangkat nyata | Perbaikan |
|---|---|---|
| 07 | Node2 tidak pernah menerima frame | `esp_ieee802154_receive()` dipanggil di `setup()` |
| 07 | Payload sesekali berisi sampah RAM | buffer TX dijadikan `static` (transmit bersifat asinkron) |
| 07 | Panjang frame salah | byte `Len` kini menghitung 2 byte FCS |
| 11, 12, 13, 15 | Node attach tetapi tidak ada paket multicast yang tiba | prefix mesh-local dipaksa sama (`otThreadSetMeshLocalPrefix()`), dataset selalu di-commit ulang |

**Koeksistensi Wi-Fi + 802.15.4 pada ESP32-C6 (Modul 13 & 15).** Menjalankan
Thread dan Wi-Fi bersamaan pada satu chip butuh tiga hal yang tidak ada di kode
awal: **urutan inisialisasi** (Wi-Fi disambungkan di antara `OThread.begin()` dan
`OThread.start()`), **prioritas radio**
(`esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`), dan **timer retry MQTT yang
terpisah** dari timer retry Wi-Fi. Tanpa itu semua, C6 mendapat IP yang benar
tetapi seluruh TCP keluar gagal.

Setelah diperbaiki, rantai penuh Modul 13 dan 15 terbukti jalan — tetapi hop
Wi-Fi tetap tidak andal. Diuji pada tiga AP:

| AP uji | Kanal Wi-Fi | RSSI | M15 end-to-end |
|---|---|---|---|
| AP-1 | 1 | −82 dBm | 0 % |
| AP-2 | 12 | −81 dBm | 36 % |
| AP-3 | 9 | −71 dBm | 5 % |

Sinyal terkuat justru bukan yang terbaik, dan mengganti channel 802.15.4
(15 → 25 → 11) tidak menolong — jadi ini bukan soal link budget melainkan
pembagian airtime satu antena. Pembanding yang menentukan, pada AP dan jarak
yang sama:

| Pipeline | Modul | Hop sensor | Hop Wi-Fi/MQTT | End-to-end |
|---|---|---|---|---|
| BLE → C6 → MQTT | 16 | 47/48 (98 %) | 47/47 (100 %) | **98 %** |
| Thread → C6 → MQTT | 15 | 30/39 (77 %) | 2/7 (29 %) | **5 %** |

BLE + Wi-Fi nyaris tanpa ongkos koeksistensi; Thread + Wi-Fi sangat mahal.
Angka ini jadi bahan utama analisis Modul 16.

**Catatan metodologi yang lahir dari sini:** `mqtt.publish()` mengembalikan
`true` bukan bukti pesan sampai (QoS 0 hanya menulis ke buffer socket). Semua
tabel "broker menerima" di lab ini wajib diisi dari log broker/subscriber.

**Perbaikan kode tambahan dari uji ESP32-C6**

| Modul | Masalah di perangkat nyata | Perbaikan |
|---|---|---|
| 13, 15 | C6 panic: `Failed to create OpentThread event loop` → `assert failed: otTaskletsSignalPending` | `OThread.begin()` dipanggil sebelum Wi-Fi |
| 13, 15 | Wi-Fi tidak pernah asosiasi bila `OThread.start()` sudah jalan | Wi-Fi disambungkan di antara `OThread.begin()` dan `OThread.start()` |
| 13–16 | `while (WiFi.status() != WL_CONNECTED)` menggantung selamanya | dibatasi `WIFI_TIMEOUT_MS`, lalu lanjut dan dicoba ulang berkala |
| 14 | `reconnectMQTT()` memblokir `loop()` tanpa batas | dibatasi `MQTT_TIMEOUT_MS`, keluar bila Wi-Fi belum siap |
| 15, 16 | `mqtt.connect()` tiap iterasi `loop()` → banjir `DNS Failed` menenggelamkan log | `maintainNetwork()` dengan jeda dan cek Wi-Fi lebih dulu |
| 13, 15, 16 | `WiFi.disconnect()` tiap retry membatalkan asosiasi yang berjalan | hanya `WiFi.begin()` ulang, jeda lebih panjang |
| 13, 15 | Seluruh TCP keluar gagal saat stack Thread aktif | `esp_coex_preference_set(ESP_COEX_PREFER_WIFI)` sebelum `OThread.start()` |
| 13 | Balasan HTTP timeout padahal data sudah sampai server | `http.setConnectTimeout(8000)` / `setTimeout(8000)` |
| 15, 16 | Retry MQTT ikut terkunci jeda retry Wi-Fi (20 s) padahal Wi-Fi sehat | timer `WIFI_RETRY_MS` dan `MQTT_RETRY_MS` dipisah |
| 15 | `Publish MQTT [...]` dicetak walau broker tidak terhubung — laporan palsu | publish hanya bila `mqtt.connected()`, gagal dicetak apa adanya |

**Perkakas pendukung** (`tools/`) — lahir karena jaringan uji memblokir port
1883 dan 80 keluar:

| Berkas | Guna |
|---|---|
| `tools/mqtt_broker.py` | Broker MQTT 3.1.1 lokal, Python murni tanpa install/sudo; sekaligus pengganti `mosquitto_sub -v` |
| `tools/http_sink.py` | Server penerima POST lokal, pengganti `httpbin.org` untuk Modul 13 |

## Perangkat keras

| No | Peralatan | Jumlah | Keterangan |
|----|-----------|--------|------------|
| 1  | ESP32-H2 DevKitM-1 | ≥ 3 | node sensor / BLE / Zigbee / Thread |
| 2  | ESP32-C6 DevKitC-1 | ≥ 1 | gateway Wi-Fi / MQTT |
| 3  | Kabel USB data | sesuai board | flash + serial monitor |
| 4  | PC/Laptop | 1 per kelompok | terinstal PlatformIO |
| 5  | Akses Wi-Fi/hotspot | 1 | modul 13–16 |
| 6  | Broker MQTT (tes/lokal) | 1 | modul 14–16 |

## Perangkat lunak

- PlatformIO dengan platform **pioarduino** `espressif32` 55.03.311 (Arduino core
  **3.3.11**, ESP-IDF 5.5.5). Platform resmi `platformio/espressif32` **tidak
  menyediakan board ESP32-H2**, sehingga tiap `platformio.ini` memakai URL rilis
  pioarduino secara eksplisit. Toolchain terunduh otomatis pada build pertama.
- Modul 13, 15, dan 16 memakai `board_build.partitions = huge_app.csv` pada
  gateway ESP32-C6 — firmware Thread/BLE + Wi-Fi + MQTT/HTTP melebihi partisi
  app default 1,25 MB.
- Zigbee dan OpenThread **bawaan** Arduino core 3.x; mode Zigbee diset lewat
  `build_flags` (`-DZIGBEE_MODE_ED`, `-DZIGBEE_MODE_ZCZR`).
- Modul 07 dan 11–13 memakai API ESP-IDF (`esp_ieee802154.h`, `OThread`) yang
  dapat dipanggil langsung dari Arduino core 3.x.
- Serial Monitor 115200 baud.
- Library: NimBLE-Arduino (BLE), PubSubClient (MQTT).
- Perkakas lokal di `tools/` bila jaringan memblokir broker/HTTP publik —
  lihat `tools/README.md`.

**Deploy per modul**

```bash
# contoh: upload dua role pada Module 02
pio run -d week02_ble_p2p_data -e node1 -t upload
pio run -d week02_ble_p2p_data -e node2 -t upload
```

## Lab rules & keselamatan

1. Kabel USB dicabut/diamankan saat memindah posisi board (eksperimen jarak).
2. Antena board tidak ditempelkan ke permukaan logam saat pengukuran.
3. Gunakan daya dari PC/laptop; hindari power bank bila tidak perlu.
4. Data pengukuran wajib hasil eksperimen sendiri — bukan salinan kelompok lain.
5. Laporan dan analisis ditulis dengan bahasa sendiri; copy-paste teori/kode
   tanpa pemahaman dinilai nol pada bagian analisis.

## Sistem penilaian

| Komponen | Bobot | Sumber penilaian |
|---|---|---|
| Persiapan & eksekusi percobaan (semua CHECKPOINT terlewati) | 25% | Bagian 6–7 |
| Data pengukuran | 20% | Bagian 8 |
| Analisis berbasis data | 20% | Bagian 9 |
| Challenge (modifikasi kode) | 15% | Bagian 11 |
| Concept check | 10% | Bagian 10 |
| Laporan akhir & kesimpulan | 10% | Bagian 12 |

Catatan penilaian:

- **Capaian pembelajaran (Bagian 3) adalah rubriknya.** Tiap capaian ditulis
  agar bisa dinilai lulus/tidak dari bukti yang dilampirkan, bukan dari kesan.
- **Angka tanpa asal-usul dianggap tidak ada.** Setiap sel tabel pengukuran
  harus bisa ditunjuk log atau kondisi ukurnya — ini yang diuji habis-habisan
  di Modul 16.
- **Challenge dinilai dari kode yang berubah**, bukan dari penjelasan tentang
  kode yang tidak diubah.

> Setiap modul berada di folder `weekNN_nama` berisi `platformio.ini`, kode
> sumber per peran (role), dan `README.md` dengan 12 bagian: Informasi Modul →
> Keterkaitan Antar-Modul → Capaian Pembelajaran → Dasar Teori → Topologi →
> Persiapan → Percobaan → Pengukuran → Analisis → Concept Check → Challenge →
> Laporan.
