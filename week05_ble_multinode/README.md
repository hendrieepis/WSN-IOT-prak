```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
       MODUL 05 — Multi-Node BLE (Topologi Bintang)

    ESP32-H2 · BLE · STAR / 2 KONEKSI · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 05 |
| Misi | Menahan dua koneksi sekaligus dari satu central dan membuktikan kedua aliran data tetap utuh |
| Platform | ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino |
| Durasi | 3 × 50 menit |
| Mode | Multi-node (bintang) — 1 central, 2 peripheral |
| Level | Intermediate |
| Instrumen | Serial Monitor 115200 baud (3 terminal) |

## 2 · Keterkaitan Antar-Modul

Empat modul pertama hanya pernah menangani **satu** lawan bicara. Di sini
jumlah node menjadi variabel — dan bersamanya muncul pertanyaan khas WSN:
apakah pusat jaringan sanggup melayani semua node, dan bagaimana cara
membedakan sumber tiap pesan. Jawaban modul ini (satu objek client per node,
laju per node dihitung terpisah) adalah versi sederhana dari binding table
Zigbee (M09) dan mesh Thread (M12).

| | Cakupan |
|---|---|
| Prasyarat | M04 — notify sebagai telemetry, subscribe, pengukuran loss |
| Dibangun di modul ini | Dua objek `NimBLEClient` hidup bersamaan, pemisahan aliran per sumber, laju per node, ketahanan saat satu node hilang |
| Dipakai lagi di | M06 (node ketiga jadi hop, bukan cabang) → M09 (satu coordinator, banyak end device) → M12 (many-to-many) → M16 (batas skala jadi bahan pembanding protokol) |

**Peta modul blok BLE**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 01 | Tautan BLE P2P terbentuk & stabil |
| 02 | Payload aplikasi mengalir dua arah |
| 03 | Characteristic mewakili state & perintah |
| 04 | Telemetry via notify |
| **05 (ini)** | **Jumlah node jadi variabel — satu pusat, banyak sumber** |
| 06 | Node ketiga dipakai sebagai relay, bukan cabang |

**Kontrak data lab ini.** Setiap peripheral memberi **prefiks identitas** pada
payloadnya (`A:n`, `B:n`). Tanpa penanda sumber, pesan dari banyak node tidak
bisa dipisahkan di pusat — masalah yang persis sama muncul lagi di M09
(`short addr`), M12 (`NODE_ID`), dan M15 (`node2` pada payload MQTT).

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membangun satu central BLE yang memelihara dua koneksi aktif bersamaan dan menunjukkan objek/state yang memisahkan keduanya di dalam kode.
2. Menghitung laju pesan tiap node secara terpisah (pesan/menit) dan mencocokkannya dengan interval yang diprogram (A: 30/menit, B: 20/menit).
3. Menghitung packet loss **per node**, bukan gabungan, pada minimal 4 jarak.
4. Menjelaskan perilaku sistem saat salah satu peripheral hilang dan kembali, berdasarkan log ketiga board.

**Kriteria keberhasilan**

- ☐ Central memegang dua koneksi aktif bersamaan (`Koneksi ke kedua node selesai`).
- ☐ Laju tiap node sesuai perhitungan interval (A: 30/menit, B: 20/menit).
- ☐ Loss per node terukur terpisah dan tercatat di tabel.
- ☐ Uji ketahanan (Node B dimatikan lalu dinyalakan) dilakukan dan hasilnya dicatat.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(penjadwalan connection event multi-link, batas jumlah koneksi NimBLE) ada di
buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Topologi bintang | Satu pusat berkomunikasi dengan banyak node; semua lalu lintas lewat pusat. |
| Advertising | Peripheral menyiarkan nama dan Service UUID agar ditemukan central. |
| Active scan | Central mengirim scan-request agar nama device ikut terbaca. |
| Multi-connection | Satu central memelihara beberapa objek `NimBLEClient` sekaligus (di sini 2). |
| Notify | Peripheral mendorong data ke central setelah di-subscribe. |
| Time-sharing radio | Satu radio melayani dua koneksi bergantian — sumber utama penurunan laju bila node bertambah banyak. |

**Kenapa interval A dan B sengaja dibedakan?** Kalau keduanya sama, log central
akan berselang-seling rapi dan kamu tidak bisa membedakan "central melayani dua
node dengan benar" dari "central hanya mencatat bergantian". Interval 2 s dan
3 s menghasilkan pola tak beraturan yang hanya cocok bila kedua aliran memang
independen.

**Sekuens protokol yang diamati**

```
 Peripheral A                 Central                  Peripheral B
 (advertise) ────► scan 5 s ────► (temukan A & B)
                connect A ──────► subscribe notify A
                connect B ──────► subscribe notify B
 "A:1","A:2"… ────notify───►        ◄───notify──── "B:1","B:2"…
