```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
       MODUL 04 — Telemetry Berkala lewat Notify

  ESP32-H2 · BLE NOTIFY · TELEMETRY · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 04 |
| Misi | Mengubah pola tarik (polling) menjadi pola dorong (notify) dan membuktikan penghematannya dengan angka |
| Platform | ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino |
| Durasi | 3 × 50 menit |
| Mode | Telemetry — Sensor (server, notify) → Monitor (client) |
| Level | Intermediate |
| Instrumen | Serial Monitor 115200 baud (2 terminal) |

## 2 · Keterkaitan Antar-Modul

Modul 03 membuat client **menarik** data berulang-ulang, sebagian besar mubazir. Modul ini membalik arah inisiatif: sensor mendorong nilai baru begitu tersedia, monitor hanya menunggu. Pola inilah yang dipakai semua telemetri di sisa lab — Zigbee attribute report (M09), Thread UDP periodik (M11–13), dan MQTT publish (M14). Angka transaksi/menit yang dihitung pada M03 dipakai lagi di sini sebagai pembanding.

| | Cakupan |
|---|---|
| Prasyarat | M03 — service GATT, hitungan transaksi radio pada skema polling |
| Dibangun di modul ini | Notify sebagai telemetry berkala, subscribe dari client, kontinuitas aliran data, perilaku saat pengirim mati/hidup lagi |
| Dipakai lagi di | M05 (satu central menerima notify dari banyak sensor) → M06 (notify diteruskan hop demi hop) → M14/M15 (telemetri yang sama berakhir di broker MQTT) |

**Peta modul blok BLE**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 01 | Tautan BLE P2P terbentuk & stabil |
| 02 | Payload aplikasi mengalir dua arah |
| 03 | Characteristic mewakili state & perintah (polling) |
| **04 (ini)** | **Polling dihapus — sensor mendorong data sendiri (notify)** |
| 05 | Lebih dari dua node |
| 06 | Relay A→B→C |

**Kontrak data lab ini.** Payload telemetri di lab ini selalu berupa **nilai terukur dalam bentuk string ringkas** (`"26.3"`, nanti `"suhu:26.3"`). Format itu dipertahankan agar hop terakhir — publish MQTT di M14/M15 — tidak perlu mengubah isinya sama sekali (*transparent forwarding*).

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Mengimplementasikan characteristic `NOTIFY` yang mengirim nilai sensor tiap 1000 ms hanya saat ada client yang subscribe.
2. Membuktikan dari log bahwa monitor tidak melakukan satu pun permintaan baca, namun tetap menerima seluruh nilai.
3. Menghitung jumlah transaksi radio per menit skema notify dan membandingkannya dengan skema polling Modul 03 dalam satu tabel.
4. Menjelaskan perilaku sistem saat sensor mati mendadak, berdasarkan log kedua node — bukan berdasarkan dugaan.

**Kriteria keberhasilan**

- ☐ Monitor menerima ± 60 nilai per menit tanpa pernah memanggil `readValue()`.
- ☐ Interval kedatangan terukur ± 1000 ms dan tercatat sebarannya.
- ☐ Uji gangguan (sensor di-reset) dilakukan dan perilaku kedua node tercatat.
- ☐ Tabel perbandingan polling (M03) vs notify (M04) terisi dari angka sendiri.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (siklus connection event BLE, hubungan interval notify dengan konsumsi arus) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Telemetry | Pengiriman nilai terukur dari perangkat ke pemantau secara berkala. |
| Notify | Server mendorong nilai ke client tanpa diminta, tanpa acknowledgement. |
| Indication | Seperti notify tetapi menunggu balasan client — lebih andal, lebih mahal. Tidak dipakai di sini. |
| Subscribe / CCCD | Client mengaktifkan notify; tanpa langkah ini `notify()` di server tidak berefek apa pun. |
| Push vs pull | Push = pengirim menentukan kapan data dikirim; pull = penerima yang meminta (M03). |
| Sensor simulasi | Nilai suhu dibangkitkan `random()`, mulai 25,0 °C, fluktuasi ±1,0 °C, reset ke 25,0 bila keluar rentang 20–40 °C. |

**Mengapa sensornya disimulasi?** Karena yang diuji modul ini adalah **kanal telemetri**, bukan akurasi sensor. Nilai simulasi menghilangkan variabel kalibrasi sehingga setiap kelainan pada log pasti berasal dari kanal radio. Mengganti `readSensor()` dengan sensor asli adalah CH-3.

**Sekuens protokol yang diamati**

```
Sensor (Server)                          Monitor (Client)
  advertise TELEM_SENSOR
        ◄──── connect + subscribe(CCCD) ────
  tiap 1000 ms:
    readSensor() → "26.3"
    notify() ────────────────────────────►  onNotify() → cetak
  (tidak ada permintaan baca sama sekali dari monitor)
```

## 5 · Topologi

```
      BOARD #1                            BOARD #2
