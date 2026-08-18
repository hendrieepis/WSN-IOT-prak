```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 12 — Mesh Thread IPv6 (Many-to-Many)

   ESP32-H2 · THREAD · MESH IPv6 · Level: Advanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan

Modul 12 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut. Misinya membangun mesh IPv6 yang mengatur dirinya sendiri, lalu merusaknya dengan sengaja untuk melihat apakah ia pulih. Percobaan berjalan sebagai mesh IPv6 tiga node dengan komunikasi many-to-many melalui multicast, diamati melalui tiga terminal Serial Monitor pada 115200 baud.

M11 membuktikan dua node Thread bisa saling kirim datagram. Di sini jumlahnya tiga, dan **tidak ada peran yang ditentukan manusia** — firmware ketiga node identik kecuali `NODE_ID`. Bandingkan dengan Zigbee M10, tempat peran ZC/ZR/ZED dipilih saat kompilasi: perbedaan ini adalah salah satu argumen terkuat Thread, dan angka pemulihannya menjadi bahan M16.

Prasyaratnya ada dua: M11 untuk Active Dataset, mesh-local prefix, dan socket UDP IPv6; serta M10 untuk konsep routing multi-hop. Yang dibangun di sini adalah role election otomatis, komunikasi many-to-many melalui multicast, deteksi loss berbasis counter, serta uji kegagalan node perantara beserta pemulihannya. Semuanya dipakai lagi pada M13 ketika mesh ini disambungkan ke Wi-Fi lewat gateway, M15 pada pipeline end-to-end, dan M16 ketika keandalan mesh menjadi kriteria pemilihan protokol.

**Peta modul blok Thread**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 11 | Thread P2P: alamat IPv6, datagram UDP |
| **12 (ini)** | **Mesh many-to-many, role dipilih sendiri, self-healing** |
| 13 | Mesh Thread bertemu Wi-Fi lewat gateway ESP32-C6 |

**Kontrak data lab ini.** Payload `NODE<n>:<counter>` membawa **identitas sumber + nomor urut** sekaligus. Format ini yang membuat loss bisa dihitung tanpa alat bantu apa pun — cukup mencari lompatan angka di log. Pola yang sama dipakai di M13/M15 sebagai `suhu:XX.X,#<seq>`.

## 2 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membangun mesh Thread tiga node dengan dataset identik dan mencatat role yang dipilih stack untuk masing-masing (Leader/Router/Child).
2. Membuktikan komunikasi many-to-many: setiap node menerima pesan dari dua node lainnya, dicocokkan lewat alamat sumber dan counter.
3. Menghitung packet loss per node dari lompatan counter, dan mengukur latency 1 hop vs 2 hop pada formasi garis.
4. Mengevaluasi self-healing: mengukur berapa lama mesh pulih setelah node relayer dimatikan, dan membandingkannya dengan relay manual M06 serta Zigbee M10.

**Kriteria keberhasilan**

- ☐ Ketiga node saling menerima pesan (many-to-many).
- ☐ Role tiap node teridentifikasi dan tercatat, termasuk perubahannya setelah node dimatikan.
- ☐ Perilaku mesh saat relayer mati terdokumentasi dengan counter, bukan dengan kesan.
- ☐ Awalan Mesh-Local EID ketiga node sama.

## 3 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (MLE, Router ID assignment, partition merge, MPL) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Thread mesh | Setiap node Router dapat meneruskan paket node lain; jalur dibentuk otomatis. |
| Leader | Satu node terpilih mengelola jaringan; lainnya Router/Child (`otGetDeviceRole()`). |
| Mesh-Local EID (`fd..`) | Alamat IPv6 unik per node dalam domain mesh (`fdde:ad00:beef:0:...`). |
| Mesh-Local prefix | Prefix `/64` milik jaringan; wajib identik di ketiga node, jika tidak multicast `ff03::` tidak diteruskan. |
| Link-local (`fe80::`) | Alamat per-interface antar tetangga 1 hop. |
| Multicast `ff03::abcd` | Realm-local; paket diteruskan ke seluruh mesh, semua anggota grup menerimanya. |
| UDP port 5050 | Port aplikasi kirim/terima (`OtUdp.beginMulticast(GROUP, PORT)`). |
| Sequence/counter | Pesan `NODE<n>:<count>` sehingga paket hilang terdeteksi dari lompatan counter. |

**Dataset harus identik, termasuk prefix mesh-local.** `DataSet::initNew()` mengacak prefix mesh-local tiap board. Ketiga firmware karena itu memaksa prefix yang sama sebelum `OThread.start()`:

