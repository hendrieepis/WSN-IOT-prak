```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
     MODUL 02 — Pertukaran Data Dua Arah via BLE

     ESP32-H2 · BLE GATT · NOTIFY/WRITE · Level: Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 02 |
| Misi | Memindahkan payload aplikasi ke dua arah di atas tautan BLE dan mengukur apa yang selamat sampai tujuan |
| Platform | ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino |
| Durasi | 3 × 50 menit |
| Mode | P2P — Server (notify + write) ↔ Client |
| Level | Basic |
| Instrumen | Serial Monitor 115200 baud (2 terminal) |

## 2 · Keterkaitan Antar-Modul

Modul 01 hanya membuktikan **tautan** terbentuk — belum ada satu byte
aplikasi pun yang lewat. Modul ini memakai tautan itu untuk membawa data, dan
memperkenalkan dua mekanisme yang akan dipakai terus sampai Modul 16: **notify**
(server mendorong) dan **write** (client mengirim).

| | Cakupan |
|---|---|
| Prasyarat | M01 — tautan BLE P2P terbentuk, Serial Monitor terbaca sebagai instrumen |
| Dibangun di modul ini | Dua characteristic (TX/NOTIFY dan RX/WRITE), subscribe, callback `onWrite`/`onNotify`, echo, pengukuran loss dua arah |
| Dipakai lagi di | M03 (characteristic jadi data terstruktur) → M04 (notify jadi telemetry berkala) → M05 (banyak node) → M16 (loss & latency jadi metrik pembanding protokol) |

**Peta modul blok BLE**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 01 | Tautan BLE P2P terbentuk & stabil |
| **02 (ini)** | **Payload aplikasi mengalir dua arah lewat tautan M01** |
| 03 | GATT characteristic — read/write data terstruktur |
| 04 | Telemetry via notify (push berkala tanpa polling) |
| 05 | Lebih dari dua node — satu central, banyak peripheral |
| 06 | Relay A→B→C, jangkauan diperluas lewat hop |

**Kontrak data lab ini.** Mulai modul ini setiap payload membawa penanda yang
bisa dihitung — di sini `millis()`, mulai CH-1 berupa nomor urut `SEQ=<n>`.
Nomor urut itulah yang membuat *packet loss* bisa dihitung, dan format yang
sama akan muncul lagi di Zigbee (M09), Thread (M12), dan MQTT (M14).

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membuat dua characteristic pada satu service BLE dengan property berbeda (`NOTIFY` untuk TX, `WRITE` untuk RX) dan menunjukkan baris kode yang menetapkannya.
2. Menjalankan subscribe dari sisi client sehingga notify dari server benar-benar diterima, dibuktikan dari log kedua node.
3. Mengirim data dari client ke server memakai write dan menjelaskan jalur echo-nya (`onWrite` → `notify` → `onNotify`) dari urutan timestamp di dua Serial Monitor.
4. Menghitung packet loss tiap arah secara terpisah (notify hilang vs write hilang) pada minimal 4 jarak berbeda.

**Kriteria keberhasilan**

- ☐ Client subscribe ke characteristic TX dan menerima notify tiap 2 detik.
- ☐ Write dari client tiba di server dan di-echo balik utuh (isi sama persis).
- ☐ Tabel jarak–RSSI–loss terisi dari pengukuran sendiri, minimal 4 jarak.
- ☐ CH-1 selesai: payload memakai `SEQ=<n>` sehingga loss terhitung dari lompatan nomor.

## 4 · Dasar Teori (secukupnya)

Teori di sini dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(kenapa GATT dirancang berlapis, detail ATT/L2CAP) ada di buku teori terpisah —
panduan ini fokus pada "gimana".*

| Istilah | Definisi kerja di lab ini |
|---|---|
| GATT | Skema data hierarkis Server → Service → Characteristic. |
| Service | Wadah characteristic; UUID `4fafc201-1fb5-459e-8fcc-c5c9c331914b`. |
| Characteristic | Unit data; punya UUID sendiri dan satu/lebih property. |
| Property WRITE | Client boleh menulis nilai ke characteristic milik server. |
| Property NOTIFY | Server mendorong nilai ke client tanpa diminta — tetapi hanya setelah client subscribe. |
| Subscribe | Client mengaktifkan notify pada characteristic TX (menulis ke CCCD). |
| `onWrite` / `onNotify` | Callback yang dipicu saat data ditulis ke server / notifikasi tiba di client. |
| Echo | Server mengirim balik isi write lewat notify — dipakai untuk membuktikan jalur pulang. |

**Kenapa dua characteristic, bukan satu?** Satu characteristic hanya bisa
mengalir efisien ke satu arah: `NOTIFY` adalah dorongan server→client,
`WRITE` adalah kiriman client→server. Memisahkan TX dan RX membuat arah data
terbaca langsung dari UUID-nya — pola yang sama dipakai profil serial BLE
(Nordic UART Service) di dunia nyata.

**Sekuens protokol yang diamati**

```
Node1 (Server)                              Node2 (Client)
  CHAR_TX (NOTIFY) ──── "Hello dari Node1" ────►  onNotify()
  CHAR_RX (WRITE)  ◄─── "Halo dari Node2"  ─────  writeValue()
  onWrite() ─── echo lewat CHAR_TX ────────────►  onNotify()
