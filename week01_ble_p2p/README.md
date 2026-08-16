```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 01 — Komunikasi BLE Point-to-Point

        ESP32-H2 · BLE · P2P · Level: Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 01 |
| Misi | Membangun tautan BLE point-to-point yang stabil dan terverifikasi lewat instrumen |
| Platform | ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino |
| Durasi | 3 × 50 menit |
| Mode | P2P — Peripheral ↔ Central |
| Level | Basic |
| Instrumen | Serial Monitor 115200 baud (nRF Connect opsional) |

## 2 · Keterkaitan Antar-Modul

BLE adalah stack berlapis. Modul ini adalah lapisan paling bawah: tautan radio
itu sendiri — belum ada payload aplikasi. Modul-modul berikutnya menumpuk di
atas tautan yang kamu bangun di sini, jadi kerjakan modul ini sampai
benar-benar solid sebelum lanjut.

| | Cakupan |
|---|---|
| Prasyarat | Dasar C dan alur build PlatformIO (modul pembuka — tidak ada modul BLE sebelumnya) |
| Dibangun di modul ini | Advertising, active scanning, pembentukan koneksi P2P, dan pengukuran RSSI terhadap jarak |
| Dipakai lagi di | M02 (payload di atas tautan ini) → M03 (GATT read/write) → M04 (telemetry notify) → M05 (> 2 node) |

**Peta modul blok BLE**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| **01 (ini)** | **Tautan BLE P2P terbentuk & stabil** |
| 02 | Pertukaran payload aplikasi lewat tautan M01 |
| 03 | GATT characteristic — read/write data terstruktur |
| 04 | Telemetry via notify (push berkala tanpa polling) |
| 05 | Skala lebih dari dua node (menuju ranah WSN) |
| 06 | Relay A→B→C — jangkauan diperluas lewat hop |

**Kontrak data lab ini.** Modul ini belum mengirim payload, tetapi sudah
menetapkan dua hal yang dipakai seterusnya: **Service UUID**
`4fafc201-1fb5-459e-8fcc-c5c9c331914b` (dipakai ulang M02–M06 dan M16) dan
**Serial Monitor sebagai instrumen ukur**, bukan sekadar tempat log.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Menjelaskan perbedaan peran BLE Peripheral (advertiser/server) dan Central (scanner/client).
2. Menyusun proyek PlatformIO dua environment (`node1`, `node2`) dan memilih source per board lewat `build_src_filter`.
3. Menjalankan advertising dengan Device Name dan Service UUID tertentu, lalu memverifikasinya dari paket yang benar-benar mengudara.
4. Membangun koneksi BLE point-to-point melalui active scanning dari sisi Central.
5. Mengukur RSSI terhadap jarak dari log node sendiri dan menentukan ambang RSSI saat koneksi mulai gagal.

**Kriteria keberhasilan**

- ☐ Node2 menemukan `NODE1_H2` dan membentuk koneksi.
- ☐ Kedua node mencetak heartbeat status terhubung tiap 5 detik.
- ☐ Uji disconnect (EXP-03) membuktikan tautan dua arah — bukan sekadar heartbeat lokal.
- ☐ Tabel jarak–RSSI–keberhasilan terisi lengkap dari pengukuran sendiri.

## 4 · Dasar Teori (secukupnya)

Teori di sini dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(kenapa BLE hemat daya, detail lapisan protokol) ada di buku teori terpisah —
panduan ini fokus pada "gimana".*

| Istilah | Definisi kerja di lab ini |
|---|---|
| BLE | Varian Bluetooth berdaya rendah untuk komunikasi data berkala. |
| Peripheral / Advertiser | Device yang menyiarkan paket advertising berisi nama device dan Service UUID. |
| Central / Scanner | Device yang memindai paket advertising dan memulai koneksi. |
| Advertising | Proses menyiarkan keberadaan device (nama `NODE1_H2` + Service UUID). |
| Active scan | Scan dengan scan-request tambahan agar data advertising lengkap. |
| Connection | Tautan BLE setelah Central meminta koneksi ke Peripheral. |
| GATT / Service | Struktur data di atas koneksi; modul ini membuat service **tanpa** characteristic. |
| RSSI | Kuat sinyal terima (dBm); makin mendekati 0 makin kuat — −50 lebih kuat dari −90. |

**Kenapa ESP32-H2?** H2 mendukung BLE 5 dan 802.15.4 (Thread/Zigbee), tetapi
tidak punya Wi-Fi maupun Bluetooth Classic. Jadi seluruh komunikasi di seri lab
ini murni BLE (dan 802.15.4 di modul lanjutan) — bukan kebetulan, tapi pilihan
board yang menegaskan fokus lab.

**Kenapa output modul ini sedikit?** Service pada Node1 sengaja dibuat tanpa
characteristic — tidak ada data aplikasi yang dikirim. Setelah banner boot dan
pesan koneksi, kedua node hanya mencetak satu baris heartbeat tiap 5 detik.
Itu bukan tanda program berhenti; itu memang bentuk keberhasilan Modul 01.
Karena heartbeat dicetak dari status **lokal** masing-masing node, bukti tautan
dua arah baru diperoleh di EXP-03.

**Sekuens protokol yang diamati**

```
Advertiser (Node1)                Scanner (Node2)
      │ ──── Advertising ────►        │
      │ ◄─── Connect Request ────     │
      │ ════ Connection (P2P) ════►   │
