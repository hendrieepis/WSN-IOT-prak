```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
     MODUL 16 — Proyek: Benchmark Protokol IoT

 H2 + C6 · BLE / ZIGBEE / THREAD → MQTT · Level: Project
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 16 |
| Misi | Membuktikan dengan data — bukan dengan demo — protokol mana yang paling sesuai untuk sebuah skenario IoT |
| Platform | ESP32-H2 (sensor) + ESP32-C6 (gateway BLE/Wi-Fi/MQTT) |
| Durasi | 3 × 50 menit |
| Mode | Proyek komparatif |
| Level | Project |
| Instrumen | 2 × Serial Monitor 115200 + `mosquitto_sub` + data Modul 05–15 |

> **Yang dinilai bukan "sistem menyala".** Yang dinilai adalah apakah kamu bisa
> membuktikan, dengan angka hasil pengukuranmu sendiri, protokol mana yang
> paling sesuai untuk sebuah kasus — dan mempertahankan rekomendasi itu saat
> ditanya balik.

## 2 · Keterkaitan Antar-Modul

Ini adalah modul **panen**. Lima belas modul sebelumnya menghasilkan angka; di
sini angka-angka itu dikumpulkan menjadi satu tabel pembanding. Modul ini
membangun pipeline **BLE → gateway C6 → MQTT** sebagai pasangan yang setara
dengan pipeline Thread di M15 — dengan payload, interval, gateway, dan broker
yang **sama persis**, sehingga hanya protokol hop pertama yang menjadi variabel.

| | Cakupan |
|---|---|
| Prasyarat | M04–06 (BLE telemetry & mesh), M08–10 (Zigbee), M11–13 (Thread), M14–15 (MQTT & pipeline) — **beserta seluruh data pengukurannya** |
| Dibangun di modul ini | Pipeline BLE→MQTT sebagai pembanding pipeline Thread M15, metodologi perbandingan yang adil (variabel kontrol), rekomendasi berbasis data |
| Menutup | Seluruh seri: dari satu tautan radio (M01) sampai keputusan arsitektur berbasis bukti |

**Peta seluruh seri — dari mana angkamu berasal**

| Blok | Modul | Angka yang dipanen di sini |
|---|---|---|
| BLE | 01–06 | RSSI vs jarak, loss, latency notify, batas multi-node, latency relay |
| 802.15.4 | 07 | jangkauan radio telanjang (baseline) |
| Zigbee | 08–10 | waktu join/binding, latency 1 hop vs 2 hop, loss per node |
| Thread | 11–12 | latency PING/PONG, loss mesh, waktu self-healing |
| Integrasi | 13–15 | latency & loss per hop, latency end-to-end pipeline Thread |
| **Proyek** | **16 (ini)** | **latency & loss end-to-end pipeline BLE — pasangan pembanding M15** |

**Kontrak data lab ini — inilah yang membuat perbandingan sah.**

| Variabel | Status | Nilai |
|---|---|---|
| Payload | **dikontrol** | `suhu:XX.X` |
| Interval kirim | **dikontrol** | 2000 ms |
| Gateway | **dikontrol** | ESP32-C6 |
| Broker & topic | **dikontrol** | `test.mosquitto.org:1883`, `praktikum/h2/telemetri` |
| Jarak & penghalang | **dikontrol** | 1 m / 5 m / 5 m + dinding |
| **Protokol hop pertama** | **variabel bebas** | BLE (modul ini) vs Thread (M15) vs Zigbee (M08–10) |

Angka yang diukur pada kondisi berbeda **tidak boleh** dimasukkan ke tabel
pembanding. Kalau data M15 diambil pada interval 3 detik sementara modul ini
2 detik, ulangi salah satunya — atau nyatakan perbedaan itu secara eksplisit
sebagai keterbatasan.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membangun pipeline BLE → gateway C6 → MQTT dengan variabel kontrol yang identik dengan pipeline Thread M15.
2. Mengukur RSSI, latency end-to-end, packet loss, dan throughput untuk pipeline BLE, dan menempatkannya dalam satu tabel bersama data Thread dan Zigbee dari modul sebelumnya.
3. Menunjukkan asal setiap angka dalam tabel perbandingan (modul, tanggal, kondisi pengukuran) sehingga hasilnya dapat diaudit.
4. Merumuskan rekomendasi protokol untuk minimal tiga kasus nyata, dengan justifikasi yang menunjuk baris tertentu pada tabel — dan menyebutkan keterbatasan datanya.

**Kriteria keberhasilan**

- ☐ Tabel perbandingan protokol terisi metrik terukur (RSSI, latency, packet loss, throughput).
- ☐ Setiap angka dapat ditunjukkan asal pengukurannya (modul + kondisi).
- ☐ Rekomendasi protokol dapat dipertanggungjawabkan dengan data, bukan opini.
- ☐ Keterbatasan metodologi dinyatakan secara eksplisit.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(model konsumsi daya, analisis kapasitas kanal, metodologi benchmark jaringan)
ada di buku teori terpisah.*

| Protokol / Istilah | Karakteristik kerja |
|---|---|
| BLE | Jaringan bintang, koneksi GATT, notify untuk push — daya sangat rendah, jangkauan pendek, tanpa mesh pada mode ini. |
| Zigbee | Mesh 802.15.4 dengan ZC/ZR/ZED — jangkauan luas via multi-hop, perintah baku antar-vendor. |
| Thread | Mesh 802.15.4 berbasis IPv6 — self-healing, role dipilih otomatis, langsung nyambung ke dunia IP. |
| MQTT pub/sub | Muara bersama semua protokol; QoS 0 pada lab ini. |
| Variabel kontrol | Faktor yang sengaja disamakan agar perbandingan adil. |
| Variabel bebas | Faktor yang sengaja diubah — di sini: protokol hop pertama. |
| Metrik | RSSI, latency end-to-end, packet loss, throughput (pesan/menit). |

**Empat metrik, empat pertanyaan berbeda.** Jangan campur:

| Metrik | Menjawab pertanyaan |
|---|---|
| RSSI | Seberapa kuat sinyalnya di titik ini? |
| Latency | Berapa lama data sampai? |
| Packet loss | Berapa banyak yang tidak sampai sama sekali? |
| Throughput | Berapa banyak yang bisa lewat per satuan waktu? |

Protokol bisa unggul di satu metrik dan kalah di lainnya — itu justru inti
pekerjaan modul ini. Rekomendasi yang baik menyebut **metrik mana** yang
menentukan untuk kasus yang dibahas.

**Sekuens protokol yang diamati**

```
[H2 sensor] NimBLE server ──► characteristic NOTIFY
[C6] scan "CMP_SENSOR" ──► connect ──► subscribe
[C6] onTelemetry() ──► mqtt.publish("praktikum/h2/telemetri", "suhu:25.3")
[Broker] ──► [Subscriber di PC]
```

## 5 · Topologi

```
   BOARD #1 (H2)               BOARD #2 (C6)                    INTERNET
