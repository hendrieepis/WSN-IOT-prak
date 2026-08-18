```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
        MODUL 14 — MQTT: Publish & Subscribe

  ESP32-C6 · WI-FI / MQTT · PUB-SUB · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 14 |
| Misi | Menempatkan perangkat pada broker dan membuatnya bicara dua arah tanpa tahu alamat lawan bicaranya |
| Platform | ESP32-C6 (Arduino core 3.x) + Wi-Fi + PubSubClient |
| Durasi | 3 × 50 menit |
| Mode | Client–Broker (publish/subscribe) |
| Level | Intermediate |
| Instrumen | Serial Monitor 115200 baud + `mosquitto_sub` / `mosquitto_pub` di PC |

## 2 · Keterkaitan Antar-Modul

M13 mengeluarkan data ke jaringan IP lewat HTTP POST — satu arah, satu tujuan
tetap, satu koneksi per pesan. MQTT membalik modelnya: perangkat menempel pada
**broker**, telemetri naik dan perintah turun lewat koneksi yang sama, dan
tidak ada pihak yang perlu tahu alamat pihak lain. Modul ini sengaja **tanpa
Thread** supaya sisi IP bisa dipelajari terpisah; keduanya baru disatukan di
M15.

| | Cakupan |
|---|---|
| Prasyarat | M13 — Wi-Fi STA di ESP32-C6, konsep gateway, transparent forwarding |
| Dibangun di modul ini | Koneksi broker, topic hierarkis, publish berkala, subscribe + callback, QoS, retained, perilaku reconnect |
| Dipakai lagi di | M15 (HTTP POST M13 diganti publish MQTT ini) → M16 (semua protokol bermuara ke topic yang sama agar perbandingannya adil) |

**Peta modul blok integrasi**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 13 | Gateway: Thread bertemu Wi-Fi, data keluar lewat HTTP |
| **14 (ini)** | **Sisi IP diperdalam: publish/subscribe lewat broker MQTT** |
| 15 | M12 + M13 + M14 digabung: sensor → Thread → C6 → MQTT → dashboard |
| 16 | Protokol sensor diganti-ganti, muara MQTT-nya tetap sama |

**Kontrak data lab ini.** Topic dibagi dua: **`praktikum/h2/telemetri`** untuk
data naik dan **`praktikum/h2/perintah`** untuk perintah turun. Pemisahan ini
adalah kelanjutan langsung dari pola M03 (characteristic data vs characteristic
perintah) dan M08 (cluster On/Off vs laporan status). Topic telemetri yang sama
dipakai lagi di M15 dan M16 — itulah yang membuat data ketiga modul bisa
dibandingkan.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Menghubungkan ESP32-C6 ke Wi-Fi dan broker MQTT dengan client ID tertentu, lalu membuktikan koneksinya dari sisi PC memakai `mosquitto_sub`.
2. Mem-publish telemetri berkala ke topic tertentu dan memverifikasi kedatangannya di subscriber eksternal, minimal 20 pesan berturut-turut.
3. Menerima perintah dari topic lain melalui callback dan menunjukkan aksi nyata yang dipicunya di perangkat.
4. Mengukur latency publish→terima dan menjelaskan perilaku sistem saat Wi-Fi atau broker terputus, berdasarkan log — termasuk nasib subscription setelah reconnect.

**Kriteria keberhasilan**

- ☐ 20 publish berturut-turut tiba di subscriber eksternal.
- ☐ Perintah dari `mosquitto_pub` memicu callback `onMessage()` dan aksi nyata (CH-2).
- ☐ Perilaku reconnect Wi-Fi/MQTT terverifikasi dan tercatat, termasuk return code kegagalan.
- ☐ Tabel latency dan success rate terisi dari pengukuran sendiri.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(paket kontrol MQTT, session state, last will & testament, MQTT 5) ada di buku
teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Broker | Server pusat yang menerima pesan dari publisher dan meneruskannya ke subscriber topic terkait. |
| Publish/Subscribe | Model komunikasi tak langsung — pengirim dan penerima tidak saling tahu alamat, hanya terikat topic. |
| Topic | Label hierarkis pemisah aliran data: `praktikum/h2/telemetri` (data), `praktikum/h2/perintah` (kontrol). |
| Wildcard | `+` cocok satu level, `#` cocok sisa level — dipakai subscriber, bukan publisher. |
| QoS | Tingkat jaminan pengiriman — 0 (at most once), 1 (at least once), 2 (exactly once). |
| Retained | Broker menyimpan pesan terakhir tiap topic dan mengirimkannya ke subscriber baru. |
| Client ID | Identitas unik klien pada broker; dua klien dengan ID sama akan saling menendang. |
| Keep alive & reconnect | Klien menjaga koneksi; kode ini otomatis reconnect Wi-Fi/MQTT bila terputus. |

