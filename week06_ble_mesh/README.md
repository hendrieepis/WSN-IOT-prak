```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
        MODUL 06 — Relay Multi-Hop di atas BLE

   ESP32-H2 · BLE · RELAY A→B→C · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 06 |
| Misi | Memperluas jangkauan lewat hop: pesan dari A sampai ke C yang tak terjangkau langsung |
| Platform | ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino |
| Durasi | 3 × 50 menit |
| Mode | Relay 2 hop — A (sumber) → B (relay) → C (penerima) |
| Level | Intermediate |
| Instrumen | Serial Monitor 115200 baud (3 terminal) |

## 2 · Keterkaitan Antar-Modul

Modul 05 menambah node sebagai **cabang** — semua tetap bicara langsung ke
pusat. Modul ini memakai node ketiga sebagai **jembatan**, sehingga jangkauan
jaringan melampaui jangkauan satu radio. Konsep hop inilah yang membuat Zigbee
(M10) dan Thread (M12) disebut mesh; bedanya, di sana routing dikerjakan stack,
sedangkan di sini routing dituliskan sendiri di lapisan aplikasi — supaya
mekanismenya terlihat telanjang sebelum disembunyikan protokol.

| | Cakupan |
|---|---|
| Prasyarat | M05 — banyak koneksi, penanda sumber, pengukuran loss per node |
| Dibangun di modul ini | Node dual-role (server + client sekaligus), penerusan pesan antar-hop, pengukuran loss per hop, mode kegagalan rantai |
| Dipakai lagi di | M10 (router Zigbee melakukan hal yang sama, tapi otomatis) → M12 (mesh Thread self-healing) → M13 (gateway = hop antar-protokol) → M16 (jangkauan multi-hop jadi kriteria pemilihan protokol) |

**Peta modul blok BLE (penutup blok)**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 01 | Tautan BLE P2P terbentuk & stabil |
| 02 | Payload aplikasi mengalir dua arah |
| 03 | Characteristic mewakili state & perintah |
| 04 | Telemetry via notify |
| 05 | Satu pusat, banyak sumber (bintang) |
| **06 (ini)** | **Jangkauan diperluas lewat hop — penutup blok BLE** |
| 07 | Turun ke lapisan MAC 802.15.4 telanjang — fondasi Zigbee & Thread |

**Kontrak data lab ini.** Payload `A:n` **tidak diubah** saat melewati relay —
inilah *transparent forwarding*. Prinsip yang sama dipakai gateway di M13 dan
M15: gateway meneruskan isi apa adanya, tidak mem-parsing ulang, sehingga hop
tambahan tidak merusak data.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Mengimplementasikan node dual-role yang menjalankan GATT server dan GATT client bersamaan, dan menunjukkan bagian kode yang menangani masing-masing peran.
2. Membuktikan pesan dari A tiba utuh di C dengan mencocokkan nomor pesan pada log ketiga node.
3. Menghitung packet loss **per hop** (A→B dan B→C) dan menentukan hop mana yang menjadi penyebab kehilangan.
4. Menjelaskan mode kegagalan rantai (relay mati, penerima akhir mati) berdasarkan log, dan menyebutkan konsekuensinya bagi desain jaringan.

**Kriteria keberhasilan**

- ☐ Rantai A → B → C terbentuk; C mencetak `Pesan tiba (via A -> B -> C)`.
- ☐ Nomor pesan di A, B, dan C dapat dicocokkan satu per satu.
- ☐ Tabel loss per hop terisi dari pengukuran sendiri.
- ☐ Kedua mode kegagalan (C mati, B mati) diuji dan hasilnya dicatat.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(BLE Mesh standar/ESP-BLE-MESH, flooding vs routing, model publish-subscribe
mesh) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Hop | Satu lompatan radio dari node ke node tetangga. |
| Relay | Node yang menerima pesan lalu meneruskannya ke node berikutnya. |
| Dual role | Satu board menjalankan GATT server (untuk hop berikutnya) dan GATT client (ke hop sebelumnya) bersamaan. |
| Transparent forwarding | Isi pesan diteruskan apa adanya, tanpa diubah relay. |
| Loss per hop | Kehilangan dihitung terpisah tiap lompatan, bukan hanya ujung-ke-ujung. |
| Latency kumulatif | Waktu total A→C = latency hop 1 + waktu proses relay + latency hop 2. |

**Ini bukan BLE Mesh standar.** ESP-BLE-MESH (spesifikasi Bluetooth SIG)
memakai flooding, provisioning, dan model publish-subscribe — jalur pesan
ditentukan protokol. Di sini rantai A→B→C ditentukan **oleh kode aplikasi**.
Keterbatasannya (tidak ada penemuan rute, tidak ada self-healing, arah tunggal)
justru yang perlu dicatat, karena itulah yang dibereskan Thread di M12.

**Sekuens protokol yang diamati**

```
 A (server)          B (relay: client ke A + server untuk C)          C (client)
   "A:1" ──notify──►  onNotifyFromA() → pendingForward
                      notify ke C ──────────────────────────────────►  cetak