```

## 5 · Topologi

```
   BOARD #1                        BOARD #2
┌──────────────┐      BLE      ┌──────────────┐
│   ESP32-H2   │◄────────────►│   ESP32-H2   │
│  DevKitM-1   │  Connection   │  DevKitM-1   │
│   Node 1     │               │   Node 2     │
│ (Peripheral/ │               │  (Central/   │
│  Advertiser) │               │   Scanner)   │
└──────────────┘               └──────────────┘
   env: node1                      env: node2
```

| Node | Board | Environment | Peran | Identitas radio |
|---|---|---|---|---|
| Node 1 | ESP32-H2 DevKitM-1 | `node1` | BLE Peripheral (advertise) | `NODE1_H2` |
| Node 2 | ESP32-H2 DevKitM-1 | `node2` | BLE Central (scan + connect) | `NODE2_H2` |

Service UUID kedua node: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 2 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 3 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 4 | Library NimBLE-Arduino | `h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps` | — |
| 5 | Platform PlatformIO | pioarduino `espressif32` 55.03.311 (Arduino core 3.3.11) | — |
| 6 | nRF Connect (opsional) | Android/iOS — cross-check paket advertising | 1 |

**platformio.ini — kunci agar dua board tidak salah flash**

Dengan dua ESP32-H2 tercolok bersamaan, auto-detect port bisa mengirim firmware
`node1` ke board yang kamu maksud jadi `node2`. Pin port tiap environment, dan
pakai `build_src_filter` untuk memilih source per node:

```ini
[env]
platform = https://github.com/pioarduino/platform-espressif32/releases/download/55.03.311/platform-espressif32.zip
framework = arduino
board = esp32-h2-devkitm-1
monitor_speed = 115200
lib_deps = h2zero/NimBLE-Arduino@^2.2.3

