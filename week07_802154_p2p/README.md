```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 07 — IEEE 802.15.4 Raw Frame (P2P)

  ESP32-H2 · 802.15.4 · RAW MAC FRAME · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 07 |
| Misi | Menyusun sendiri frame MAC 802.15.4 byte demi byte dan membuatnya terbang tanpa bantuan stack apa pun |
| Platform | ESP32-H2 (Arduino core 3.x) + API ESP-IDF `esp_ieee802154.h` |
| Durasi | 3 × 50 menit |
| Mode | P2P raw frame — PING / PONG |
| Level | Intermediate |
| Instrumen | Serial Monitor 115200 baud (2 terminal) |

## 2 · Keterkaitan Antar-Modul

Enam modul pertama berjalan di atas BLE, tempat stack menyembunyikan semua
detail radio. Modul ini **membuka lantai dasar**: tidak ada Zigbee, tidak ada
Thread, tidak ada GATT — hanya PHY/MAC 802.15.4 dan array byte yang disusun
sendiri. Setelah modul ini, setiap kali Zigbee (M08–10) atau Thread (M11–13)
tampak "langsung bekerja", praktikan mengetahui persis apa yang sebenarnya
dikerjakan protokol tersebut.

| | Cakupan |
|---|---|
| Prasyarat | M01–06 — alur build, pembacaan Serial Monitor sebagai instrumen, pengukuran loss |
| Dibangun di modul ini | Struktur MHR 802.15.4, channel & PAN ID, short address, penyusunan frame manual, callback penerimaan di konteks ISR |
| Dipakai lagi di | M08–10 (Zigbee memakai PHY/MAC yang sama) → M11–13 (Thread juga) → M16 (perbandingan overhead antar-protokol di atas radio yang identik) |

**Peta modul — titik balik seri ini**

| Modul | Lapisan yang dikerjakan |
|---|---|
| 01–06 | BLE — stack menyembunyikan radio |
| **07 (ini)** | **802.15.4 telanjang — frame disusun sendiri** |
| 08–10 | Zigbee di atas 802.15.4 — stack mengurus join, binding, routing |
| 11–13 | Thread di atas 802.15.4 — stack mengurus IPv6, mesh, dataset |

**Kontrak data lab ini.** Radio yang dipakai M07–M13 **sama persis**
(IEEE 802.15.4, channel 15). Yang berbeda hanya lapisan di atasnya. Karena itu
angka RSSI dan jangkauan yang diukur pada modul ini dapat dipakai sebagai
garis dasar (*baseline*) saat membandingkan Zigbee dan Thread di M16.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Menyusun frame MAC 802.15.4 lengkap (Len + MHR 11 byte + payload) dan menunjukkan letak tiap field pada dump heksadesimal frame yang benar-benar tertangkap.
2. Menjelaskan tiga aturan API `esp_ieee802154_*` yang wajib dipatuhi (panjang `Len` termasuk FCS, `esp_ieee802154_receive()` di `setup()`, buffer TX harus `static`) beserta gejala kegagalannya.
3. Menjalankan pertukaran PING/PONG dua arah dan menghitung packet loss tiap arah secara terpisah.
4. Membuktikan pengaruh channel dan PAN ID terhadap keterhubungan dengan mengubahnya dan mengamati akibatnya.

**Kriteria keberhasilan**

- ☐ Setiap `PING n` dibalas `PONG n` pada jarak dekat, isi payload utuh (bukan karakter acak).
- ☐ Komunikasi terbukti berhenti saat channel salah satu node dibedakan.
- ☐ Loss tiap arah terukur terpisah (PING hilang vs PONG hilang).
- ☐ Dump frame heksadesimal dianalisis dan tiap field ditunjuk.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam
(modulasi O-QPSK, CSMA-CA, superframe, beacon) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| IEEE 802.15.4 | Standar PHY/MAC nirkabel low-rate low-power; basis Zigbee dan Thread. |
| Channel | Frekuensi kerja radio (di sini 15); kedua node harus sama. |
| PAN ID | Identitas jaringan (`0xCAFE`); frame di luar PAN disaring hardware. |
| Short address | Alamat 16-bit node (`0x0001` / `0x0002`). |
| Frame / MHR | Header MAC `[Len][FC(2)][Seq(1)][DestPAN(2)][DestAddr(2)][SrcPAN(2)][SrcAddr(2)][payload]`. |
| FCS | Checksum 2 byte; **isinya** dihitung hardware, tetapi **panjangnya tetap ikut** pada byte `Len`. |
| RX when idle | Radio kembali ke RX setiap selesai TX/RX — bukan pengganti `esp_ieee802154_receive()`. |
| ISR | `esp_ieee802154_receive_done()` berjalan di konteks interupsi: salin data, set flag, jangan mencetak. |

**Tiga jebakan API `esp_ieee802154_*`.** Ketiganya nyata dan ditemukan saat
modul ini diuji di perangkat. Kode yang disediakan sudah memperhitungkannya —
yang dituntut di sini adalah kemampuan menjelaskan gejalanya:

| Aturan | Gejala bila dilanggar |
|---|---|
| `Len` = MHR + payload + 2 (FCS) | Frame ditolak / payload terpotong di penerima |
| `esp_ieee802154_receive()` wajib dipanggil di `setup()` | TX jalan, tetapi tidak ada satu pun frame diterima |
| Buffer TX harus tetap hidup sampai transmisi selesai (`static`, bukan variabel lokal) | Payload sesekali berubah jadi sampah/isi RAM lama |

Aturan ketiga paling menipu: `esp_ieee802154_transmit()` bersifat **asinkron**
dan hanya menyimpan *pointer* ke buffer. Bila buffer dideklarasikan sebagai
variabel lokal di `loop()`, isinya sudah tertimpa stack frame lain saat radio
benar-benar mengirim — sebagian frame berangkat berisi sampah, sebagian lain
kebetulan masih utuh. Itulah mengapa gejalanya *intermiten*, bukan gagal total.

**Sekuens protokol yang diamati**

```
 buildFrame()                       radio 802.15.4
 [Len][FC][Seq][DPAN][DA][SPAN][SA][payload]
        │                                   │
        ▼                                   ▼
  esp_ieee802154_transmit() ─► udara ─► esp_ieee802154_receive_done() (ISR)
                                            │
                              flag hasRx ──► loop(): cetak "RX dari ..."