```

## 5 · Topologi

```
  BOARD #1                 BOARD #2                 BOARD #3
+-----------+  notify   +-----------+  notify   +-----------+
| ESP32-H2  | --------> | ESP32-H2  | --------> | ESP32-H2  |
|  Node A   |  client B |  Node B   |  client C |  Node C   |
| (sumber)  | <-------- | (relay:   | <-------- | (penerima |
| server    |  konek B  |  server + |  konek B  |  akhir)   |
+-----------+           |  client)  |           +-----------+
 MESH_NODE_A            MESH_NODE_B              MESH_NODE_C
  env: nodea             env: nodeb               env: nodec
```

| Node | Board | Environment | Peran | Aksi |
|---|---|---|---|---|
| Node A | ESP32-H2 DevKitM-1 | `nodea` | Sumber (server) | kirim `A:n` tiap 4 s saat relay terhubung |
| Node B | ESP32-H2 DevKitM-1 | `nodeb` | Relay (server + client) | terima dari A, teruskan ke C |
| Node C | ESP32-H2 DevKitM-1 | `nodec` | Penerima akhir (client) | cetak pesan yang tiba |

Ketiganya **ESP32-H2 DevKitM-1**. Relay di sini dibuat di lapisan aplikasi di
atas BLE GATT — bukan BLE Mesh standar — sehingga tidak butuh board lain.

Susun posisi **A — B — C dalam satu garis**; A dan C tidak perlu (dan sebaiknya
tidak) saling terjangkau.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 3 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 3 |
| 3 | PC/Laptop | PlatformIO Core/IDE, idealnya 3 port USB bebas | 1 |
| 4 | Library NimBLE-Arduino | `h2zero/NimBLE-Arduino@^2.2.3` via `lib_deps` | — |
| 5 | Power bank / catu daya USB | agar A dan C bisa dijauhkan dari meja | 2 (opsional) |
| 6 | Ruang uji | lorong/ruang panjang untuk formasi garis A—B—C | — |

**platformio.ini — pin port agar tidak salah flash**

```ini
[env:nodea]
build_src_filter = +<nodea/*.cpp>
upload_port  = /dev/ttyACM0
monitor_port = /dev/ttyACM0

[env:nodeb]
build_src_filter = +<nodeb/*.cpp>
upload_port  = /dev/ttyACM1
monitor_port = /dev/ttyACM1

[env:nodec]
build_src_filter = +<nodec/*.cpp>
upload_port  = /dev/ttyACM2
monitor_port = /dev/ttyACM2
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, tiga port dicatat dan diisikan di atas.
- ☐ Ketiga ESP32-H2 terpasang dan terdeteksi.
- ☐ Environment `nodea`, `nodeb`, `nodec` dikenali PlatformIO.
- ☐ Serial Monitor 115200 baud siap (3 terminal).
- ☐ Formasi garis A — B — C sudah disiapkan.

**Deploy** — urutan penting: relay dulu, baru ujung-ujungnya.

```bash
pio run -d week06_ble_mesh -e nodeb -t upload
pio run -d week06_ble_mesh -e nodea -t upload
pio run -d week06_ble_mesh -e nodec -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Menyalakan Relay (Node B)

Unggah environment `nodeb` lebih dulu, lalu verifikasi dual-role: server
(advertise `MESH_NODE_B` untuk C) sekaligus client (scan `MESH_NODE_A`).

```
        server (untuk C)         client (ke A)
   advertise MESH_NODE_B       scan MESH_NODE_A
             \                   /
              +---- Node B -----+
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Pesan awal relay (`Node B (relay) starting...`) | |
| Nama BLE relay | |
| Characteristic yang dipakai (UUID akhir) | |
| Berapa peran radio yang dijalankan Node B? | |

**Buka abstraksinya** — di `src/nodeb/main.cpp`, tunjukkan **dua blok kode
terpisah**: satu yang membuat `NimBLEServer` (untuk C) dan satu yang membuat
`NimBLEClient` (ke A). Keduanya hidup di board yang sama dengan satu radio.
Pertanyaan yang harus dijawab sebelum lanjut: saat B sedang mengirim notify
ke C, apakah B masih bisa menerima notify dari A pada saat yang sama?

> **CHECKPOINT** — Node B mencetak baris start-nya dan tidak crash. Jika board
> reboot berulang (boot loop), kemungkinan besar radio kehabisan resource —
> periksa jumlah koneksi maksimum di konfigurasi NimBLE.

### EXP-02 — Menutup Rantai (Node A & Node C)

Unggah `nodea` (server, kirim `A:n` tiap 4 s saat relay terhubung) dan `nodec`
(client yang scan `MESH_NODE_B` lalu subscribe). Amati Serial Monitor ketiga
node dan verifikasi jejak pesan per hop.

```
 A: setup ──► advertise ──► B konek ke A ──► A kirim "A:n" / 4 s
 B: onNotifyFromA() ──► pendingForward ──► notify ke C
 C: onNotifyFromB() ──► cetak "Pesan tiba (via A -> B -> C)"
```

**Expected output**

- **Node A** — `Node A (sumber pesan) starting...`, `Menunggu relay (Node B)...`, `Node B terhubung`, `Kirim ke B: A:1`, …
- **Node B** — `Node B (relay) starting...`, `Node A ditemukan`, `Terhubung ke Node A`, `Koneksi ke A berhasil`, `Node C terhubung`, `Terima dari A: A:1 (diteruskan)`, `Teruskan ke C: A:1`, …
- **Node C** — `Node C (penerima akhir) starting...`, `Scanning Node B...`, `Node B ditemukan`, `Terhubung ke Node B`, `Koneksi ke B berhasil`, `Pesan tiba (via A -> B -> C): A:1`, …

> **CHECKPOINT** — Cocokkan **nomor pesan yang sama** di tiga Serial Monitor:
> `Kirim ke B: A:5` di A, `Teruskan ke C: A:5` di B, dan
> `Pesan tiba ...: A:5` di C. Jika nomor di C tertinggal jauh atau melompat,
> hentikan dan catat — itu loss per hop yang akan diukur pada Bagian 8.

### EXP-03 — Mode Kegagalan Rantai

1. **Matikan Node C** — verifikasi B tetap menerima dari A dan tetap memanggil notify, tetapi tidak ada penerima akhir.
2. **Matikan Node B** — amati Node A berhenti mengirim (syarat `relayConnected` tidak terpenuhi lagi).
3. Ukur dan bandingkan jumlah pesan di A vs di C selama 2 menit.

**Data capture**

| Parameter | Hasil |
|---|---|
| Pesan terkirim A / 2 menit (harapan 30) | |
| Pesan tiba di C / 2 menit | |
| Perilaku saat Node C dimatikan | |
| Perilaku saat Node B dimatikan | |
| Apakah rantai pulih sendiri setelah B dinyalakan lagi? | |

> **CHECKPOINT** — Praktikan dapat menjelaskan mengapa matinya B menghentikan A
> (bukan sekadar "pesannya tidak sampai"), dengan menunjuk baris kode di
> `src/nodea/main.cpp`.

### Verifikasi hardware (log referensi)

Dijalankan pada 3 × **ESP32-H2 DevKitM-1** dalam satu garis, capture 40 detik.

```
# Node A (ESP32-H2)          # Node B (ESP32-H2, relay)        # Node C (ESP32-H2)
[0.601] Node B terhubung     [0.602] Node C terhubung          [0.602] Terhubung ke Node B
[4.210] Kirim ke B: A:1      [4.207] Terima dari A: A:1        [4.410] Pesan tiba
[8.217] Kirim ke B: A:2      [4.207] Teruskan ke C: A:1                (via A -> B -> C): A:1
```

| Parameter | Hasil terukur |
|---|---|
| Rantai A → B → C terbentuk | 1,4 s setelah boot |
| Pesan dikirim A | 9 |
| Pesan diteruskan B | 9 |
| Pesan tiba di C | 9 (0 % loss ujung-ke-ujung) |
| Latency relay (B terima → C cetak) | < 200 ms |

## 8 · Pengukuran

Geser jarak hop A–B dan B–C (ukur dari posisi Node B); catat RSSI dan success rate.

| Jarak (per hop) | RSSI (dBm) | Latency A→C (kasar) | Success (%) |
|---|---|---|---|
| 1 m | | | |
| 3 m | | | |
| 5 m | | | |
| 10 m | | | |
| 15 m | | | |

**Pengukuran per-hop** (pengamatan 2 menit) — inti modul ini:

| Hop | Pesan dikirim | Pesan diterima | Loss (%) |
|---|---|---|---|
| A → B | | | |
| B → C | | | |
| A → C (ujung-ke-ujung) | | | |

Periksa: apakah loss A→C ≈ loss A→B + loss B→C? Jelaskan jika tidak.

**Uji jangkauan (wajib)** — jauhkan A dan C sampai **tidak saling terjangkau
langsung**, buktikan dengan mematikan B (pesan berhenti), lalu nyalakan B lagi
(pesan kembali). Inilah bukti hop benar-benar menambah jangkauan.

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Apakah setiap pesan `A:n` yang dikirim Node A juga tiba di Node C? Hitung persentase kedatangan.
2. Bagaimana pengaruh jarak tiap hop terhadap RSSI dan keberhasilan relay?
3. Berapa tambahan latency karena melewati dua hop dibanding koneksi langsung satu hop (bandingkan dengan data M04)?
4. Pada hop mana loss lebih besar, dan apa penyebab yang mungkin?
5. Bandingkan relay multi-hop dengan topologi bintang M05: kapan relay lebih menguntungkan, dan apa harganya?

## 10 · Concept Check

1. Apa yang dimaksud relay pada jaringan mesh?
2. Mengapa Node B harus menjalankan peran server dan client sekaligus?
3. Apa keuntungan multi-hop dibanding komunikasi langsung dari sisi jangkauan dan daya pancar?
4. Apa keterbatasan simulasi mesh ini dibanding BLE Mesh (ESP-BLE-MESH) sebenarnya? Sebut minimal tiga.
5. Apa yang terjadi pada aliran pesan bila relay mati — dan apa yang **seharusnya** terjadi pada mesh sungguhan?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Tiga hop.** Tambahkan Node D setelah C (A → B → C → D): ubah C menjadi dual-role seperti B. Amati apakah pesan tetap utuh sampai D dan berapa tambahan latency per hop.

- **CH-2 — Loss per hop otomatis.** Beri nomor urut pada payload dan hitung loss di B dan di C secara otomatis. Contoh: B menerima 30 pesan, C hanya 27 → loss hop 2 = (30−27)/30 × 100 % = 10 %. Bandingkan dengan loss kumulatif A→D pada CH-1.

- **CH-3 — Jejak hop.** Ubah relay agar menambahkan penanda pada payload (`A:5|B`) sehingga jalur yang dilalui terbaca di penerima akhir. Diskusikan: apa yang hilang dari sifat *transparent forwarding* akibat perubahan ini?

- **CH-4 — Self-healing sederhana.** Buat Node C melakukan scan ulang otomatis saat relay hilang, dan Node A menunggu relay kembali tanpa perlu reset. Ukur waktu pemulihan rantai, 5 percobaan.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (hop, relay, dual role, transparent forwarding)
3. Konfigurasi — environment `nodea`/`nodeb`/`nodec`, UUID, interval 4 s
4. Hasil eksperimen — log serial tiga node (EXP-01…03 + checkpoint), termasuk pencocokan nomor pesan
5. Data pengukuran — tabel jarak **dan** tabel per-hop, plus hasil uji jangkauan
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