┌──────────────────┐   NOTIFY suhu   ┌──────────────────┐
│     ESP32-H2     │ ──────────────► │     ESP32-H2     │
│    DevKitM-1     │   tiap 1 detik  │    DevKitM-1     │
│  Sensor Node     │                 │  Monitor Node    │
│  (TELEM_SENSOR)  │                 │ (TELEM_MONITOR)  │
└──────────────────┘                 └──────────────────┘
     env: sensor                         env: monitor
```

| Node | Board | Environment | Peran | Aksi |
|---|---|---|---|---|
| Sensor | ESP32-H2 DevKitM-1 | `sensor` | GATT Server (`TELEM_SENSOR`) | notify suhu tiap 1000 ms |
| Monitor | ESP32-H2 DevKitM-1 | `monitor` | GATT Client (`TELEM_MONITOR`) | subscribe + cetak tiap notifikasi |

Keduanya **ESP32-H2** (radio Bluetooth LE). Tidak ada ESP32-C6 pada modul ini.

**Address map**

| Objek | UUID |
|---|---|
| Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| CHAR telemetry (NOTIFY) | `beb5483e-36e1-4688-b7f5-ea07361b26b2` |

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 2 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 3 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 4 | Library NimBLE-Arduino | `h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps` | — |
| 5 | Data Modul 03 | tabel transaksi/menit skema polling — dipakai sebagai pembanding | 1 |

Catatan: suhu pada kode adalah **simulasi** (`random`), tidak memakai sensor fisik.

**platformio.ini — pin port agar tidak salah flash**

```ini
[env:sensor]
build_src_filter = +<sensor/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3  -- board Sensor
monitor_port = /dev/ttyACM0