```

## 5 · Topologi

```
                        BOARD #1
                 +---------------------+
                 |      ESP32-H2       |
                 |   MULTI_CENTRAL     |
                 | (client, 2 koneksi) |
                 +----------+----------+
                /                     \
       koneksi 1                       koneksi 2
             /                           \
     BOARD #2                             BOARD #3
  +----------+---------+      +----------+---------+
  |     ESP32-H2       |      |     ESP32-H2       |
  |   MULTI_NODE_A     |      |   MULTI_NODE_B     |
  | notify "A:n" / 2 s |      | notify "B:n" / 3 s |
  +--------------------+      +--------------------+
      env: nodea                    env: nodeb
```

| Node | Board | Environment | Peran | Payload / interval |
|---|---|---|---|---|
| Central | ESP32-H2 DevKitM-1 | `central` | BLE Central, 2 koneksi | — |
| Node A | ESP32-H2 DevKitM-1 | `nodea` | Peripheral `MULTI_NODE_A` | `A:n` tiap 2000 ms |
| Node B | ESP32-H2 DevKitM-1 | `nodeb` | Peripheral `MULTI_NODE_B` | `B:n` tiap 3000 ms |

Ketiga peran memakai board yang sama, **ESP32-H2 DevKitM-1**, dengan radio
Bluetooth LE. ESP32-C6 tidak dipakai pada modul ini.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 3 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 3 |
| 3 | PC/Laptop | PlatformIO Core/IDE, idealnya 3 port USB bebas | 1 |
| 4 | Library NimBLE-Arduino | `h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps` | — |
| 5 | Ruang uji | jarak awal ±1 m antar board, bebas logam di dekat antena | — |

Bila port USB kurang dari tiga, monitor boleh dibuka bergantian — tetapi
minimal central harus terus termonitor selama pengukuran.

**platformio.ini — pin port agar tidak salah flash**

```ini
[env:central]
build_src_filter = +<central/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3
monitor_port = /dev/ttyACM0