+---------------+  BLE GATT  +--------------------+  Wi-Fi   +--------------------+
|   ESP32-H2    | ─────────► |     ESP32-C6       | ───────► |   Broker MQTT      |
|  DevKitM-1    |  notify    |    DevKitC-1       |  MQTT    | test.mosquitto.org |
|  CMP_SENSOR   | "suhu:XX.X"| CMP_GATEWAY        |  publish |       :1883        |
|  env: sensor  |  / 2 s     | BLE client + Wi-Fi |          +---------+----------+
+---------------+            | env: gateway       |                    │
 radio: BLE                  +--------------------+          +---------v----------+
                              radio: BLE + Wi-Fi             |  PC: mosquitto_sub |
                                                             +--------------------+
```

| Node | Board | Environment | Peran |
|---|---|---|---|
| Sensor | **ESP32-H2** DevKitM-1 | `sensor` | BLE server `CMP_SENSOR`, notify tiap 2 s |
| Gateway | **ESP32-C6** DevKitC-1 | `gateway` | BLE client `CMP_GATEWAY` + Wi-Fi/MQTT publisher |
| Konsumen | PC/laptop | — | `mosquitto_sub`, verifikasi independen |

Perhatikan: **gateway-nya sama** dengan M15 (ESP32-C6), **broker dan topic-nya
sama**, yang berbeda hanya hop pertama — BLE di sini, Thread di M15. Itulah
sebabnya kedua hasil bisa diletakkan berdampingan.

UUID penting: service `4fafc201-1fb5-459e-8fcc-c5c9c331914b`, characteristic
telemetri `beb5483e-36e1-4688-b7f5-ea07361b26b2` — sama dengan characteristic
telemetri Modul 04, jadi sensor M04 bisa dipakai ulang di sini bila perlu.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 — sensor BLE `CMP_SENSOR` | 1 |
| 2 | Board ESP32-C6 | DevKitC-1 — gateway `CMP_GATEWAY` | 1 |
| 3 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 4 | PC/Laptop | PlatformIO Core/IDE + `mosquitto-clients` | 1 |
| 5 | Wi-Fi / hotspot | **2,4 GHz**, ada akses internet | 1 |
| 6 | Broker MQTT | `test.mosquitto.org:1883` atau lokal | 1 |
| 7 | **Data Modul 05–15** | tabel pengukuran BLE, Zigbee, Thread, pipeline M15 | wajib |
| 8 | Meteran / penanda jarak | agar posisi 1 m / 5 m benar-benar sama dengan pengukuran modul lain | 1 |

**Pre-flight checklist**

- ☐ ESP32-H2 dan ESP32-C6 terhubung ke PC via kabel USB, port dicatat.
- ☐ `WIFI_SSID` dan `WIFI_PASS` pada `src/gateway/main.cpp` sudah disesuaikan (hotspot **2,4 GHz**).
- ☐ Env `gateway` memakai `board_build.partitions = huge_app.csv` (firmware BLE + Wi-Fi + MQTT > 1,25 MB).
- ☐ Broker dapat dijangkau (`mosquitto_sub -h test.mosquitto.org -t "praktikum/#" -v`).
- ☐ Firmware `sensor` dan `gateway` berhasil di-build.
- ☐ Dua Serial Monitor (115200) dibuka, satu untuk tiap board.
- ☐ **Data Thread M15 tersedia** sebagai pembanding, beserta catatan kondisi pengukurannya.
- ☐ Posisi uji (1 m / 5 m / 5 m + dinding) ditandai fisik agar bisa diulang identik.

**Deploy**

```bash
mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v   # terminal 1
pio run -d week16_comparative -e sensor  -t upload -t monitor        # terminal 2
pio run -d week16_comparative -e gateway -t upload -t monitor        # terminal 3
```

## 7 · Percobaan

### EXP-01 — Sensor BLE & Advertising

Deploy firmware `sensor` ke H2. NimBLE membuat server GATT dengan characteristic
NOTIFY lalu mengadvertise nama `CMP_SENSOR`. Gateway belum dinyalakan.

```
[H2] NimBLE init "CMP_SENSOR" ──► createService ──► characteristic NOTIFY
     ──► startAdvertising
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama perangkat BLE | |
| Service / Characteristic UUID | |
| Interval kirim data (s) | |
| Properti characteristic | |
| Status serial saat advertising | |