**Batasan PubSubClient yang wajib diketahui.** Library ini hanya melakukan
**publish QoS 0**. Argumen ketiga `mqtt.publish(topic, payload, true)` adalah
flag *retained*, **bukan** QoS. Artinya: setiap klaim tentang QoS 1/2 pada
laporan harus berasal dari library lain (mis. `arduino-mqtt`,
`AsyncMqttClient`), bukan dari percobaan ini. Menyebut "QoS 1" tanpa mengganti
library adalah kesalahan yang sering muncul di laporan.

**Mengapa modul ini tanpa Thread?** Supaya kegagalan bisa dilokalisasi. Jika
MQTT dan Thread dinyalakan bersamaan sejak awal (seperti M15), pesan yang tidak
sampai bisa berasal dari mana saja. Di sini hanya ada satu hop — sehingga
angka latency dan loss yang diperoleh adalah **milik MQTT saja**, dan dapat
dikurangkan dari angka M15 nanti.

**Sekuens protokol yang diamati**

```
[C6] ──publish──► [Broker] ──push──► [Subscriber / dashboard]
[C6] ◄──push───── [Broker] ◄──publish── [mosquitto_pub di PC]
        callback onMessage()          route by topic
```

## 5 · Topologi

```
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
```

| Elemen | Board / alat | Identitas | Peran |
|---|---|---|---|
| Klien MQTT | **ESP32-C6** DevKitC-1 (env `node`) | client ID `esp32c6-praktikum` | publish telemetri + subscribe perintah |
| Broker | layanan publik | `test.mosquitto.org:1883` | routing berbasis topic |
| Verifikator | PC/laptop | `mosquitto_sub` / `mosquitto_pub` | pembuktian independen dari sisi luar |

**Mengapa ESP32-C6, bukan H2?** ESP32-H2 tidak punya radio Wi-Fi sama sekali,
jadi ia tidak bisa menjadi klien MQTT. Modul ini hanya memakai kaki Wi-Fi C6 —
radio 802.15.4-nya menganggur, dan baru dipakai bersamaan di M15.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-C6 | DevKitC-1 | 1 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 1 |
| 3 | PC/Laptop | PlatformIO Core/IDE + paket `mosquitto-clients` | 1 |
| 4 | Wi-Fi / hotspot | **2,4 GHz**, ada akses internet | 1 |
| 5 | Broker MQTT | `test.mosquitto.org:1883` (publik) atau Mosquitto lokal | 1 |
| 6 | Library PubSubClient | `knolleary/PubSubClient@^2.8` — otomatis via `lib_deps` | — |

**Konfigurasi**

| Parameter | Nilai |
|---|---|
| Client ID | `esp32c6-praktikum` |
| Topic telemetri (publish) | `praktikum/h2/telemetri` |
| Topic perintah (subscribe) | `praktikum/h2/perintah` |
| Interval publish | 5000 ms |
| QoS efektif | 0 (batasan PubSubClient) |

**Pre-flight checklist**