```

## 5 · Topologi

```
   BOARD #1                          BOARD #2
┌──────────────┐   NOTIFY (TX)   ┌──────────────┐
│   ESP32-H2   │ ──────────────► │   ESP32-H2   │
│  DevKitM-1   │                 │  DevKitM-1   │
│    Node 1    │                 │    Node 2    │
│ (BLE Server) │ ◄────────────── │ (BLE Client) │
└──────────────┘  WRITE (RX)     └──────────────┘
   env: node1                        env: node2
```

| Node | Board | Environment | Peran | Aksi periodik |
|---|---|---|---|---|
| Node 1 | ESP32-H2 DevKitM-1 | `node1` | BLE Server (`NODE1_H2`) | notify `Hello dari Node1 (<millis>)` tiap 2 s |
| Node 2 | ESP32-H2 DevKitM-1 | `node2` | BLE Client | write `Halo dari Node2 (<millis>)` tiap 3 s |

Kedua peran berjalan di **ESP32-H2** dengan radio Bluetooth LE — modul ini
tidak membutuhkan ESP32-C6. Pesan yang diterima server di-echo kembali ke
client lewat notify.

**Address map** (identik di kedua node)

| Objek | UUID |
|---|---|
| Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| CHAR_TX (NOTIFY) | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| CHAR_RX (WRITE) | `beb5483e-36e1-4688-b7f5-ea07361b26a9` |

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 2 |
| 2 | Kabel USB data | USB-A/C ke micro-USB, **kabel data** (bukan kabel charge-only) | 2 |
| 3 | PC/Laptop | PlatformIO Core/IDE terpasang, 2 port USB bebas | 1 |
| 4 | Library NimBLE-Arduino | `h2zero/NimBLE-Arduino@^2.2.3` — otomatis via `lib_deps` | — |
| 5 | Platform PlatformIO | pioarduino `espressif32` 55.03.311 (Arduino core 3.3.11) | — |

**platformio.ini — kunci agar dua board tidak salah flash**

Dengan dua ESP32-H2 tercolok bersamaan, auto-detect port bisa mengirim firmware
`node1` ke board yang kamu maksud jadi `node2`. Pin port tiap environment:

```ini
[env:node1]
build_src_filter = +<node1/*.cpp>
upload_port  = /dev/ttyACM0     ; Windows: COM3  -- board Node1
monitor_port = /dev/ttyACM0

[env:node2]
build_src_filter = +<node2/*.cpp>
upload_port  = /dev/ttyACM1     ; Windows: COM4  -- board Node2
monitor_port = /dev/ttyACM1
```

**Pre-flight checklist**

- ☐ Jalankan `pio device list`, catat port tiap board, isi `upload_port`/`monitor_port` di atas.
- ☐ Board pertama terhubung (akan diflash `node1`, BLE Server), board kedua terhubung (`node2`, BLE Client).
- ☐ Firmware `node1` dan `node2` berhasil build tanpa error.
- ☐ Dua Serial Monitor 115200 baud dibuka lebih dulu, lalu tekan RESET agar sekuens boot terekam.

**Deploy**

```bash
pio device list                                      # catat port dulu
pio run -d week02_ble_p2p_data -e node1 -t upload
pio run -d week02_ble_p2p_data -e node2 -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Connect & Subscribe

Node1 advertise `NODE1_H2`; Node2 scan, konek, mencari service dan kedua
characteristic, lalu subscribe ke TX.

```
Node2: Scan ─► NODE1_H2 ditemukan ─► Connect ─► getService()
      ─► getCharacteristic(TX/RX) ─► subscribe(TX, notify)
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama device server yang ditemukan | |
| Service UUID ditemukan | |
| Jumlah characteristic ditemukan | |
| Waktu dari scan sampai subscribe selesai (s) | |

**Buka abstraksinya** — di `src/node2/main.cpp`, `pTx->subscribe(true, onNotify)`
tampak seperti satu baris biasa. Sebenarnya baris itu **menulis ke CCCD**
(Client Characteristic Configuration Descriptor) milik server. Cari di
`src/node1/main.cpp` di mana descriptor itu dibuat — jawabannya: tidak ada,
NimBLE menambahkannya otomatis begitu property `NOTIFY` dipasang. Buktikan
dengan nRF Connect: buka characteristic TX dan lihat descriptor `0x2902`.

> **CHECKPOINT** — Node2 mencetak `Koneksi berhasil`. Jika berhenti di
> `Scanning Node1...`: pastikan board `node1` menyala dan nama pada
> `advertisedDevice->getName()` di Node2 sama persis dengan
> `pAdvertising->setName()` di Node1.

### EXP-02 — Downlink: Server → Client (notify)

Setelah terhubung, Node1 mengirim notify setiap 2000 ms.

**Expected output — Node1 (Server)**

```
Node1 (BLE Server) starting...
Menunggu koneksi dari Node2...
Client terhubung
TX ke Node2: Hello dari Node1 (2043)
TX ke Node2: Hello dari Node1 (4047)
```

**Expected output — Node2 (Client)**

```
Node2 (BLE Client) starting...
Scanning Node1...
Node1 ditemukan
Terhubung ke Node1
Koneksi berhasil
RX dari Node1: Hello dari Node1 (2043)
RX dari Node1: Hello dari Node1 (4047)
```

> **CHECKPOINT** — Baris `RX dari Node1` muncul di Node2 dengan jarak ±2 detik
> dan nilai `millis()` yang sama persis dengan `TX ke Node2` di Node1. Kalau
> nilainya berbeda, kamu sedang membaca log yang tidak sinkron — hentikan dan
> periksa dulu, jangan lanjut ke EXP-03.

### EXP-03 — Uplink + Echo: Client → Server (write)

Node2 menulis ke characteristic RX tiap 3000 ms. Server menerima (`onWrite`),
mencetak, lalu meng-echo balik lewat notify pada characteristic TX.

```
Node2 ── WRITE "Halo dari Node2 (6051)" ──► Node1 CHAR_RX
Node1 ── print "RX dari Node2: ..."
Node1 ── NOTIFY (echo) ──► Node2 print "RX dari Node1: Halo dari Node2 (6051)"
```

**Expected output — Node1**

```
RX dari Node2: Halo dari Node2 (6051)
TX ke Node2: Halo dari Node2 (6051)
```

**Expected output — Node2**

```
TX ke Node1: Halo dari Node2 (6051)
RX dari Node1: Halo dari Node2 (6051)
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Interval notify Node1 (ms) | 2000 |
| Interval write Node2 (ms) | 3000 |
| Contoh payload notify Node1 | |
| Contoh payload write Node2 | |
| Apakah echo diterima Node2? (ya/tidak) | |

> **CHECKPOINT** — Pada Node2 muncul **dua jenis** baris `RX dari Node1`: yang
> berisi `Hello ...` (notify periodik) dan yang berisi `Halo ...` (echo dari
> write kamu sendiri). Kalau hanya satu jenis yang muncul, satu arah belum
> jalan — perbaiki sebelum masuk ke pengukuran.

### Verifikasi hardware (log referensi)

Modul ini sudah dijalankan pada 2 × **ESP32-H2 DevKitM-1** (jarak ±20 cm,
capture 25 detik). Log di bawah adalah hasil sebenarnya, bukan ilustrasi.

```
# Node 1 (ESP32-H2, env node1)          # Node 2 (ESP32-H2, env node2)
[0.200] Node1 (BLE Server) starting...  [0.401] Node2 (BLE Client) starting...
[0.401] Menunggu koneksi dari Node2...  [0.401] Scanning Node1...
[0.601] Client terhubung                [0.401] Node1 ditemukan
[2.205] TX ke Node2: Hello ... (2005)   [0.601] Terhubung ke Node1
[3.407] RX dari Node2: Halo ... (3001)  [2.404] RX dari Node1: Hello ... (2005)
                                        [3.406] TX ke Node1: Halo ... (3001)
                                        [3.406] RX dari Node1: Halo ... (3001)  <- echo
```

| Parameter | Hasil terukur |
|---|---|
| Waktu scan → subscribe | ± 1,4 s |
| Notify Node1 diterima Node2 | 12 / 12 (0 % loss) |
| Write Node2 diterima Node1 | 8 / 8 (0 % loss) |
| Echo kembali ke Node2 | ya, payload utuh |

## 8 · Pengukuran

Pindahkan Node1 menjauh; hitung jumlah pesan yang diterima Node2 per interval
pengamatan. **Hitung tiap arah terpisah** — inti modul ini adalah dua arah
tidak selalu gagal bersamaan.

RSSI dibaca dari log Node2 sendiri. Tambahkan pada heartbeat Node2:

```cpp
// Node2 — di loop(), saat terhubung
Serial.printf("RSSI: %d dBm\n", pClient->getRssi());
```

| RSSI (dBm) | Interpretasi |
|---|---|
| > −70 | Kuat — koneksi andal |
| −70 s/d −85 | Baik — masih stabil |
| −85 s/d −95 | Marginal — mulai rawan putus |
| < −95 | Tidak reliable — sering gagal |

| Jarak | RSSI (dBm) | Notify diterima /30 s (harapan 15) | Write ter-echo /30 s (harapan 10) | Loss downlink (%) | Loss uplink (%) |
|---|---|---|---|---|---|
| 1 m | | | | | |
| 3 m | | | | | |
| 5 m | | | | | |
| 10 m | | | | | |
| 15 m | | | | | |

Latency diestimasi dari selisih nilai `millis()` pada payload terhadap waktu
kedatangan di Node2.

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8, bukan berdasarkan teori saja:

1. Bagaimana pengaruh jarak terhadap nilai RSSI pada pengukuranmu?
2. Pada RSSI berapa pesan mulai hilang? Bandingkan dengan tabel referensi.
3. Berapa latency rata-rata satu arah (Node1 → Node2)?
4. Apakah loss downlink dan uplink mulai naik pada jarak yang sama? Kalau berbeda, apa dugaan penyebabnya (daya pancar, `writeValue(..., true)` yang menunggu response, atau posisi antena)?
5. Untuk data periodik, mana yang lebih hemat: notify atau client mem-*polling* dengan read berulang? Dukung dengan jumlah transaksi per menit dari datamu.

## 10 · Concept Check

1. Apa perbedaan property READ, WRITE, dan NOTIFY pada characteristic?
2. Mengapa client harus subscribe sebelum bisa menerima notify?
3. Apa yang terjadi jika server memanggil `notify()` saat tidak ada client terhubung?
4. Bagaimana arsitektur GATT menentukan arah aliran data?
5. `writeValue(..., true)` menunggu response dari server, `false` tidak. Kapan masing-masing lebih tepat dipakai?

## 11 · Challenge (tugas modifikasi)

Ubah kode, jangan cuma jelaskan hasil.

- **CH-1 — Nomor urut (wajib, dipakai modul berikutnya).** Ganti payload notify Node1 menjadi `SEQ=<n>` dengan nomor urut bertambah tiap kirim, interval 500 ms.

  ```cpp
  // Node1 — loop()
  static uint32_t seq = 0;
  String msg = "SEQ=" + String(++seq);
  ```

- **CH-2 — Deteksi loss otomatis.** Di Node2, simpan nomor urut terakhir dan cetak peringatan saat ada lompatan, lalu hitung loss-nya:

  ```cpp
  // Node2 — di onNotify()
  static uint32_t last = 0;
  uint32_t n = atoi(strchr((char*)pData, '=') + 1);
  if (last && n != last + 1) Serial.printf("LOSS: %lu paket\n", n - last - 1);
  last = n;
  ```
  Contoh pelaporan: 30 dikirim, 27 diterima → loss = (30 − 27)/30 × 100 % = 10 %.

- **CH-3 — Uplink berpenanda.** Terapkan hal yang sama pada arah write (Node2 → Node1) sehingga loss uplink terhitung otomatis di Node1. Bandingkan angkanya dengan loss downlink pada jarak yang sama.

- **CH-4 — Backpressure.** Turunkan interval notify Node1 ke 50 ms. Amati apakah Node2 masih menerima semua nomor urut. Pada interval berapa mulai ada yang hilang, dan mengapa (petunjuk: connection interval BLE)?

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (GATT, property, subscribe, echo)
3. Konfigurasi — `platformio.ini`, environment, UUID TX/RX
4. Hasil eksperimen — log Serial Monitor kedua arah (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel Bagian 8, loss dua arah terpisah
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2, sertakan potongan kode yang diubah
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