```cpp
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] =
    {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};   // fdde:ad00:beef::/64
otThreadSetMeshLocalPrefix(esp_openthread_get_instance(), &prefix);
```

Bila dilewatkan, node tetap attach dan `Attached as: ...` tetap tercetak, tetapi tidak ada satu pun baris `RX` — gejala yang mudah disalahartikan sebagai masalah jarak atau interferensi. Periksa awalan Mesh-Local EID: harus sama di semua node.

**Sekuens protokol yang diamati**

```
 Node1 ──TX "NODE1:1" (multicast)──► Node2, Node3
 Node2 ──TX "NODE2:1" (multicast)──► Node1, Node3   (tiap 5 detik, semua node)
 Node3 ──TX "NODE3:1" (multicast)──► Node1, Node2
```

## 4 · Topologi

```
                    BOARD #1
              +-----------------+
              |    ESP32-H2     |
              |     Node1       |<----------------+
              | (Leader/Router) |                 |
              +--------+--------+                 |
                       |                          |
          +------------+------------+             |
          |                         |             |
     BOARD #2                  BOARD #3           |
 +--------v-------+       +---------v------+      |
 |    ESP32-H2    |<----->|    ESP32-H2    |------+
 |     Node2      |  RF   |     Node3      |
 | (Router/Child) |       | (Router/Child) |
 +----------------+       +----------------+
    env: node2               env: node3
   Thread: ESP_OT_MESH, channel 15, PAN 0xABCD,
           mesh-local prefix fdde:ad00:beef::/64
```

| Node | Board | Environment | `NODE_ID` | Role Thread | Aksi |
|---|---|---|---|---|---|
| Node1 | ESP32-H2 DevKitM-1 | `node1` | 1 | Leader/Router/Child (dinamis) | TX `NODE1:<n>` multicast tiap 5 s |
| Node2 | ESP32-H2 DevKitM-1 | `node2` | 2 | Leader/Router/Child (dinamis) | TX `NODE2:<n>` multicast tiap 5 s |
| Node3 | ESP32-H2 DevKitM-1 | `node3` | 3 | Leader/Router/Child (dinamis) | TX `NODE3:<n>` multicast tiap 5 s |

Ketiganya **ESP32-H2 DevKitM-1** dengan firmware yang sama kecuali `NODE_ID`. Role Thread dipilih otomatis oleh stack dan bisa berbeda tiap kali dinyalakan — bukan ditentukan oleh nama environment.

**Formasi awal:** segitiga dengan jarak antar node ± 3 m. Formasi garis (untuk membuktikan multi-hop) dipakai di EXP-03.

## 5 · Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) + OpenThread (`OThread`, `OThreadUDP`).

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 (env `node1`, `node2`, `node3`) | 3 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 3 |
| 3 | PC/Laptop | PlatformIO Core/IDE, idealnya 3 port USB bebas | 1 |
| 4 | Power bank / catu daya USB | wajib untuk formasi garis | 3 |
| 5 | Ruang uji | area untuk segitiga ±3 m dan garis panjang | — |

**Parameter jaringan yang wajib identik di ketiga node**

| Parameter | Nilai |
|---|---|
| Network name | `ESP_OT_MESH` |
| Channel / PAN ID | 15 / `0xABCD` |
| Ext PAN ID | `DE:AD:00:BE:EF:00:CA:FE` |
| Mesh-local prefix | `fdde:ad00:beef::/64` |
| Grup multicast / port | `ff03::abcd` : 5050 |
| Interval TX | 5000 ms |

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, tiga port dicatat dan diisikan pada tiap env.
- ☐ **Hapus dataset lama** ketiga board (`-t erase`) bila pernah dipakai modul Thread lain.
- ☐ Flash environment `node1`, `node2`, dan `node3` (firmware sama, `NODE_ID` 1/2/3).
- ☐ Serial Monitor 115200 baud pada ketiga board (3 terminal).
- ☐ Dataset identik: `ESP_OT_MESH`, channel 15, PAN `0xABCD`, port 5050, prefix `fdde:ad00:beef::/64`.
- ☐ Formasi segitiga ± 3 m sudah disiapkan.

**Deploy**

```bash
for e in node1 node2 node3; do pio run -d week12_thread_mesh -e $e -t erase; done
pio run -d week12_thread_mesh -e node1 -t upload
pio run -d week12_thread_mesh -e node2 -t upload
pio run -d week12_thread_mesh -e node3 -t upload -t monitor
```

## 6 · Percobaan

### EXP-01 — Pembentukan Mesh & Pemilihan Role