- ☐ ESP32-C6 terhubung ke PC via kabel USB, port dicatat lewat `pio device list`.
- ☐ `WIFI_SSID` dan `WIFI_PASS` pada `src/main.cpp` sudah disesuaikan (hotspot **2,4 GHz**).
- ☐ Hotspot/Wi-Fi aktif dan board memperoleh akses internet.
- ☐ Broker dapat dijangkau dari PC: `mosquitto_sub -h test.mosquitto.org -t "praktikum/#" -v`.
- ☐ Firmware environment `node` berhasil di-build (`pio run -e node`).
- ☐ Serial Monitor 115200 baud dibuka.
- ☐ **Ganti prefix topic** menjadi unik per kelompok bila memakai broker publik (lihat catatan keamanan di Bagian 10).

**Deploy**

```bash
# terminal 1 — subscriber, jalankan lebih dulu
mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v

# terminal 2 — flash & monitor
pio run -d week14_mqtt -e node -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Koneksi Wi-Fi & Broker

Deploy firmware `node` ke ESP32-C6. Node terhubung ke Wi-Fi (`reconnectWiFi`),
lalu melakukan koneksi MQTT dengan client ID `esp32c6-praktikum` dan subscribe
topic perintah.

```
[C6] ──► WiFi.begin ──► IP didapat ──► mqtt.connect("esp32c6-praktikum")
     ──► subscribe TOPIC_CMD
```

**Data capture**

| Parameter | Hasil |
|---|---|
| SSID yang digunakan | |
| IP Wi-Fi C6 | |
| Alamat & port broker | |
| RSSI Wi-Fi (`WiFi.RSSI()`) | |
| Topic yang di-subscribe | |
| Waktu boot → `MQTT terhubung` (s) | |

> **CHECKPOINT** — Serial Monitor mencetak `Wi-Fi OK, IP: ...` **lalu**
> `MQTT terhubung`. Jika berhenti di titik-titik Wi-Fi, periksa apakah hotspot
> 2,4 GHz (C6 tidak mendukung 5 GHz). Jika Wi-Fi OK tetapi MQTT gagal, catat
> `rc=` yang tercetak — angka itu jawaban soal analisis.

### EXP-02 — Publish Berkala

Pada `loop()`, setiap 5 detik node membaca sensor (simulasi suhu 20–40 °C) dan
melakukan `mqtt.publish(TOPIC_TELEM, "XX.X")`. Ukur interval publish aktual
pada log.

```
loop() ──► millis()-last > 5000 ──► readSensor() ──► mqtt.publish
       ──► "TX MQTT [praktikum/h2/telemetri]: 26.4"
