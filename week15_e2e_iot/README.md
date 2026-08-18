```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 15 — Pipeline IoT End-to-End

 H2 + C6 · THREAD → MQTT · END-TO-END · Level: Advanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 15 |
| Misi | Merangkai seluruh vertikal — sensor sampai dashboard — dan menunjukkan di hop mana pesan hilang bila hilang |
| Platform | ESP32-H2 (sensor Thread) + ESP32-C6 (gateway Thread + Wi-Fi/MQTT) |
| Durasi | 3 × 50 menit |
| Mode | End-to-end (4 hop) |
| Level | Advanced |
| Instrumen | 2 × Serial Monitor 115200 + `mosquitto_sub` di PC |

```
H2 → Thread → C6 → Wi-Fi → MQTT → Dashboard
```

## 2 · Keterkaitan Antar-Modul

Modul ini **tidak memperkenalkan protokol baru**. Seluruh komponennya sudah dibangun: sensor Thread (M11), mesh (M12), gateway dwi-radio (M13), dan klien MQTT (M14). Yang baru adalah menyatukannya — dan menghadapi masalah yang hanya muncul saat sistem punya banyak hop: **ketika data tidak sampai, hop mana yang salah?** Karena tiap hop sudah diukur sendiri pada modul sebelumnya, angka pembanding untuk menjawabnya sudah tersedia.

| | Cakupan |
|---|---|
| Prasyarat | M11–12 (Thread + dataset), M13 (gateway dwi-radio), M14 (MQTT + `mosquitto_sub`) |
| Dibangun di modul ini | Integrasi tiga stack pada satu gateway, latency & loss per hop pada rantai 4 hop, isolasi kesalahan, verifikasi dari sisi luar |
| Dipakai lagi di | M16 (pipeline ini jadi kerangka baku; hanya protokol hop pertama yang diganti-ganti agar perbandingannya adil) |

**Peta modul blok integrasi (penutup blok)**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 13 | Gateway: Thread bertemu Wi-Fi, keluar lewat HTTP |
| 14 | Sisi IP diperdalam: publish/subscribe MQTT |
| **15 (ini)** | **Semuanya disatukan: rantai lengkap sensor → dashboard** |
| 16 | Hop pertama diganti BLE/Zigbee/Thread untuk dibandingkan |

**Kontrak data lab ini.** Payload `suhu:XX.X` berjalan **tanpa diubah** dari node H2 sampai subscriber di PC — gateway tidak mem-parsing ulang, hanya memindahkan dari satu transport ke transport lain. Karena itu topic `praktikum/h2/telemetri` di sini identik dengan M14, dan datanya bisa langsung dibandingkan dengan M16.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Merangkai pipeline lengkap sensor Thread → gateway dwi-radio → broker MQTT → subscriber, dan menunjukkan jejak satu pesan yang sama di keempat titik.
2. Mengonfigurasi ESP32-C6 menjalankan Thread Leader, Wi-Fi STA, dan klien MQTT bersamaan, serta menjelaskan urutan inisialisasinya.
3. Mengukur latency end-to-end pada tiga skenario jarak dan memecahnya menjadi kontribusi tiap hop memakai data M11–M14.
4. Mengidentifikasi hop penyebab packet loss dengan membandingkan counter di tiap tahap, bukan dengan menebak.

**Kriteria keberhasilan**

- ☐ Pesan `suhu:XX.X` dari H2 muncul di subscriber MQTT tiap ± 3 detik.
- ☐ Latency end-to-end terukur pada tiga skenario jarak.
- ☐ Hop penyebab loss teridentifikasi dengan membandingkan counter tiap tahap.
- ☐ Satu pesan yang sama dapat ditunjukkan jejaknya di H2, C6, dan `mosquitto_sub`.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (arsitektur referensi IoT, edge vs cloud processing, skema QoS berlapis) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Pipeline end-to-end | Rantai lengkap sensor → WSN → gateway → backbone IP → broker → konsumen data. |
| Gateway dwi-radio | C6 menjalankan stack Thread dan Wi-Fi bersamaan, menerjemahkan UDP multicast Thread menjadi publish MQTT. |
| Hop | Satu perpindahan antar tahap; rantai ini punya 4 hop yang bisa gagal secara terpisah. |
| Transparent forwarding | String `suhu:XX.X` diteruskan tanpa diubah sepanjang rantai. |
| Topic | Data masuk ke `praktikum/h2/telemetri`; konsumen cukup berlangganan tanpa tahu sensornya. |
| QoS | Jaminan pengiriman MQTT (0/1/2); kode ini memakai QoS 0 (batasan PubSubClient). |

**Isolasi kesalahan adalah inti modul ini.** Empat hop berarti empat tempat pesan bisa hilang. Cara membedakannya: hitung **counter di tiap tahap** — berapa yang dikirim H2, berapa yang tercetak `RX via Thread` di C6, berapa yang tercetak `Publish MQTT`, dan berapa yang muncul di `mosquitto_sub`. Selisih antar tahap menunjuk hop yang bermasalah. Tanpa counter, semua kegagalan terlihat sama: "datanya tidak muncul".

**Sekuens protokol yang diamati**

```
[H2] readSensor ──► "suhu:25.3" ──► OtUdp multicast
[C6] OtUdp.parsePacket ──► "RX via Thread" ──► mqtt.publish(TOPIC_TELEM)
                                          ──► "Publish MQTT [...]"