Nyalakan ketiga board. Tiap node men-commit dataset (termasuk prefix mesh-local), start, menunggu attach (role ≥ Child), lalu join grup multicast. Board yang selesai boot lebih dulu umumnya terpilih menjadi Leader.

```
 [board pertama] dataset (+ ML prefix) ──► start ──► Leader
 [board kedua]   dataset (+ ML prefix) ──► start ──► attach ──► Router/Child
 [board ketiga]  dataset (+ ML prefix) ──► start ──► attach ──► Router/Child
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Role Node1 | … (Leader/Router/Child) |
| Role Node2 | … (Leader/Router/Child) |
| Role Node3 | … (Leader/Router/Child) |
| Awalan Mesh-Local EID sama di ketiga node? | … (harus `fdde:ad00:beef:0:`) |
| Waktu attach tiap node (detik) | |

**Buka abstraksinya** — matikan board yang menjadi Leader, tunggu, lalu amati role kedua node sisanya di Serial Monitor. Salah satunya akan **naik menjadi Leader** tanpa satu baris kode tambahan. Catat berapa lama peralihan itu. Bandingkan dengan M10: di Zigbee, coordinator tidak bisa digantikan — matinya ZC berarti matinya jaringan.

> **CHECKPOINT** — Ketiga node mencetak `Attached as: ...` dan awalan EID ketiganya sama. Jika ada yang berbeda, node itu berada di jaringan lain — hapus NVS-nya dan flash ulang.

### EXP-02 — Multicast Many-to-Many

Setiap 5 detik tiap node mengirim `NODEn:<counter>` ke `ff03::abcd:5050` dan menerima pesan node lain; alamat sumber mesh-local tercetak pada baris RX.

```
 [tiap node] TX multicast ──► [semua node lain] RX [fdde:ad00:beef:0:...]: NODEx:c
```

**Expected output — contoh Node1**

```
Node1 (Thread) starting...
Attached as: Leader        <- bisa Router atau Child, tergantung urutan boot
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE1:1
RX [fdde:ad00:beef:0:yyyy:...]: NODE2:1
RX [fdde:ad00:beef:0:zzzz:...]: NODE3:1
TX multicast: NODE1:2
RX [fdde:ad00:beef:0:yyyy:...]: NODE2:2
```

> **CHECKPOINT** — Di **setiap** Serial Monitor muncul baris RX dari **dua** sumber berbeda (bukan satu). Jika hanya satu, node ketiga belum masuk mesh atau prefix-nya berbeda. Cocokkan juga counter: harus berurutan tanpa lompat.

### EXP-03 — Perubahan Topologi & Kegagalan Node

1. **Formasi garis** N1 — N2 — N3 (N2 di tengah, N1 dan N3 dijauhkan sampai tidak saling terjangkau): amati apakah pesan NODE3 tetap diterima N1 (multi-hop) dengan counter berlanjut.
2. **Relayer mati** — pada formasi garis, matikan N2; amati apakah N1 dan N3 saling kehilangan paket. Catat counter terakhir yang diterima.
3. Nyalakan N2 lagi dan catat **waktu pemulihan** sampai counter kembali mengalir.
4. **Jarak** — regangkan jarak antar node dan amati kenaikan loss dari lompatan counter.

**Data capture**

| Parameter | Hasil |
|---|---|
| Counter NODE3 terakhir diterima N1 sebelum N2 mati | |
| Apakah N1↔N3 benar-benar putus saat N2 mati? | |
| Waktu pemulihan setelah N2 hidup lagi (s) | |
| Latency 1 hop vs 2 hop | |
| Role setelah N2 kembali — berubah? | |

> **CHECKPOINT** — Tersedia bukti kuantitatif untuk dua klaim terpisah: (a) pesan N3 mencapai N1 lewat N2, dan (b) mesh pulih sendiri. Klaim (a) hanya sah bila N1 dan N3 memang **tidak** saling terjangkau langsung — buktikan dulu dengan mematikan N2 dan melihat aliran berhenti.

### Verifikasi hardware (log referensi)

Dijalankan pada 3 × **ESP32-H2 DevKitM-1** (flash di-erase lebih dulu, formasi meja < 1 m), capture 50 detik.

```
# Node1 (ESP32-H2)              # Node3 (ESP32-H2)
[9.617] Attached as: Router     [7.410] Attached as: Leader
[9.817] TX multicast: NODE1:1   [7.410] TX multicast: NODE3:1
                                [9.814] RX [...:385a:...]: NODE1:1
                                [11.016] RX [...:390e:...]: NODE2:1