```

## 5 · Topologi

```
        BOARD #1                              BOARD #2
+----------------------+                      +----------------------+
|      ESP32-H2        |  PING n  / 2 s       |      ESP32-H2        |
| Node1 (0x0001)       | ------------------>  | Node2 (0x0002)       |
| pengirim + penerima  |                      | penerima + balasan   |
| balasan PONG         | <------------------  | (PONG n)             |
+----------------------+      PONG n          +----------------------+
      env: node1                                    env: node2
        Channel 15, PAN ID 0xCAFE (kedua node sama)
```

| Node | Board | Environment | Short addr | Aksi |
|---|---|---|---|---|
| Node1 | ESP32-H2 DevKitM-1 | `node1` | `0x0001` | TX `PING n` tiap 2 s, RX balasan |
| Node2 | ESP32-H2 DevKitM-1 | `node2` | `0x0002` | RX `PING n`, TX `PONG n` |

Radio 802.15.4 dipakai **telanjang** (tanpa Zigbee/Thread) di dua
**ESP32-H2 DevKitM-1**. ESP32-C6 juga punya radio 802.15.4 dan bisa dipakai,
tetapi lab ini menyimpannya untuk peran gateway Wi-Fi di Modul 13.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 | 2 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 3 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 4 | Platform PlatformIO | pioarduino `espressif32` 55.03.311 (API `esp_ieee802154.h` bawaan) | — |

Tidak ada library eksternal — modul ini memanggil API ESP-IDF langsung.

**Radio config**

| Parameter | Nilai |
|---|---|
| Channel | 15 |
| PAN ID | `0xCAFE` |
| Short address | Node1 `0x0001`, Node2 `0x0002` |
| Interval PING | 2000 ms |

**platformio.ini — pin port agar tidak salah flash**

```ini
[env:node1]
build_src_filter = +<node1/*.cpp>
upload_port  = /dev/ttyACM0
monitor_port = /dev/ttyACM0

[env:node2]
build_src_filter = +<node2/*.cpp>
upload_port  = /dev/ttyACM1
monitor_port = /dev/ttyACM1

[env:node3]
build_src_filter = +<node3/*.cpp>
; port diisi sesuai board ketiga (opsional, untuk EXP-04-e broadcast)
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, dua port dicatat dan diisikan di atas.
- ☐ Dua ESP32-H2 terpasang dan terdeteksi.
- ☐ Environment `node1` dan `node2` dikenali PlatformIO.
- ☐ Serial Monitor 115200 baud untuk kedua node.
- ☐ Tidak ada firmware Zigbee/Thread yang masih berjalan di board yang sama (radio 802.15.4 dipakai langsung).

**Deploy**

```bash
pio device list
pio run -d week07_802154_p2p -e node1 -t upload
pio run -d week07_802154_p2p -e node2 -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Konfigurasi Radio & Anatomi Frame

Unggah kedua firmware, verifikasi konfigurasi radio pada baris pertama Serial
Monitor, lalu telusuri fungsi `buildFrame()`.

```
 frame[0]=Len | [1..2]=FC 0x8801 | [3]=Seq | [4..5]=PAN 0xCAFE
 [6..7]=DestAddr | [8..9]=PAN | [10..11]=SrcAddr | [12..]=payload

 Len = 11 (MHR) + panjang payload + 2 (FCS)
```

Contoh frame `PING 38` yang benar-benar tertangkap di udara (dump
`receive_done` pada ESP32-H2; dua byte terakhir adalah RSSI dan LQI yang
menggantikan FCS saat penerimaan):

```
14 01 88 00 FE CA 02 00 FE CA 01 00 50 49 4E 47 20 33 38 E5 0A
│  │     │  │     │     │     │     "P  I  N  G  _  3  8" │  │
│  FC    │  PAN   Dest  PAN   Src                        │  LQI
Len=0x14 Seq      0x0002      0x0001                     RSSI
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Channel | |
| PAN ID | |
| Short address Node1 | |
| Short address Node2 | |
| Ukuran MHR (byte) | |
| `Len` untuk payload 7 karakter | |

**Buka abstraksinya** — hitung sendiri nilai `Len` untuk payload `"PING 38"`
(7 karakter) dan cocokkan dengan `0x14` pada dump di atas. Lalu jawab: jika
FCS dihitung hardware, mengapa panjangnya tetap harus disertakan? Petunjuk:
`Len` adalah field PHY, dan PHY menghitung **semua** byte yang mengudara.

> **CHECKPOINT** — Kedua node mencetak baris `Channel 15, PAN 0xCAFE, short
> addr 0x000X` dengan nilai yang berbeda untuk tiap node. Jika keduanya
> mencetak alamat yang sama, berarti terjadi kesalahan flash — periksa `upload_port`.

### EXP-02 — Pertukaran PING–PONG

Node1 mengirim `PING n` tiap 2 s; Node2 menerima (callback
`esp_ieee802154_receive_done` menyalin payload dan menyetel flag, `loop()`
mencetak), lalu membalas `PONG n`; Node1 menerima balasan itu.

```
 Node1 loop (tiap 2 s)             Node2 receive_done
 TX "PING n" ─────────────────►  RX dari 0x0001: PING n
 RX dari 0x0002: PONG n  ◄──────  TX balasan "PONG n"
```

**Expected output — Node1**

```
Node1 (802.15.4 sender) starting...
Channel 15, PAN 0xCAFE, short addr 0x0001
TX ke 0x0002: PING 1
RX dari 0x0002: PONG 1
TX ke 0x0002: PING 2
RX dari 0x0002: PONG 2
```

**Expected output — Node2**

```
Node2 (802.15.4 receiver) starting...
Channel 15, PAN 0xCAFE, short addr 0x0002
RX dari 0x0001: PING 1
TX balasan ke 0x0001: PONG 1
```

> **CHECKPOINT** — Isi payload harus **terbaca sebagai teks**, bukan karakter
> acak. Jika muncul sampah seperti `���@��`, itu gejala buffer TX bukan
> `static` (lihat Bagian 4). Jika Node2 hanya mencetak baris konfigurasi dan
> tidak pernah `RX`, `esp_ieee802154_receive()` tidak dipanggil. Perbaiki dulu,
> jangan lanjut mengukur.

### EXP-03 — Isolasi Channel & RTT

1. Ubah jarak antar node secara bertahap.
2. Ubah `CHANNEL` pada **salah satu** node (perlu unggah ulang) sehingga berbeda — verifikasi komunikasi berhenti total.
3. Kembalikan ke channel yang sama, lalu ubah `PAN_ID` salah satu node — amati apakah gejalanya sama atau berbeda dengan kasus channel.
4. Ukur round-trip kasar PING→PONG dari waktu di Serial Monitor.

**Data capture**

| Parameter | Hasil |
|---|---|
| Perilaku saat channel berbeda | |
| Perilaku saat PAN ID berbeda | |
| Round-trip PING→PONG (kasar) | |
| Interval kirim PING (s) | |
| Pesan per menit yang dibalas | |

> **CHECKPOINT** — Praktikan dapat menjelaskan **perbedaan** antara gagal karena
> channel dan gagal karena PAN ID (petunjuk: yang satu radio tidak mendengar
> sama sekali, yang satu mendengar tapi menyaring). Ini penting untuk memahami
> penyaringan Zigbee/Thread di modul berikutnya.

### EXP-04 — Efek Parameter: PAN ID, Channel, Broadcast

Semua efek di bawah cukup dicapai dengan **mengubah `#define` di
`src/nodeX/main.cpp`** — tidak ada logika yang diubah. Tiap ubah parameter,
unggah ulang node yang bersangkutan.

| Uji | `node1` | `node2` | Gejala yang harus terlihat |
|---|---|---|---|
| 04-a PAN sama | `PAN_ID 0xCAFE` | `PAN_ID 0xCAFE` | PING–PONG normal (baseline) |
| 04-b PAN beda | `PAN_ID 0xCAFE` | `PAN_ID 0xBEEF` | Node1 tetap cetak `TX`, Node2 **tidak pernah** cetak `RX` — frame *heard but filtered* (disaring hardware MAC) |
| 04-c Channel sama | `CHANNEL 15` | `CHANNEL 15` | PING–PONG normal |
| 04-d Channel beda | `CHANNEL 15` | `CHANNEL 20` | Kedua node sunyi di sisi RX — radio *never heard* (tuli, tidak mendengar sama sekali) |
| 04-e Broadcast | `PEER_ADDR 0xFFFF` | `PEER_ADDR` apa pun | Node2 **dan** Node3 (bila ada) menerima frame yang sama |

Perbedaan 04-b vs 04-d adalah inti yang harus bisa dijelaskan:

- **PAN ID beda (04-b):** radio memang menerima transmisi di channel yang sama,
  tetapi MAC hardware **menyaring frame** dengan PAN ID asing sebelum sampai ke
  callback. TX di sisi lain tetap berjalan normal — komunikasi terlihat
  "searah hilang".
- **Channel beda (04-d):** radio tidak berada di frekuensi yang sama — tidak ada
  yang diterima secara fisik. Tidak ada filter yang "menolak" karena memang
  tidak ada yang masuk.

**Uji broadcast (04-e) — wajib 3 node.** Salin `src/node2` menjadi
`src/node3`, ganti `MY_ADDR` menjadi `0x0003`, tambahkan `[env:node3]` di
`platformio.ini`, lalu set `PEER_ADDR` Node1 menjadi `0xFFFF`. Amati bahwa
Node2 dan Node3 menerima frame yang sama, lalu diskusikan apa yang hilang
dibanding unicast (tidak ada ACK, tidak ada penyaringan alamat tujuan).

**Bonus investigasi — promiscuous mode.** Tambahkan
`esp_ieee802154_set_promiscuous_mode(true)` di `setup()` Node2 dan biarkan
`PAN_ID` berbeda dengan Node1. Semua frame asing kini diterima — bukti bahwa
penyaringan PAN ID sebelumnya bekerja di **hardware**, bukan di kode.

**Data capture — tabel gejala lintas kelompok**

| Uji | Konfigurasi (Node1 / Node2) | TX di Node1? | RX di Node2? | Loss (dari log) | Gejala yang diamati |
|---|---|---|---|---|---|
| 04-a | PAN sama | | | | |
| 04-b | PAN beda | | | | |
| 04-c | Channel sama | | | | |
| 04-d | Channel beda | | | | |
| 04-e | Broadcast (3 node) | | | | |

> **CHECKPOINT** — Praktikan dapat membedakan 04-b dari 04-d tanpa melihat kode,
> hanya dari pola log: 04-b ada TX tanpa RX di pasangan; 04-d kedua sisi sunyi.
> Jika sebuah kelompok di ruangan sama menyalakan radio 802.15.4 di channel
> yang sama, gejala yang muncul mirip 04-b — itu sebabnya tiap
> kelompok wajib memakai channel berbeda.

### Verifikasi hardware (log referensi)

Dijalankan pada 2 × **ESP32-H2 DevKitM-1**, capture 25 detik.

```
# Node1 (ESP32-H2, env node1)          # Node2 (ESP32-H2, env node2)
[0.201] Channel 15, PAN 0xCAFE, 0x0001 [0.201] Channel 15, PAN 0xCAFE, 0x0002
[2.204] TX ke 0x0002: PING 1           [2.205] RX dari 0x0001: PING 1
[2.204] RX dari 0x0002: PONG 1         [2.205] TX balasan ke 0x0001: PONG 1
[4.208] TX ke 0x0002: PING 2           [4.209] RX dari 0x0001: PING 2
```

| Parameter | Hasil terukur |
|---|---|
| PING dikirim / diterima Node2 | 12 / 12 |
| PONG dikirim / diterima Node1 | 12 / 12 |
| Round-trip PING→PONG | < 1 ms (di bawah resolusi cetak Serial) |

## 8 · Pengukuran

| Jarak | RSSI (dBm) | Latency RTT (kasar) | Success PONG (%) |
|---|---|---|---|
| 1 m | | | |
| 3 m | | | |
| 5 m | | | |
| 10 m | | | |
| 15 m | | | |

**Pengukuran per-node** (pengamatan 2 menit) — pisahkan dua arah:

| Node | TX | RX | Loss (%) |
|---|---|---|---|
| Node1 (0x0001) | | | |
| Node2 (0x0002) | | | |

RSSI dapat dibaca dari `frame_info->rssi` di dalam `receive_done` (salin ke
variabel, cetak di `loop()` — jangan mencetak di ISR).

**Baseline untuk M16.** Catat jarak maksimum yang masih 100 % berhasil pada
modul ini. Angka itu adalah jangkauan radio 802.15.4 **tanpa** bantuan mesh —
pembanding langsung untuk Zigbee (M10) dan Thread (M12).

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Bagaimana pengaruh jarak terhadap RSSI dan persentase PING yang dibalas PONG?
2. Pada jarak berapa komunikasi mulai gagal, dan apa indikasinya di Serial Monitor?
3. Apakah round-trip latency bertambah signifikan dengan jarak? Mengapa?
4. Berapa packet loss tiap arah (PING hilang vs PONG hilang)? Adakah asimetri, dan apa dugaan penyebabnya?
5. Mengapa channel dan PAN ID harus sama, dan apa hubungan 802.15.4 dengan Zigbee pada modul berikutnya?

## 10 · Concept Check

1. Apa fungsi field Frame Control dan sequence number pada frame 802.15.4?
2. Apa perbedaan short address dan extended address, dan kapan masing-masing dipakai?
3. Mengapa FCS tidak perlu dihitung di perangkat lunak, tetapi panjangnya tetap harus dihitung?
4. Mengapa callback penerimaan tidak boleh mencetak langsung ke Serial (konteks ISR)?
5. Apa yang terjadi bila dua node memakai PAN ID berbeda — di lapisan mana penyaringan itu terjadi?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Sequence number nyata (wajib).** Field `frame[3]` saat ini selalu `0`. Isi dengan nomor urut yang naik tiap kirim, lalu hitung packet loss dari sisi penerima:

  ```cpp
  // buildFrame(): ganti frame[3] = 0;
  static uint8_t seq = 0;
  frame[3] = seq++;
  ```
  Contoh: 60 PING dikirim, 57 PONG diterima → loss = (60−57)/60 × 100 % = 5 %.

- **CH-2 — Pengaruh ukuran payload.** Perbesar payload menjadi 40 byte teks dan bandingkan success rate terhadap payload pendek pada jarak yang sama. Jelaskan hasilnya dari sisi peluang bit error per frame.

- **CH-3 — RSSI dari frame sendiri.** Salin `frame_info->rssi` dan `frame_info->lqi` di ISR, cetak di `loop()`, lalu isi kolom RSSI Bagian 8 dari data node sendiri (bukan aplikasi luar).

- **CH-4 — Broadcast.** Ubah `DestAddr` menjadi `0xFFFF` (broadcast) dan tambahkan node ketiga. Amati apakah kedua penerima menerima frame yang sama, dan diskusikan apa yang hilang (tidak ada ACK, tidak ada penyaringan alamat).

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (802.15.4, MHR, channel, PAN ID, short address, tiga aturan API)
3. Konfigurasi — environment `node1`/`node2`, channel 15, PAN `0xCAFE`, interval 2 s
4. Hasil eksperimen — log PING–PONG kedua node + analisis dump frame heksadesimal
5. Data pengukuran — tabel jarak, tabel per-node, dan baseline jangkauan untuk M16
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-3
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