[PC] mosquitto_sub -t praktikum/h2/telemetri ──► praktikum/h2/telemetri suhu:25.3
```

## 5 · Topologi

```
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
```

Rantai vertikal per lapis:

```
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
```

| Node | Board | Environment | Peran |
|---|---|---|---|
| Sensor | **ESP32-H2** DevKitM-1 | `h2_node` | Sensor Thread, TX `suhu:XX.X` tiap 3 s |
| Gateway | **ESP32-C6** DevKitC-1 | `c6_gateway` | Thread Leader + Wi-Fi STA + klien MQTT (`esp32c6-gateway`) |
| Konsumen | PC/laptop | — | `mosquitto_sub`, verifikasi independen |

Sama seperti M13, **dua jenis board wajib**: ESP32-H2 tidak punya Wi-Fi, jadi hanya ESP32-C6 yang bisa memegang Thread dan Wi-Fi sekaligus.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 — node sensor Thread | 1 |
| 2 | Board ESP32-C6 | DevKitC-1 — gateway Thread → MQTT | 1 |
| 3 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 4 | PC/Laptop | PlatformIO Core/IDE + `mosquitto-clients` | 1 |
| 5 | Wi-Fi / hotspot | **2,4 GHz**, ada akses internet | 1 |
| 6 | Broker MQTT | `test.mosquitto.org:1883` atau Mosquitto lokal | 1 |
| 7 | Library PubSubClient | `knolleary/PubSubClient@^2.8` via `lib_deps` | — |

**Konfigurasi jaringan**

| Parameter | Nilai |
|---|---|
| Thread network | `ESP_OT_E2E`, channel 15, PAN `0xABCD` |
| Mesh-local prefix | `fdde:ad00:beef::/64` (identik di H2 dan C6) |
| Grup multicast / port | `ff03::abcd` : 5050 |
| Topic MQTT | `praktikum/h2/telemetri` |
| Client ID gateway | `esp32c6-gateway` |
| Interval telemetri | 3000 ms |

**Pre-flight checklist**

- ☐ ESP32-H2 dan ESP32-C6 terhubung ke PC via kabel USB, port dicatat.
- ☐ `WIFI_SSID`, `WIFI_PASS` pada `src/c6_gateway/main.cpp` sudah disesuaikan (hotspot **2,4 GHz**).
- ☐ Broker MQTT dapat dijangkau dari PC (tes dengan `mosquitto_sub`).
- ☐ Firmware `h2_node` dan `c6_gateway` berhasil di-build.
- ☐ Env gateway memakai `board_build.partitions = huge_app.csv` (firmware > 1,25 MB).
- ☐ Dua Serial Monitor (115200) dibuka, satu untuk tiap board.
- ☐ Prefix mesh-local kedua firmware sama: `fdde:ad00:beef::/64`.
- ☐ Data latency dan loss dari M11 (Thread) dan M14 (MQTT) sudah di tangan sebagai pembanding per hop.

**Deploy**

```bash
# terminal 1 — subscriber, jalankan lebih dulu
mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v