```

| Parameter | Hasil terukur |
|---|---|
| Role terpilih (Node1 / Node2 / Node3) | Router / Child / Leader |
| Awalan Mesh-Local EID ketiga node | `fdde:ad00:beef:0:` (identik) |
| Pesan diterima tiap node dari 2 node lain | 9 + 9, counter berurutan tanpa lompatan |
| Loss | 0 % pada jarak meja |

Karena semua node saling terjangkau langsung, hasil ini **belum** membuktikan routing multi-hop — itu tugas EXP-03 formasi garis.

## 7 · Pengukuran

**Tabel jarak** (amati RX pada node terjauh, 10 pesan sumber):

| Jarak | RSSI | Latency | Success |
|---|---|---|---|
| 1 m | | | … / 10 |
| 3 m | | | … / 10 |
| 5 m | | | … / 10 |
| 10 m | | | … / 10 |
| 15 m | | | … / 10 |

**Tabel per-node** (amati 1 menit, tiap node ± 12 TX):

| Node | RSSI | Paket diterima | Loss (%) |
|---|---|---|---|
| Node1 (dari N2 & N3) | | … / 24 | |
| Node2 (dari N1 & N3) | | … / 24 | |
| Node3 (dari N1 & N2) | | … / 24 | |

**Tabel pembanding self-healing — wajib.** Isi dari data tiga modul:

| Pendekatan | Modul | Siapa yang menentukan jalur | Pulih sendiri? | Waktu pemulihan |
|---|---|---|---|---|
| Relay manual (BLE) | M06 | kode aplikasi | | |
| Routing Zigbee | M10 | stack Zigbee | | |
| Mesh Thread | M12 | stack Thread | | |

## 8 · Analisis

Jawab berdasarkan tabel bagian Pengukuran:

1. Role apa yang dipegang tiap node setelah attach? Apakah berubah setelah node dimatikan/dinyalakan?
2. Pada formasi garis, berapa hop yang ditempuh pesan NODE3 ke NODE1, dan apa buktinya dari latency/loss?
3. Bagaimana pola loss tiap node ketika jarak diperbesar? Apakah merata atau ada node yang lebih rentan?
4. Apa yang terjadi pada komunikasi N1↔N3 ketika N2 (relayer) dimatikan? Jelaskan dari counter yang berhenti/berlanjut.
5. Bandingkan keandalan mesh ini dengan multi-node Zigbee M09/M10 dan relay manual M06, memakai tabel pembanding self-healing.

## 9 · Concept Check

1. Bagaimana Thread memilih Leader dan apa tugas Leader dalam mesh?
2. Mengapa pesan multicast `ff03::abcd` dapat diterima semua node tanpa alamat tujuan per node?
3. Apa perbedaan alamat mesh-local EID (`fd...`) dan link-local (`fe80::`) dalam forwarding mesh?
4. Apa yang membuat node Router dapat meneruskan paket sedangkan Child tidak?
5. Bagaimana format pesan `NODEn:counter` membantu deteksi paket hilang — dan apa yang tidak bisa ia deteksi?

## 10 · Challenge (tugas modifikasi)

- **CH-1 — Node keempat.** Tambah `node4`: salin `src/node3`, ubah `NODE_ID` menjadi 4, tambahkan env `node4` di `platformio.ini`. Amati total pesan RX per menit di tiap node dan periksa apakah loss naik.

- **CH-2 — Packet loss dari counter (wajib).** Hitung loss otomatis dari lompatan counter per sumber. Contoh: Node2 mengirim `NODE2:1..60`, Node1 menerima 54 → loss = (60−54)/60 × 100 % = 10 %.

- **CH-3 — Pemetaan hop.** Pindahkan Node3 sehingga harus 2 hop ke Node1; bandingkan latency 1 hop vs 2 hop dari stempel waktu TX/RX. Sajikan sebagai tabel jarak → hop → latency.

- **CH-4 — Ukur self-healing secara kuantitatif.** Matikan Leader (bukan relayer), catat berapa detik sampai ada node lain mengambil alih dan aliran pesan kembali normal. Ulangi 5 kali, laporkan rata-rata dan sebarannya.

## 11 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (mesh Thread, role election, multicast realm-local, forwarding, mesh-local prefix)
3. Konfigurasi — env `node1`–`node3`, dataset `ESP_OT_MESH`, port 5050, grup `ff03::abcd`, interval 5 s
4. Hasil eksperimen — log ketiga node, skema formasi (segitiga dan garis), hasil percobaan "buka abstraksinya"
5. Data pengukuran — tabel jarak, tabel per-node, dan tabel pembanding self-healing M06/M10/M12
6. Analisis + concept check
7. Challenge — minimal CH-2 dan CH-4
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