> **CHECKPOINT** — H2 mencetak `Menunggu gateway...` dan belum mengirim notify
> apa pun. Ini kondisi awal yang benar sebelum gateway dinyalakan.

### EXP-02 — Gateway: Scan, Connect, Subscribe

Deploy firmware `gateway` ke C6. Gateway konek Wi-Fi, inisialisasi BLE sebagai
`CMP_GATEWAY`, active scan 5 detik, berhenti saat menemukan `CMP_SENSOR`, lalu
connect dan subscribe notify.

```
[C6] WiFi.begin ──► NimBLE init ──► scan(5s) ──► "Sensor BLE ditemukan"
     ──► connect ──► subscribe(notify)
[H2] onConnect ──► "Gateway terhubung" ──► notify "suhu:XX.X" tiap 2 s
```

**Expected output — H2**

```
Sensor (BLE telemetry) starting...
Menunggu gateway...
Gateway terhubung
Notify: suhu:25.1
Notify: suhu:25.9
```

**Expected output — C6**

```
Gateway (BLE -> MQTT) starting...
Konek Wi-Fi NAMA_WIFI....
Wi-Fi OK, IP: 192.168.x.x
Scanning sensor BLE...
Sensor BLE ditemukan
BLE: terhubung ke sensor
BLE: koneksi berhasil
RX BLE: suhu:25.1
Publish MQTT [praktikum/h2/telemetri]: suhu:25.1
```