# terminal 2 & 3 — gateway dulu, baru node sensor
pio run -d week15_e2e_iot -e c6_gateway -t upload -t monitor
pio run -d week15_e2e_iot -e h2_node    -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Inisialisasi Gateway

Deploy firmware kedua board. Gateway melakukan tiga tahap setup: konek Wi-Fi, konek MQTT (client ID `esp32c6-gateway`), lalu membentuk jaringan Thread `ESP_OT_E2E` sebagai Leader dan join grup multicast. Ukur waktu total setup.

```
[C6 setup] WiFi.begin ──► mqtt.connect ──► OThread dataset ──► leader
           ──► beginMulticast(ff03::abcd, 5050)
```

**Data capture**

| Parameter | Hasil |
|---|---|
| SSID & IP Wi-Fi gateway | |
| Broker & port | |
| Nama jaringan Thread | |
| Role C6 setelah attach | |
| Awalan Mesh-Local EID H2 dan C6 sama? | |
| Waktu total setup hingga `Gateway siap` | |

**Buka abstraksinya** — gateway ini menjalankan **tiga** stack di satu chip: Thread, Wi-Fi, dan MQTT. Bandingkan ukuran firmware `c6_gateway` modul ini dengan `c6_gateway` M13 (Thread + Wi-Fi + HTTP) dari ringkasan `pio run`, lalu periksa `huge_app.csv` untuk melihat berapa besar partisi app yang tersedia. Jawab: berapa persen partisi sudah terpakai, dan apa yang akan terjadi bila ditambahkan satu stack lagi (mis. BLE seperti di M16)? Ini metrik yang jarang diukur orang tetapi menentukan apakah sebuah gateway bisa dikembangkan lagi.

> **CHECKPOINT** — Gateway mencetak **ketiga** tanda kesiapan berurutan: `Wi-Fi OK, IP: ...`, `MQTT terhubung`, dan `Thread attached as: leader`. Jika salah satu tidak muncul, hentikan di sini — mendiagnosis satu stack jauh lebih mudah daripada mendiagnosis tiga sekaligus.

### EXP-02 — Thread TX → Forward MQTT

H2 mengirim `suhu:XX.X` tiap 3 detik; C6 menerima paket dan langsung mem-publish payload yang sama ke broker.

```
[H2] ──3 s──► "TX via Thread: suhu:25.3"
[C6] ──► "RX via Thread: suhu:25.3" ──► "Publish MQTT [praktikum/h2/telemetri]: suhu:25.3"
```

**Expected output — H2**

```
Sensor H2 (Thread node) starting...
Menunggu join ke gateway (C6)...
Attached as: child
TX via Thread: suhu:25.2
```

**Expected output — C6**

```
Konek Wi-Fi NAMA_WIFI....
Wi-Fi OK, IP: 192.168.x.x
MQTT terhubung
Menunggu attach Thread...
Thread attached as: leader
Gateway siap (H2 -> Thread -> C6 -> MQTT).
RX via Thread: suhu:25.2
Publish MQTT [praktikum/h2/telemetri]: suhu:25.2
```

> **CHECKPOINT** — Untuk **satu** nilai suhu yang sama (mis. `25.2`), tiga baris log berurutan harus dapat ditunjuk: `TX via Thread` di H2, `RX via Thread` di C6, dan `Publish MQTT` di C6. Jika baris kedua ada tetapi ketiga tidak, masalahnya di MQTT — bukan di Thread.

### EXP-03 — Verifikasi End-to-End

Jalankan subscriber di PC:

```bash
mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v
```

Verifikasi bahwa tiap ± 3 detik muncul:

```
praktikum/h2/telemetri suhu:25.2
```

Variasi wajib:

1. Jauhkan H2 dari C6 (1 m / 5 m / di balik dinding) dan hitung pesan yang sampai ke subscriber.
2. Matikan hotspot sesaat untuk melihat reconnect MQTT (kode melakukan `mqtt.connect` ulang di `loop`). Catat berapa pesan Thread yang datang selama itu dan apa nasibnya.
3. Reset H2 saat sistem berjalan; ukur berapa lama sampai data muncul lagi di subscriber.

**Data capture**

| Parameter | Hasil |
|---|---|
| Interval pesan di subscriber (s) | |
| Jumlah pesan / 2 menit | |
| RSSI Wi-Fi gateway | |
| Perilaku saat MQTT terputus | |
| Waktu pulih setelah H2 di-reset | |