[env:monitor]
build_src_filter = +<monitor/*.cpp>
upload_port  = /dev/ttyACM1     ; Windows: COM4  -- board Monitor
monitor_port = /dev/ttyACM1
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, port tiap board dicatat dan diisikan di atas.
- ☐ Board pertama terhubung (env `sensor`), board kedua terhubung (env `monitor`).
- ☐ Firmware `sensor` dan `monitor` berhasil build tanpa error.
- ☐ Dua Serial Monitor 115200 baud dibuka lebih dulu, lalu RESET kedua board.
- ☐ Angka transaksi/menit dari Modul 03 sudah di tangan.

**Deploy**

```bash
pio device list
pio run -d week04_ble_telemetry -e sensor  -t upload
pio run -d week04_ble_telemetry -e monitor -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Subscribe & Stream Start

Monitor scan, connect, lalu subscribe. Aliran data baru dimulai **setelah** subscribe berhasil — bukan setelah connect.

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama device sensor | |
| Waktu scan → `Koneksi berhasil` (s) | |
| Waktu connect → nilai pertama tiba (s) | |
| Apakah ada `readValue()` di kode monitor? (ya/tidak) | |

**Buka abstraksinya** — sebelum lanjut, komentari baris `pTx->subscribe(...)` di `src/monitor/main.cpp`, flash ulang, dan amati: koneksi tetap terbentuk, sensor tetap memanggil `notify()`, tetapi monitor **tidak menerima apa pun**. Kembalikan kodenya. Ini membuktikan notify bukan sekadar "server mengirim", melainkan kontrak dua pihak yang dicatat di CCCD.

> **CHECKPOINT** — Monitor mencetak `Koneksi berhasil, menunggu telemetry...` lalu baris `Telemetry diterima` pertama muncul < 1,5 detik kemudian. Jika baris kedua tidak pernah muncul, subscribe gagal — periksa dulu.

### EXP-02 — Aliran Telemetri

Sensor mengirim nilai tiap 1000 ms selama monitor terhubung.

**Expected output — Sensor**

```
Sensor Node starting...
Menunggu monitor...
Monitor terhubung
Notify: suhu = 25.3 C
Notify: suhu = 26.1 C
```

**Expected output — Monitor**

```
Monitor Node starting...
Scanning sensor...
Sensor ditemukan
Terhubung ke sensor
Koneksi berhasil, menunggu telemetry...
Telemetry diterima: suhu = 25.3 C
Telemetry diterima: suhu = 26.1 C
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Interval notify (ms) | 1000 |
| Format payload | `s.d` (contoh: 26.3) |
| Rentang nilai suhu teramati (°C) | |
| Jumlah telemetry diterima / 60 detik | |
| Interval kedatangan terkecil / terbesar (ms) | |

> **CHECKPOINT** — Tiap nilai `Notify:` di sensor punya pasangan `Telemetry diterima:` di monitor dengan angka yang sama persis. Cocokkan minimal 10 baris berturut-turut sebelum masuk EXP-03.

### EXP-03 — Kontinuitas & Pemulihan

1. Reset sensor selama ± 5 detik lalu nyalakan lagi. Amati `Monitor terputus, advertise ulang` di sensor dan apa yang dilakukan monitor.
2. Catat apakah aliran pulih sendiri atau monitor perlu di-reset — dan **jelaskan dari kode** mengapa demikian.
3. Jauhkan sensor perlahan sampai ada nilai yang hilang; catat interval kedatangan saat mulai tidak teratur.

**Data capture**

| Parameter | Hasil |
|---|---|
| Pesan di sensor saat monitor hilang | |
| Pesan di monitor saat sensor hilang | |
| Aliran pulih otomatis? (ya/tidak) | |
| Alasan berdasarkan kode | |

> **CHECKPOINT** — Praktikan dapat menunjukkan baris kode yang menentukan apakah monitor melakukan scan ulang atau tidak. Jika belum bisa, jangan lanjut ke analisis — jawabannya ada di `setup()` monitor.

### Verifikasi hardware (log referensi)

Dijalankan pada 2 × **ESP32-H2 DevKitM-1**, capture 25 detik.

```
# Sensor (ESP32-H2, env sensor)        # Monitor (ESP32-H2, env monitor)
[1.404] Notify: suhu = 24.3 C          [1.405] Telemetry diterima: suhu = 24.3 C
[2.406] Notify: suhu = 23.4 C          [2.407] Telemetry diterima: suhu = 23.4 C
[3.407] Notify: suhu = 23.8 C          [3.409] Telemetry diterima: suhu = 23.8 C
```

| Parameter | Hasil terukur |
|---|---|
| Notify dikirim sensor | 24 |
| Telemetry diterima monitor | 24 (0 % loss) |
| Interval kedatangan | 1001 ± 2 ms |
| Rentang suhu teramati | 21,3 – 24,3 °C |
| Selisih waktu sensor → monitor | 1–2 ms |

## 8 · Pengukuran

| Jarak | RSSI (dBm) | Telemetry diterima /60 s (harapan 60) | Loss (%) | Interval terbesar (ms) |
|---|---|---|---|---|
| 1 m | | | | |
| 3 m | | | | |
| 5 m | | | | |
| 10 m | | | | |
| 15 m | | | | |

**Tabel pembanding wajib — polling (M03) vs notify (M04)**

Isi kolom kiri dari data Modul 03 dan kolom kanan dari modul ini:

| Aspek | Polling (M03) | Notify (M04) |
|---|---|---|
| Transaksi radio / menit | | |
| Nilai baru yang benar-benar terbawa / menit | | |
| Transaksi mubazir (nilai tak berubah) / menit | | |
| Siapa yang menentukan waktu kirim | client | sensor |
| Konsekuensi bila data jarang berubah | | |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Berapa jumlah telemetry yang diterima per menit, dan berapa persen dari nilai yang dikirim sensor?
2. Bandingkan transaksi radio per menit skema polling dan notify dari tabel pembanding. Berapa persen penghematannya?
3. Pada jarak berapa interval kedatangan mulai tidak teratur, dan bagaimana bentuk ketidakteraturannya (melar atau melompat)?
4. Jika data hanya berubah tiap 10 detik, skema mana yang lebih boros? Tunjukkan dengan angka.
5. Apa risiko notify dibanding indication untuk data yang tidak boleh hilang (mis. alarm)?

## 10 · Concept Check

1. Apa beda notify dan indication, dan kapan masing-masing dipakai?
2. Mengapa `notify()` tidak berefek apa pun sebelum client subscribe?
3. Apa yang disimpan di CCCD dan siapa yang menulisnya?
4. Mengapa sensor sebaiknya berhenti mengirim saat tidak ada client terhubung?
5. Bagaimana pola push ini nanti diterjemahkan ke MQTT pada Modul 14?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Telemetri berpenanda (wajib).** Ubah payload menjadi `suhu:26.3,#<seq>` dengan nomor urut naik. Monitor menghitung loss dari lompatan nomor. Format ini dipakai lagi di M13–M16.

  ```cpp
  // Sensor — loop()
  static uint32_t seq = 0;
  char msg[32];
  snprintf(msg, sizeof(msg), "suhu:%.1f,#%lu", readSensor(), (unsigned long)++seq);
  ```

- **CH-2 — Interval adaptif.** Kirim notify hanya bila nilai berubah > 0,5 °C dari nilai terakhir yang dikirim, dengan batas maksimal 10 detik tanpa kirim (*heartbeat*). Ukur berapa banyak transaksi yang dihemat dalam 2 menit.

- **CH-3 — Sensor asli.** Ganti `readSensor()` dengan pembacaan sensor nyata (DHT22/DS18B20 bila tersedia). Bandingkan sebaran nilainya dengan versi simulasi dan catat berapa lama satu pembacaan memblokir `loop()`.

- **CH-4 — Self-healing.** Buat monitor melakukan scan ulang otomatis pada `onDisconnect` sehingga aliran pulih tanpa reset manual. Ukur waktu pemulihannya, 5 percobaan, hitung rata-rata.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (telemetry, notify vs indication, push vs pull)
3. Konfigurasi — `platformio.ini`, environment, UUID characteristic telemetri
4. Hasil eksperimen — log kedua node (EXP-01…03 + checkpoint), termasuk hasil uji subscribe dikomentari
5. Data pengukuran — tabel Bagian 8 **dan** tabel pembanding polling vs notify
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2, sertakan angka penghematan transaksi
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