**Buka abstraksinya** — perhatikan bahwa gateway C6 di modul ini menjalankan
**BLE + Wi-Fi**, sedangkan gateway C6 di M15 menjalankan **Thread + Wi-Fi**.
Bandingkan ukuran firmware keduanya dari ringkasan `pio run`. Lalu jawab: mana
yang lebih besar, dan apa artinya untuk perangkat gateway dengan flash terbatas?
Ini adalah metrik kelima yang jarang diukur orang, tetapi nyata biayanya.

> **CHECKPOINT** — Untuk **satu** nilai suhu yang sama, kamu bisa menunjuk tiga
> baris: `Notify:` di H2, `RX BLE:` di C6, dan `Publish MQTT` di C6. Persis
> seperti M15 — struktur pengamatannya sengaja dibuat identik.

### EXP-03 — Verifikasi End-to-End & Variasi

Jalankan `mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v`
dan pastikan tiap ± 2 detik muncul `praktikum/h2/telemetri suhu:25.1`.

Variasi wajib:

1. **Jarak H2–C6**: 1 m / 5 m / di balik dinding — posisi harus sama persis dengan pengukuran M15. Catat apakah koneksi BLE bertahan dan pesan tetap sampai.
2. **Putus koneksi**: reset H2, amati `onDisconnect` → H2 advertise ulang; catat apakah gateway menyambung kembali sendiri atau perlu di-reset.
3. **Ulangi pengukuran pipeline Thread M15** pada kondisi jarak yang sama bila sempat — ini menghilangkan keraguan terbesar pada tabel pembanding.

**Data capture**

| Parameter | Hasil |
|---|---|
| Interval pesan di subscriber (s) | |
| Pesan / 2 menit | |
| RSSI Wi-Fi gateway | |
| RSSI BLE (dari `getRssi()` di C6) | |
| Perilaku saat sensor reset | |

> **CHECKPOINT** — Kamu punya **tiga baris data BLE** (1 m, 5 m, 5 m + dinding)
> dengan kondisi yang bisa kamu buktikan sama dengan data M15. Tanpa itu, tabel
> perbandingan di Bagian 8 tidak sah — dan itulah yang paling sering membuat
> laporan modul ini gugur.

### Verifikasi hardware (log referensi)

Dijalankan pada **ESP32-H2 DevKitM-1** + **ESP32-C6 DevKitC-1** asli, broker
lokal (`tools/mqtt_broker.py`), jarak ±20 cm, capture 60 detik.

```
# H2 (env sensor)              # C6 (env gateway)               # Broker
[..] Gateway terhubung         [2.004] Wi-Fi OK, IP: ...197     CONNECT id=esp32c6-gateway
[..] Notify: suhu:24.7                 | RSSI: -84 dBm          PUBLISH praktikum/h2/telemetri
[..] Notify: suhu:23.9         [2.204] Sensor BLE ditemukan              suhu:23.7
                               [3.606] BLE: koneksi berhasil    PUBLISH praktikum/h2/telemetri
                               [4.608] RX BLE: suhu:24.7                suhu:22.7
                               [20.434] MQTT terhubung
                               [20.434] Publish MQTT [...]: suhu:23.7
```

| Parameter | Hasil terukur |
|---|---|
| Waktu boot → Wi-Fi OK (C6) | 2,0 s (RSSI −84 dBm) |
| Waktu boot → BLE tersambung ke sensor | 3,6 s |
| Notify BLE dikirim H2 / diterima C6 | 28 / 28 (0 % loss) |
| Publish MQTT tiba di broker | 47/47 — diverifikasi dari log broker, bukan dari log gateway |
| BLE + Wi-Fi + MQTT jalan bersamaan di satu C6 | ✅ stabil |