[env:nodea]
build_src_filter = +<nodea/*.cpp>
upload_port  = /dev/ttyACM1     ; Windows: COM4
monitor_port = /dev/ttyACM1

[env:nodeb]
build_src_filter = +<nodeb/*.cpp>
upload_port  = /dev/ttyACM2     ; Windows: COM5
monitor_port = /dev/ttyACM2
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, tiga port dicatat dan diisikan di atas.
- ☐ Ketiga ESP32-H2 terpasang dan terdeteksi.
- ☐ Environment `central`, `nodea`, `nodeb` dikenali PlatformIO.
- ☐ Serial Monitor 115200 baud siap (3 terminal).
- ☐ Penempatan tiga perangkat direncanakan (jarak awal ±1 m).

**Deploy** — flash **peripheral dulu**, central belakangan, agar saat central
melakukan scan 5 detik keduanya sudah mengudara:

```bash
pio run -d week05_ble_multinode -e nodea   -t upload
pio run -d week05_ble_multinode -e nodeb   -t upload
pio run -d week05_ble_multinode -e central -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Menyalakan Dua Peripheral

Unggah firmware peripheral ke dua board, verifikasi keduanya advertise dan
menunggu central.

```
 +-----+  advertise    (udara)   advertise  +-----+
 |  A  | ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~> |  B  |
 +-----+ <~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ +-----+
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama BLE Node A | |
| Nama BLE Node B | |
| Pesan `Menunggu central...` muncul di keduanya? | |
| Interval kirim A (ms) | |
| Interval kirim B (ms) | |

> **CHECKPOINT** — Kedua peripheral mencetak `Menunggu central...` dan belum
> mencetak `Notify:` sama sekali. Kalau sudah ada `Notify:` padahal central
> belum menyala, berarti node mengirim tanpa penerima — periksa syarat
> `deviceConnected` di kodenya.

### EXP-02 — Dua Koneksi & Subscribe

Unggah environment `central` ke board ketiga. Central melakukan active scan
5 detik, menemukan `MULTI_NODE_A` dan `MULTI_NODE_B`, lalu membuka dua koneksi
dan subscribe notify pada masing-masing.

```
 scan 5 s ──► temukan A ──► connect A ──► subscribe A
          ──► temukan B ──► connect B ──► subscribe B
                          (loop: cetak setiap notify)
```

**Expected output — Central**

```
Central (multi-node) starting...
Scanning node A dan B...
Node A ditemukan
Node B ditemukan
NodeA terhubung
NodeB terhubung
Koneksi ke kedua node selesai
[NodeA] RX: A:1
[NodeB] RX: B:1
[NodeA] RX: A:2
[NodeA] RX: A:3
[NodeB] RX: B:2
```

**Expected output — Peripheral (contoh Node A)**

```
Node A (peripheral) starting...
Menunggu central...
Central terhubung
Notify: A:1
Notify: A:2
```

**Buka abstraksinya** — di `src/central/main.cpp`, cari **berapa objek
`NimBLEClient` yang dibuat** dan bagaimana callback notify tahu pesan ini
datang dari A atau dari B. Jawabannya bukan dari isi payload — payload hanya
kebetulan diberi prefiks. Telusuri sampai ketemu mekanisme sebenarnya, lalu
jawab: kalau kedua node mengirim payload identik `"data"`, apakah central masih
bisa membedakannya?

> **CHECKPOINT** — Central mencetak `Koneksi ke kedua node selesai` dan setelah
> itu muncul baris `[NodeA]` **dan** `[NodeB]` bergantian tak beraturan. Kalau
> hanya satu label yang pernah muncul, koneksi kedua gagal — ulangi scan dengan
> mereset central (peripheral tetap menyala).

### EXP-03 — Laju & Ketahanan

Biarkan sistem berjalan 2–3 menit, ukur laju pesan tiap node, lalu uji
ketahanan: reset (atau cabut USB) Node B, amati `NodeB terputus` di central dan
`Central terputus, advertise ulang` di Node B, lalu nyalakan kembali dan
verifikasi pemulihan.

**Data capture**

| Parameter | Hasil |
|---|---|
| Jumlah pesan A / menit (harapan 30) | |
| Jumlah pesan B / menit (harapan 20) | |
| Apakah laju A berubah saat B mati? | |
| Perilaku central saat Node B reset | |
| Apakah koneksi B pulih otomatis? | |

> **CHECKPOINT** — Saat Node B dimatikan, aliran `[NodeA]` **tidak boleh**
> ikut berhenti. Kalau ikut berhenti, central kehilangan kedua koneksi — itu
> temuan penting, catat dan jelaskan di analisis.

### Verifikasi hardware (log referensi)

Dijalankan pada 3 × **ESP32-H2 DevKitM-1** (jarak ±20 cm), capture 30 detik.

```
# Central (ESP32-H2, env central)
[0.401] Node B ditemukan
[0.401] Node A ditemukan
[0.802] NodeA terhubung
[1.604] NodeB terhubung
[2.205] Koneksi ke kedua node selesai
[2.406] [NodeA] RX: A:1
[3.408] [NodeB] RX: B:1
[4.409] [NodeA] RX: A:2
[6.413] [NodeA] RX: A:3
[6.413] [NodeB] RX: B:2
```

| Parameter | Hasil terukur |
|---|---|
| Waktu scan → dua koneksi aktif | 2,2 s |
| Node A: notify dikirim / diterima central | 14 / 14 (0 % loss) |
| Node B: notify dikirim / diterima central | 9 / 9 (0 % loss) |
| Laju Node A | 2,00 s per pesan → 30 pesan/menit |
| Laju Node B | 3,00 s per pesan → 20 pesan/menit |

Dua koneksi simultan tidak menggeser interval kedua node — pada beban ringan
ini central masih mampu melayani keduanya tanpa kehilangan pesan.

## 8 · Pengukuran

Ukur **per node**, jangan digabung. Ini inti modul: dua node pada satu central
tidak selalu terdegradasi bersamaan.

| Jarak (A dan B sama jauh) | RSSI A | RSSI B | Pesan A /60 s (harapan 30) | Pesan B /60 s (harapan 20) | Loss A (%) | Loss B (%) |
|---|---|---|---|---|---|---|
| 1 m | | | | | | |
| 3 m | | | | | | |
| 5 m | | | | | | |
| 10 m | | | | | | |

**Skenario asimetris** (wajib, minimal satu baris) — dekatkan A, jauhkan B:

| Posisi A | Posisi B | Loss A (%) | Loss B (%) | Kesimpulan |
|---|---|---|---|---|
| 1 m | 10 m | | | |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Bagaimana hubungan jarak terhadap RSSI dan keberhasilan penerimaan dari kedua node?
2. Apakah jumlah pesan per menit sesuai perhitungan dari interval tiap node? Jelaskan bila ada selisih.
3. Berapa latency dari `Notify` di peripheral hingga `RX` di central? Apakah bertambah pada jarak jauh?
4. Pada skenario asimetris, apakah node yang jauh menurunkan kualitas node yang dekat? Apa artinya bagi desain WSN?
5. Apakah topologi bintang BLE cocok untuk WSN banyak node? Bandingkan dengan koneksi P2P modul sebelumnya, dan perkirakan apa yang terjadi pada 10 node.

## 10 · Concept Check

1. Apa perbedaan peran central dan peripheral dalam BLE?
2. Mengapa central perlu subscribe pada tiap characteristic notify secara terpisah?
3. Bagaimana central membedakan pesan dari Node A dan Node B — dari payload atau dari sesuatu yang lain?
4. Apa yang terjadi pada peripheral saat koneksi terputus, dan bagaimana pemulihannya?
5. Apa yang membatasi jumlah koneksi pada topologi bintang BLE (dari sisi stack dan dari sisi radio)?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Node ketiga.** Tambahkan Node C (peripheral ketiga, interval 5 s, pesan `C:n`). Hitung persentase pesan tiap node terhadap total di central dan periksa apakah laju A dan B berubah setelah C bergabung.

- **CH-2 — Loss otomatis per node.** Hitung packet loss dari nomor urut, terpisah untuk tiap node:

  ```cpp
  // Central — di callback notify, simpan last[] per node
  static uint32_t last[2] = {0, 0};
  uint32_t n = atoi(strchr(buf, ':') + 1);
  if (last[idx] && n != last[idx] + 1)
      Serial.printf("LOSS %c: %lu paket\n", 'A' + idx, n - last[idx] - 1);
  last[idx] = n;
  ```
  Contoh: counter Node A mencapai 120 dalam 4 menit tetapi central menerima 116 → loss = (120−116)/120 × 100 % = 3,33 %.

- **CH-3 — Cari batas skala.** Turunkan interval kedua node ke 100 ms. Catat pada interval berapa central mulai kehilangan pesan, dan node mana yang lebih dulu terdampak. Kaitkan dengan konsep *time-sharing radio*.

- **CH-4 — Reconnect otomatis.** Buat central melakukan scan ulang dan menyambung kembali node yang hilang tanpa perlu reset. Ukur waktu pemulihannya, 5 percobaan.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (central/peripheral, multi-connection, topologi bintang)
3. Konfigurasi — environment `central`/`nodea`/`nodeb`, UUID, interval
4. Hasil eksperimen — log serial tiga perangkat (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel per node **dan** tabel skenario asimetris
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