[env:node1]
build_src_filter = +<node1/*.cpp>   ; memilih src/node1/main.cpp
upload_port  = /dev/ttyACM0         ; Windows: COM3 -- board Node1
monitor_port = /dev/ttyACM0

[env:node2]
build_src_filter = +<node2/*.cpp>   ; memilih src/node2/main.cpp
upload_port  = /dev/ttyACM1         ; Windows: COM4 -- board Node2
monitor_port = /dev/ttyACM1
```

**Pre-flight checklist**

- ☐ Jalankan `pio device list`, catat port tiap board, isi `upload_port`/`monitor_port` di atas.
- ☐ Board ESP32-H2 pertama terhubung (akan diflash `node1`), board kedua terhubung (`node2`).
- ☐ Toolchain PlatformIO siap; firmware `node1` & `node2` berhasil build tanpa error.
- ☐ Serial Monitor 115200 baud dibuka **lebih dulu**, lalu tekan RESET agar sekuens boot terekam.

**Deploy**

```bash
pio device list                                  # catat port dulu
pio run -d week01_ble_p2p -e node1 -t upload
pio run -d week01_ble_p2p -e node2 -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Advertising & Scanning

Node1 advertise sebagai `NODE1_H2` membawa Service UUID. Node2 melakukan active
scan 5 detik dan mencetak hasil temuan beserta RSSI.

```
Node1: [ADV] "NODE1_H2" + SERVICE_UUID
                 │
                 ▼
Node2: Scan 5 detik ──► onResult() ──► nama cocok? ──► stop scan
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama device yang ditemukan | |
| Service UUID pada paket advertising | |
| RSSI saat ditemukan (dBm) | |
| Waktu scanning (detik) | |
| MAC address Node1 (jika ada) | |

**Buka abstraksinya** — sebelum lanjut, scan `NODE1_H2` pakai nRF Connect dan
amati isi paket advertising: Device Name, Service UUID, dan flags. Cocokkan tiap
field dengan baris di `src/node1/main.cpp` — baris kode mana yang menyetel
masing-masing? Ini menghubungkan API NimBLE dengan byte yang benar-benar
mengudara.

> **CHECKPOINT** — Node2 mencetak `Node1 ditemukan` dan sebuah nilai RSSI. Jika
> tidak: pastikan board `node1` menyala dan filter nama di `ScanCallbacks`
> Node2 benar.

### EXP-02 — Pembentukan Tautan

Setelah Node1 ditemukan, Node2 menjalankan alur koneksi. Verifikasi tiap tahap
di Serial Monitor kedua node.

```
Scan ──► Node1 ditemukan ──► Connect ──► Service check ──► Connected
```

**Expected output — Node1 (`NODE1_H2`)**

```
Node1 (BLE Peripheral) starting...
Advertise sebagai NODE1_H2, menunggu Node2...
Node2 terhubung (link P2P aktif)
Status: H2 <-> H2 terhubung
```

**Expected output — Node2 (`NODE2_H2`)**

```
Node2 (BLE Central) starting...
Scanning Node1...
Node1 ditemukan
Terhubung ke Node1
Koneksi berhasil
Status: H2 <-> H2 terhubung | RSSI: -57 dBm
```

> **CHECKPOINT** — Kedua node mencetak baris `Status: ... terhubung` berulang
> tiap 5 detik, dan baris Node2 menyertakan nilai RSSI.

### EXP-03 — Ketahanan Tautan

Modul ini belum mempertukarkan payload aplikasi. Uji ketahanan tautan dan amati
perilaku dua arahnya:

1. **Reset Node1** — Node2 mencetak `Terputus dari Node1` setelah supervision timeout (± 2–3 detik), lalu berhenti mencetak status. Node1 hanya mencetak banner boot-nya, bukan `Node2 terputus`, karena baru restart.
2. **Reset Node2** — Node1 mencetak `Node2 terputus, mulai advertise ulang`, lalu `Node2 terhubung` saat Node2 selesai boot & scan lagi. Ini satu-satunya skenario yang memicu `onDisconnect` di Node1.
3. **Reconnect** — biarkan Node2 jalan, restart Node1: koneksi tidak terbentuk sendiri karena Node2 hanya scan sekali (5 detik) di `setup()`. Node2 perlu di-reset. (Ini akan diperbaiki di CH-4.)
4. **Filter test** — ubah filter nama di `ScanCallbacks` Node2, amati Node2 tak lagi menemukan Node1, lalu kembalikan kode.

**Data capture**

| Parameter | Hasil |
|---|---|
| Waktu rata-rata scan sampai ditemukan (ms) | |
| Pesan saat disconnect pada Node1 | |
| Pesan saat disconnect pada Node2 | |
| Interval cetak status (ms) | |

> **CHECKPOINT** — Kamu bisa menjelaskan mengapa reset Node1 dan reset Node2
> memicu pesan yang berbeda — itu bukti tautan diamati dari dua sisi.

## 8 · Pengukuran

RSSI dibaca dari log Node2 sendiri, bukan aplikasi luar. Tambahkan cetak RSSI
koneksi pada heartbeat Node2:

```cpp
// Node2 - loop(), cetak tiap 5000 ms saat terhubung
if (pClient && pClient->isConnected()) {
  Serial.printf("Status: H2 <-> H2 terhubung | RSSI: %d dBm\n",
                pClient->getRssi());
}
```

nRF Connect boleh dipakai sebagai cross-check opsional. Gunakan referensi
berikut untuk menilai kualitas tautan:

| RSSI (dBm) | Interpretasi |
|---|---|
| > −70 | Kuat — koneksi andal |
| −70 s/d −85 | Baik — masih stabil |
| −85 s/d −95 | Marginal — mulai rawan putus |
| < −95 | Tidak reliable — koneksi sering gagal |

Ukur pada beberapa jarak (isi dari Serial Monitor Node2):

| Jarak | RSSI (dBm) | Latency koneksi (ms) | Success (ya/tidak) |
|---|---|---|---|
| 1 m | | | |
| 3 m | | | |
| 5 m | | | |
| 10 m | | | |
| 15 m | | | |

Metrik turunan: latency rata-rata scan→connected, dan ambang RSSI saat koneksi
mulai gagal.

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8, bukan berdasarkan teori saja:

1. Bagaimana pengaruh jarak terhadap nilai RSSI?
2. Pada nilai RSSI berapa koneksi mulai gagal? Bandingkan dengan tabel referensi.
3. Berapa latency rata-rata dari scan sampai connected (ms)?
4. Apakah halangan (tembok/tubuh) memengaruhi keberhasilan koneksi?
5. Apakah BLE P2P cocok untuk aplikasi yang butuh koneksi cepat dan hemat daya? Jelaskan dari datamu.

## 10 · Concept Check

1. Apa perbedaan Peripheral dan Central pada BLE?
2. Apa saja yang dimuat dalam paket advertising?
3. Apa beda active scan dan passive scan?
4. Mengapa Node1 harus advertise ulang setelah Node2 disconnect?
5. Apa fungsi Service UUID dalam koneksi BLE?

## 11 · Challenge (tugas modifikasi)

Ubah kode, jangan cuma jelaskan hasil:

- **CH-1** — Ubah interval heartbeat dari 5000 ms ke 1000 ms; amati dampaknya pada keterbacaan log dan beban.

- **CH-2** — Tambahkan LED pada Node1 yang menyala saat ada Central terhubung.

- **CH-3** — Ukur waktu dari Node2 start sampai `Koneksi berhasil` pakai `millis()`, 5 percobaan, hitung rata-rata.

- **CH-4** — Buat Node2 nge-scan ulang otomatis saat `onDisconnect` agar tautan self-healing (fondasi robustness untuk M04/M05):

  ```cpp
  // CH-4 - di ClientCallbacks::onDisconnect(), picu scan ulang
  void onDisconnect(NimBLEClient* c, int reason) override {
    Serial.println("Terputus - scan ulang...");
    NimBLEDevice::getScan()->start(5000, false);
  }
  ```

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori (ringkas)
3. Konfigurasi — `platformio.ini`, environment, UUID
4. Hasil eksperimen — log Serial Monitor kedua node (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel Bagian 8
6. Analisis + concept check
7. Challenge — termasuk CH-4
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