**Pengukuran pembanding langsung BLE vs Thread** — pipeline M16 dan M15 diukur
pada AP, jarak, dan broker yang sama persis, masing-masing 100 detik:

| Pipeline | Modul | Hop sensor | Hop Wi-Fi/MQTT | End-to-end |
|---|---|---|---|---|
| BLE → C6 → MQTT | M16 (ini) | 47/48 (98 %) | 47/47 (100 %) | **98 %** |
| Thread → C6 → MQTT | M15 | 30/39 (77 %) | 2/7 (29 %) | **5 %** |

Pada jaringan lain (AP kanal 12) M15 mencapai 36 % dan M16 82 % — urutannya
tetap sama, selisihnya tetap besar.

Yang membedakan bukan protokol di atas kertas, melainkan **biaya koeksistensi
radio pada satu chip satu antena**: BLE duty-cycled sehingga berbagi antena
dengan Wi-Fi nyaris gratis; 802.15.4 pada peran Router selalu RX sehingga
menekan airtime Wi-Fi sampai TCP tidak lewat.

> Masukkan temuan ini ke analisis nomor 4 dan ke kolom "kondisi ukur" tabel
> perbandingan. Kesimpulan yang tepat bukan "Thread lebih buruk dari BLE",
> melainkan "pada gateway satu-chip, Thread + Wi-Fi berbagi radio jauh lebih
> mahal daripada BLE + Wi-Fi" — gateway dua-chip atau border router khusus
> akan mengubah angka ini sepenuhnya.

> **Jangan percaya `publish()` yang mengembalikan `true`.** Pada run M15 di atas,
> gateway mencetak 7 baris `Publish MQTT [...]` sementara broker hanya menerima
> 2. Pada QoS 0 itu wajar: `publish()` hanya menulis ke buffer socket. Kolom
> "Broker menerima" pada tabelmu **wajib** diisi dari log broker/subscriber.

**Perbaikan kode yang lahir dari uji ini**

| Masalah di perangkat nyata | Perbaikan |
|---|---|
| `mqtt.connect()` dipanggil tiap iterasi `loop()` tanpa jeda → ribuan baris `DNS Failed` membanjiri Serial dan menenggelamkan log BLE | `maintainNetwork()` dengan jeda dan pengecekan status Wi-Fi lebih dulu |
| `while (WiFi.status() != WL_CONNECTED)` menggantung selamanya | dibatasi `WIFI_TIMEOUT_MS`, lalu lanjut; kaki BLE tetap bisa diamati |

## 8 · Pengukuran

**Pengukuran BLE (proyek ini)**

| Skenario / Jarak | RSSI BLE | Latency end-to-end (Notify → subscriber, ms) | Success / 40 |
|---|---|---|---|
| 1 m | | | |
| 5 m | | | |
| 5 m + dinding | | | |

**Tabel perbandingan protokol — deliverable utama modul ini.**
Setiap sel wajib disertai asal datanya:

| Protokol | Sumber data | Kondisi ukur | RSSI (dBm) | Latency (ms) | Packet loss (%) | Throughput (pesan/menit) |
|---|---|---|---|---|---|---|
| BLE → MQTT | M16 (modul ini) | | | | | |
| Thread → MQTT | M15 | | | | | |
| Zigbee (hop sensor) | M08–M10 | | | | | |
| 802.15.4 raw (baseline) | M07 | | | | | |

> Kolom **"Kondisi ukur"** wajib diisi (jarak, interval, ada/tidaknya
> penghalang, tanggal). Sel yang kondisinya berbeda dari baris lain harus
> ditandai dan disebut sebagai keterbatasan di Bagian 9 — bukan disembunyikan.
>
> Zigbee tidak punya pipeline MQTT di lab ini, jadi angkanya adalah **latency
> hop sensor saja**, bukan end-to-end. Menuliskannya sebagai end-to-end adalah
> kesalahan yang akan langsung terlihat saat sidang.