```

**Expected output**

```
MQTT Node (C6) starting...
Konek Wi-Fi NAMA_WIFI....
Wi-Fi OK, IP: 192.168.x.x
Konek MQTT test.mosquitto.org:1883 ...
MQTT terhubung
Subscribe: praktikum/h2/perintah
TX MQTT [praktikum/h2/telemetri]: 25.7
TX MQTT [praktikum/h2/telemetri]: 26.3
```

Verifikasi di PC:

```bash
mosquitto_sub -h test.mosquitto.org -t "praktikum/h2/telemetri" -v
```

**Buka abstraksinya** — jalankan subscriber dengan wildcard
`mosquitto_sub -h test.mosquitto.org -t "praktikum/#" -v`. Data kelompok lain — bahkan
data orang asing — mungkin ikut terlihat pada broker publik yang sama. Jelaskan
dari sini: apa yang **tidak** dikerjakan broker, dan mengapa produksi nyata tidak
pernah memakai broker publik tanpa autentikasi.

> **CHECKPOINT** — Baris yang muncul di `mosquitto_sub` **sama persis** dengan
> baris `TX MQTT` di Serial Monitor, termasuk nilainya. Jika Serial mencetak
> tetapi subscriber diam, publish gagal di sisi jaringan — bukan di sisi kode.

### EXP-03 — Perintah Turun & Pemulihan

Injeksi perintah dari PC:

```bash
mosquitto_pub -h test.mosquitto.org -t "praktikum/h2/perintah" -m "LED_ON"
```

Verifikasi callback `onMessage()`:

```
RX MQTT [praktikum/h2/perintah]: LED_ON
```

Variasi wajib:

1. Kirim beberapa perintah berbeda (`LED_ON`, `LED_OFF`, `RESET`) dan amati callback.
2. **Matikan hotspot ± 10 detik** lalu nyalakan lagi; amati `reconnectWiFi`/`reconnectMQTT` dan output `Gagal (rc=...)`.
3. Setelah reconnect, kirim perintah lagi — apakah masih diterima? (Ini menguji apakah subscription bertahan.)

**Data capture**

| Parameter | Hasil |
|---|---|
| Perintah terkirim vs diterima | |
| Delay kirim → `RX MQTT` (ms) | |
| Perilaku saat Wi-Fi terputus | |
| Return code saat gagal connect | |
| Apakah subscription bertahan setelah reconnect? | |

> **CHECKPOINT** — Setelah hotspot dinyalakan lagi, perintah baru **tetap**
> sampai ke perangkat. Jika tidak, subscription hilang saat reconnect — temuan
> penting, dan jawabannya ada di apakah `subscribe()` dipanggil ulang di dalam
> fungsi reconnect.

### Verifikasi hardware (log referensi)

Dijalankan pada **ESP32-C6 DevKitC-1** asli dengan broker lokal
(`tools/mqtt_broker.py`) karena `test.mosquitto.org:1883` diblokir jaringan uji.

```
# ESP32-C6 (env node)                       # Broker (tools/mqtt_broker.py)
[0.200] MQTT Node (C6) starting...          CONNECT   id=esp32c6-praktikum
[2.405] Konek Wi-Fi myrouter....                      from 192.168.110.197
[2.405] Wi-Fi OK, IP: 192.168.110.197       SUBSCRIBE id=esp32c6-praktikum
        | RSSI: -83 dBm                               -> praktikum/h2/perintah