> **CHECKPOINT** — Nilai suhu yang muncul di `mosquitto_sub` sama persis dengan yang dicetak H2. Jika berbeda atau tertukar urutannya, ada pihak lain yang mem-publish ke topic yang sama — ganti prefix topic menjadi unik per kelompok.

### Verifikasi hardware (log referensi)

Dijalankan pada **ESP32-H2 DevKitM-1** + **ESP32-C6 DevKitC-1** asli.

```
# H2 (env h2_node)                # C6 (env c6_gateway)
[1.002] Attached as: Router       [2.003] Wi-Fi OK, IP: 192.168.110.197 | RSSI: -84 dBm
[3.406] TX via Thread: suhu:24.7  [3.004] Thread attached as: Router
[6.412] TX via Thread: suhu:24.5  [3.004] Default netif dikembalikan ke Wi-Fi STA (err=0)
                                  [18.025] RX via Thread: suhu:23.4
                                  [18.025] Publish MQTT GAGAL (mqtt=-2) ...
```

| Bagian rantai | Status |
|---|---|
| Build `h2_node` + `c6_gateway` (`huge_app.csv`) | ✅ sukses |
| C6 attach ke Thread `ESP_OT_E2E` | ✅ 3,0 s sejak boot |
| Hop Thread H2 → C6 (`RX via Thread`) | ✅ seluruh paket, 0 % loss |
| C6 asosiasi Wi-Fi sambil Thread jalan | ✅ 2,0 s (setelah perbaikan urutan) |
| Publish MQTT → broker | ⚠️ berjalan tetapi tidak andal (0–36 % end-to-end, tergantung AP) |

**Rantai penuh terbukti — dengan satu syarat wajib.** Pipeline H2 → Thread → C6 → Wi-Fi → MQTT → subscriber berhasil dijalankan utuh, **tetapi hanya setelah prioritas radio diberikan ke Wi-Fi** sebelum stack 802.15.4 dinyalakan:

```cpp
#include "esp_coexist.h"
...
esp_coex_preference_set(ESP_COEX_PREFER_WIFI);   // sebelum OThread.start()
```

Tanpa baris itu, C6 tetap asosiasi Wi-Fi dan dapat IP, tetapi **seluruh TCP keluar gagal** — bahkan ke router sendiri (probe timeout 4 detik berulang).

**Diuji pada tiga jaringan Wi-Fi berbeda.** Hop Thread selalu sehat; hop Wi-Fi/MQTT yang bervariasi dan selalu menjadi penyumbang kerugian:

| AP uji | Kanal Wi-Fi | RSSI | H2 TX → C6 RX | Publish → broker | End-to-end |
|---|---|---|---|---|---|
| AP-1 | 1 (2412 MHz) | −82 dBm | ✅ | ⛔ 0 | 0 % |
| AP-2 | 12 (2467 MHz) | −81 dBm | 32/33 (97 %) | 12/12 | **36 %** |
| AP-3 | 9 (2452 MHz) | −71 dBm | 30/39 (77 %) | 2/7 | **5 %** |

Sinyal yang lebih kuat (AP-3) **tidak** menghasilkan hasil terbaik — jadi penyebabnya bukan link budget, melainkan pembagian airtime antara Wi-Fi dan 802.15.4 pada satu antena. Mengganti channel 802.15.4 (15 → 25, dan 15 → 11 untuk menjauh maksimum dari kanal Wi-Fi AP-3) juga tidak menolong.

**Pelajaran penting dari AP-3: `publish()` bernilai `true` bukan bukti sampai.** Pada run itu gateway mencetak 7 baris `Publish MQTT [...]` sementara broker hanya menerima **2**. Pada QoS 0, `PubSubClient::publish()` hanya menulis ke buffer socket; bila koneksi TCP sudah setengah mati, tidak ada yang memberi tahu. Karena itu Bagian 8 mewajibkan kolom "Broker menerima" diisi dari **log broker**, bukan dari log gateway. Ini juga jawaban konkret untuk Concept Check nomor 3.

**Pembanding yang paling menentukan.** Modul 16 (BLE + Wi-Fi, bukan Thread + Wi-Fi) diukur pada AP-3, jarak, dan broker yang sama persis:

| Pipeline | Modul | Hop sensor | Hop Wi-Fi/MQTT | End-to-end |
|---|---|---|---|---|
| BLE → C6 → MQTT | M16 | 47/48 (98 %) | 47/47 (100 %) | **98 %** |
| Thread → C6 → MQTT | M15 | 30/39 (77 %) | 2/7 (29 %) | **5 %** |

Kondisi jaringan identik; yang berbeda hanya radio hop pertama. Ini bahan utama untuk analisis Modul 16: pada gateway satu-chip satu-antena, **BLE + Wi-Fi nyaris tanpa ongkos koeksistensi, Thread + Wi-Fi sangat mahal**. Kesimpulan yang tepat bukan "Thread lebih buruk dari BLE", melainkan bahwa arsitektur gateway satu-chip tidak cocok untuk Thread + Wi-Fi — border router dua-chip akan mengubah angka ini sepenuhnya.

**Yang sudah dicoba dan tidak menyelesaikan:** mengganti channel 802.15.4 (15 → 25), memakai AP di kanal Wi-Fi yang tidak bertetangga, `WiFi.setSleep()` kedua nilainya, dan memaksa default netif ke Wi-Fi STA. Yang **berhasil** hanya kombinasi urutan inisialisasi + `esp_coex_preference_set(ESP_COEX_PREFER_WIFI)`
+ memisahkan jeda retry MQTT dari jeda retry Wi-Fi. Bahkan setelah itu, hop Wi-Fi tetap tidak andal — laporkan angkanya apa adanya.

**Yang harus dilakukan praktikan:** catat RSSI Wi-Fi gateway di laporan dan isi tabel counter per tahap di Bagian 8. Rantai yang bocor di satu hop dengan sebab yang dapat ditunjuk bernilai lebih tinggi daripada demo mulus tanpa data.

**Perbaikan kode yang lahir dari uji ini**

| Masalah di perangkat nyata | Perbaikan |
|---|---|
| C6 **panic** saat boot (`Failed to create OpentThread event loop` → `assert failed: otTaskletsSignalPending`) | `OThread.begin()` dipanggil **sebelum** Wi-Fi; wrapper OpenThread tidak mentoleransi event loop default yang sudah dibuat Wi-Fi |
| Wi-Fi tidak pernah asosiasi bila `OThread.start()` sudah jalan | Wi-Fi disambungkan **di antara** `OThread.begin()` dan `OThread.start()` — asosiasi selesai sebelum radio 802.15.4 aktif |
| `while (WiFi.status() != WL_CONNECTED)` dan loop MQTT menggantung selamanya | dibatasi `WIFI_TIMEOUT_MS` / `MQTT_TIMEOUT_MS`, lalu lanjut dan dicoba ulang berkala |
| `mqtt.connect()` dipanggil tiap iterasi `loop()` → banjir `DNS Failed` menenggelamkan log | `maintainNetwork()` dengan jeda `WIFI_RETRY_MS` dan cek Wi-Fi lebih dulu |
| `WiFi.disconnect()` di tiap percobaan ulang membatalkan asosiasi yang sedang berjalan | hanya `WiFi.begin()` ulang, dengan jeda lebih panjang dari durasi asosiasi |
| `Publish MQTT [...]` dicetak walau broker tidak terhubung — **laporan palsu** | publish hanya bila `mqtt.connected()`, kegagalan dicetak apa adanya beserta `mqtt.state()` |
| Seluruh TCP keluar gagal saat stack Thread aktif, padahal Wi-Fi sudah dapat IP | `esp_coex_preference_set(ESP_COEX_PREFER_WIFI)` dipanggil sebelum `OThread.start()` |
| Percobaan MQTT ikut terkunci jeda retry Wi-Fi (20 s) padahal Wi-Fi sudah sehat | timer retry Wi-Fi dan MQTT dipisah (`WIFI_RETRY_MS` vs `MQTT_RETRY_MS`) |

## 8 · Pengukuran

| Skenario / Jarak H2–C6 | RSSI Wi-Fi (C6) | Latency end-to-end (TX H2 → subscriber, ms) | Success / 40 pesan |
|---|---|---|---|
| 1 m, garis pandang | | | |
| 5 m, garis pandang | | | |
| 5 m + penghalang dinding | | | |