**Metrik pendukung (opsional tapi bernilai)**

| Aspek | BLE (M16) | Thread (M15) |
|---|---|---|
| Ukuran firmware gateway | | |
| Waktu dari boot sampai data pertama sampai | | |
| Pemulihan setelah sensor di-reset | | |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8, dan **tunjuk barisnya**:

1. Berdasarkan data, protokol mana yang paling andal (packet loss terkecil) pada jarak terjauh, dan mengapa?
2. Bagaimana latency end-to-end BLE→MQTT dibandingkan Thread→MQTT untuk payload yang sama? Berapa selisihnya, dan dari hop mana selisih itu berasal?
3. Mengapa BLE connection-based lebih sensitif terhadap jarak/penghalang dibanding mesh Thread? Kaitkan dengan data M06 (relay BLE) dan M12 (mesh Thread).
4. Protokol mana yang paling efisien untuk node baterai dengan interval kirim jarang? Jelaskan dengan data, termasuk konsekuensi peran router (M10).
5. Untuk kasus (a) rumah pintar 15 node, (b) sensor tunggal dekat gateway, (c) gedung bertingkat — protokol apa yang kamu rekomendasikan? Dasarkan tiap jawaban pada baris tabel tertentu.
6. **Apa keterbatasan terbesar dari perbandingan ini?** Sebutkan minimal dua, dan jelaskan apa yang perlu diukur untuk mengatasinya.

## 10 · Concept Check

1. Jelaskan perbedaan topologi BLE (star/connection), Zigbee (mesh), dan Thread (mesh IPv6).
2. Apa itu GATT notify dan mengapa dipakai, bukan indication atau polling read?
3. Bagaimana gateway menemukan dan memilih sensor yang tepat saat scanning (perhatikan `onResult`)?
4. Apa peran MQTT dalam proyek ini, dan mengapa perbandingan protokol dilakukan di hop sensor→gateway, bukan di hop MQTT?
5. Jika throughput naik 10× (interval 200 ms), protokol mana yang paling mungkin bermasalah lebih dulu? Mengapa — dan data modul mana yang mendukung dugaanmu?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Rekomendasi berbasis data (wajib).** Tulis mini-laporan 1 halaman yang memilih protokol untuk **satu** kasus nyata, dengan tabel Bagian 8 sebagai justifikasi. Sertakan satu paragraf "kapan rekomendasi ini salah" — kondisi yang akan membalikkan kesimpulanmu.

- **CH-2 — Dua sensor BLE.** Tambahkan sensor BLE kedua (`CMP_SENSOR2`, UUID berbeda) dan buat gateway mem-forward keduanya ke topic berbeda. Ukur apakah latency berubah saat gateway melayani dua koneksi — bandingkan dengan temuan M05.

- **CH-3 — Packet loss (wajib).** Hitung packet loss dengan sequence number pada payload (`suhu:25.3,#21`). Contoh: 60 notify terkirim, 57 sampai di subscriber → loss = (60−57)/60 × 100 % = 5 %. Pisahkan loss hop BLE dan hop MQTT.

- **CH-4 — Pipeline Zigbee.** Lengkapi baris Zigbee pada tabel perbandingan dengan pipeline yang setara (Zigbee → gateway → MQTT), sehingga ketiga protokol diukur end-to-end pada kondisi yang sama. Ini pekerjaan terbesar — dan yang membuat tabelmu benar-benar utuh.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (BLE/GATT, Zigbee, Thread, MQTT, metodologi perbandingan: variabel kontrol vs bebas)
3. Konfigurasi — UUID, nama perangkat, SSID, broker, topic, NimBLE-Arduino, `huge_app.csv`
4. Hasil eksperimen — log H2, C6, `mosquitto_sub` (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel BLE **dan tabel perbandingan protokol lengkap dengan kolom "kondisi ukur"**
6. Analisis + concept check, termasuk pernyataan keterbatasan
7. Challenge — CH-1 dan CH-3 wajib
8. **Kesimpulan dan rekomendasi protokol** — ditulis sendiri, dengan setiap klaim menunjuk baris data