[2.606] MQTT terhubung                      PUBLISH   praktikum/h2/telemetri 25.4
[2.606] Subscribe: praktikum/h2/perintah    PUBLISH   praktikum/h2/telemetri 24.5
[5.210] TX MQTT [praktikum/h2/telemetri]: 25.4
[6.009] RX MQTT [praktikum/h2/perintah]: LED_ON     <- dari mosquitto_pub/paho di PC
[10.215] RX MQTT [praktikum/h2/perintah]: LED_OFF
[13.219] RX MQTT [praktikum/h2/perintah]: RESET
```

| Parameter | Hasil terukur |
|---|---|
| Waktu boot → `Wi-Fi OK` | 2,4 s (RSSI −83 dBm) |
| Waktu boot → `MQTT terhubung` | 2,6 s |
| Publish dikirim / tiba di broker | 8 / 8 (0 % loss) |
| Interval publish terukur | 5,00 s ± 0,01 |
| Perintah dikirim / memicu `onMessage()` | 3 / 3 (`LED_ON`, `LED_OFF`, `RESET`) |
| Subscription bertahan setelah reboot board | ya, re-subscribe 0,2 s setelah connect |

> **`test.mosquitto.org` sering tidak terjangkau dari jaringan kampus** (port
> 1883 keluar diblokir). Gejalanya: `Gagal (rc=-2)` disertai
> `hostByName(): DNS Failed` dan `Host is unreachable`. Solusinya ada di
> `tools/README.md` — jalankan broker lokal dan arahkan `MQTT_BROKER` ke IP
> laptop.

**Perbaikan kode yang lahir dari uji ini**

| Masalah di perangkat nyata | Perbaikan |
|---|---|
| `while (WiFi.status() != WL_CONNECTED)` menggantung selamanya bila SSID/password salah | penantian dibatasi `WIFI_TIMEOUT_MS`, lalu lanjut dan dicoba ulang di `loop()` |
| `reconnectMQTT()` memblokir `loop()` tanpa batas saat broker tak terjangkau — board tampak hang | dibatasi `MQTT_TIMEOUT_MS` dan langsung keluar bila Wi-Fi belum siap |

## 8 · Pengukuran

| Skenario | Publish interval (s) | QoS dipakai | Latency publish→terima (ms) | Success / 20 pesan |
|---|---|---|---|---|
| Dekat AP (1 m) | 5 | 0 (default) | | |
| Jauh AP (5 m) | 5 | 0 | | |
| Jauh AP + dinding | 5 | 0 | | |
| Interval 1 s (modifikasi) | 1 | 0 | | |

Latency diukur dengan cap waktu log publish C6 versus kemunculan pesan pada
`mosquitto_sub` (gunakan `mosquitto_sub -F '%t %p'` atau timestamp terminal).

**Tabel pembanding transport — wajib.** Isi kolom M13 dari data modul
sebelumnya:

| Aspek | HTTP POST (M13) | MQTT publish (M14) |
|---|---|---|
| Koneksi per pesan | | |
| Arah komunikasi | | |
| Perlu tahu alamat penerima? | | |
| Latency rata-rata | | |
| Perilaku saat jaringan putus | | |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Mengapa model publish/subscribe lebih cocok untuk telemetri IoT dibanding HTTP request/response? Dukung dengan tabel pembanding transport.
2. Apa fungsi broker dalam sistem ini dan apa yang terjadi jika broker tidak dapat dijangkau?
3. Bagaimana pengaruh RSSI Wi-Fi terhadap latency dan keberhasilan publish?
4. Apa perbedaan QoS 0, 1, dan 2 — dan QoS berapa yang **sebenarnya** dipakai kode ini? Jelaskan batasan PubSubClient.
5. Mengapa topic telemetri dan perintah dipisah, bukan digabung satu topic? Kaitkan dengan pola yang sama di M03 dan M08.

## 10 · Concept Check

1. Jelaskan perbedaan pesan MQTT dan pesan HTTP dari sisi overhead dan arah komunikasi.
2. Apa yang dimaksud topic hierarkis, dan bagaimana wildcard `#` dan `+` bekerja?
3. Apa fungsi client ID `esp32c6-praktikum` pada `mqtt.connect()`, dan apa yang terjadi bila dua board memakai ID sama?
4. Apa yang terjadi pada subscription bila koneksi MQTT terputus lalu reconnect?
5. Mengapa praktikum ini menggunakan broker publik, dan apa risikonya? Sebutkan minimal dua, beserta cara menguranginya.

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Retained message.** Aktifkan flag *retained* (`mqtt.publish(topic, payload, true)`), lalu jalankan subscriber **setelah** publish berjalan dan amati apakah pesan terakhir langsung diterima. Catatan: argumen ketiga adalah `retained`, **bukan** QoS. Untuk menguji QoS 1 diperlukan library lain (mis. `arduino-mqtt` / `AsyncMqttClient`); jelaskan konsekuensinya di laporan.

- **CH-2 — Aksi nyata.** Tambahkan aksi pada perintah: toggle LED bawaan berdasarkan `LED_ON`/`LED_OFF`, dan publish balik status LED ke `praktikum/h2/status`. Ini melengkapi lingkaran perintah→aksi→laporan.

- **CH-3 — Packet loss (wajib).** Hitung packet loss dengan sequence number pada payload (`26.4,#15`). Contoh: 50 publish, 48 diterima subscriber → loss = (50−48)/50 × 100 % = 4 %.

- **CH-4 — Topic per perangkat.** Ubah topic menjadi `praktikum/<client_id>/telemetri` dan subscribe dengan wildcard `praktikum/+/telemetri` di PC. Diskusikan bagaimana skema ini menskalakan ke 50 perangkat.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (MQTT, broker, publish/subscribe, topic, QoS, retained, batasan PubSubClient)
3. Konfigurasi — SSID, broker, client ID, topic, library PubSubClient
4. Hasil eksperimen — log Serial Monitor **dan** log `mosquitto_sub`/`mosquitto_pub` (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel Bagian 8 **dan** tabel pembanding HTTP vs MQTT
6. Analisis + concept check
7. Challenge — minimal CH-2 dan CH-3
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