Latency end-to-end: cap waktu `TX via Thread` pada H2 versus kemunculan pesan di `mosquitto_sub` (gunakan `mosquitto_sub -F '%t %p'` atau timestamp terminal).

**Tabel counter per tahap — inti modul ini.** Amati 2 menit (≈ 40 pesan):

| Tahap | Baris log yang dihitung | Jumlah | Loss vs tahap sebelumnya |
|---|---|---|---|
| 1. H2 mengirim | `TX via Thread` | | — |
| 2. C6 menerima | `RX via Thread` | | |
| 3. C6 mem-publish | `Publish MQTT` | | |
| 4. Subscriber menerima | baris di `mosquitto_sub` | | |

**Dekomposisi latency — wajib.** Isi dari data modul sebelumnya:

| Hop | Modul sumber angka | Latency |
|---|---|---|
| H2 → C6 (Thread) | M11 | |
| C6 → broker (MQTT) | M14 | |
| Jumlah keduanya | — | |
| Latency end-to-end terukur (M15) | modul ini | |
| Selisih (overhead integrasi) | — | |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Apa peran gateway C6 dalam pipeline ini, dan protokol apa saja yang ia jalankan bersamaan?
2. Berapa latency tambahan karena hop Thread→MQTT dibanding pengiriman Thread satu hop (M11/M13)? Gunakan tabel dekomposisi latency.
3. Apakah payload berubah di sepanjang rantai? Jelaskan desain transparent forwarding ini dan apa untungnya untuk M16.
4. Bagian mana dari rantai yang paling banyak kehilangan pesan? Tunjukkan dari tabel counter per tahap — bukan dari dugaan.
5. Bandingkan arsitektur end-to-end ini dengan node sensor Wi-Fi-MQTT langsung (M14) dari sisi konsumsi daya, jangkauan, dan jumlah node yang bisa dilayani.

## 10 · Concept Check

1. Gambarkan kembali arsitektur H2 → Thread → C6 → MQTT dan jelaskan fungsi tiap elemen.
2. Mengapa gateway melakukan publish dengan payload asli, bukan mem-parsing ulang datanya?
3. Apa yang terjadi pada data Thread yang sedang dikirim saat koneksi MQTT gateway terputus?
4. Bagaimana cara memonitor topic ini dari dashboard (mis. MQTT Explorer) dan apa yang perlu disiapkan?
5. Keuntungan apa yang diperoleh dengan memisahkan jaringan sensor (Thread) dan backbone (Wi-Fi/MQTT), dibanding satu jaringan Wi-Fi untuk semuanya?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Dua sensor.** Tambahkan node Thread H2 kedua dengan payload ber-ID (`suhu:25.3,node2`) sehingga sumber data dapat dibedakan di subscriber. Diskusikan alternatifnya: memberi ID di payload vs memberi topic sendiri per node.

- **CH-2 — QoS sungguhan.** PubSubClient hanya mendukung publish QoS 0. Ganti library gateway ke yang mendukung QoS 1 (mis. `arduino-mqtt`), ukur apakah success rate meningkat, dan bandingkan overhead-nya (ukuran firmware, latency).

- **CH-3 — Loss per hop (wajib).** Hitung packet loss end-to-end dengan sequence number (`suhu:25.3,#42`). Contoh: H2 mengirim 100, subscriber menerima 94 → loss = 6 %. Identifikasi hop penyebab dengan membandingkan counter `RX via Thread` dan `Publish MQTT` di C6.

- **CH-4 — Dashboard sungguhan.** Sambungkan topic ini ke MQTT Explorer, Node-RED, atau Grafana, dan tampilkan grafik suhu terhadap waktu. Lampirkan tangkapan layarnya di laporan.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (pipeline IoT, gateway dwi-radio, transparent forwarding, isolasi kesalahan per hop)
3. Konfigurasi — dataset Thread `ESP_OT_E2E`, SSID, broker, topic, client ID, PubSubClient
4. Hasil eksperimen — log H2, C6, dan `mosquitto_sub`, termasuk jejak satu pesan yang sama di tiga titik
5. Data pengukuran — tabel jarak, **tabel counter per tahap**, dan tabel dekomposisi latency
6. Analisis + concept check
7. Challenge — minimal CH-3
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
