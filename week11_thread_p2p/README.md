```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
       MODUL 11 — Thread: Datagram UDP di atas IPv6

  ESP32-H2 · THREAD · UDP/IPv6 · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 11 |
| Misi | Memberi tiap node alamat IPv6 sungguhan dan mengirim datagram UDP di antara keduanya |
| Platform | ESP32-H2 (Arduino core 3.x) + OpenThread (`OThread`, `OThreadUDP`) |
| Durasi | 3 × 50 menit |
| Mode | P2P-IPv6 — PING multicast / PONG unicast |
| Level | Intermediate |
| Instrumen | Serial Monitor 115200 baud (2 terminal) |

## 2 · Keterkaitan Antar-Modul

Zigbee memakai alamat 16-bit milik jaringannya sendiri; untuk keluar ke
Internet ia butuh penerjemah. Thread memakai **IPv6** — alamat yang bentuknya
sama dengan alamat Internet — di atas radio 802.15.4 yang sama persis dengan
M07–M10. Inilah alasan Thread bisa disambungkan ke Wi-Fi di M13 hampir tanpa
penerjemahan: paketnya sudah IP sejak dari node sensor.

| | Cakupan |
|---|---|
| Prasyarat | M07 — channel, PAN ID, radio 802.15.4; M08–10 — pengalaman jaringan yang mengelola dirinya sendiri |
| Dibangun di modul ini | Active Dataset Thread, mesh-local prefix & EID, role attach otomatis, socket UDP IPv6, multicast realm-local vs unicast |
| Dipakai lagi di | M12 (mesh many-to-many) → M13 (dataset yang sama dipakai gateway C6) → M15 (payload UDP ini berakhir di MQTT) → M16 (Thread jadi pembanding BLE/Zigbee) |

**Peta modul blok Thread**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 07 | 802.15.4 telanjang |
| 08–10 | Zigbee: alamat 16-bit, join/binding, mesh |
| **11 (ini)** | **Thread: tiap node punya alamat IPv6, datagram UDP** |
| 12 | Mesh Thread many-to-many, role election |
| 13 | Thread disambungkan ke Wi-Fi lewat gateway C6 |

**Kontrak data lab ini.** Grup multicast `ff03::abcd` dan port **5050**
dipakai sama persis di M11, M12, M13, dan M15. Karena itu firmware penerima
modul mana pun bisa dijadikan alat bantu diagnosis untuk modul lainnya —
teknik yang benar-benar dipakai saat menguji M13 tanpa board C6.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Menyusun Active Dataset Thread lengkap (nama, channel, PAN ID, ext PAN ID, network key, mesh-local prefix) dan menjelaskan mengapa keenam parameter harus identik di semua node.
2. Membentuk jaringan Thread dua node dan menunjukkan mesh-local EID masing-masing beserta **awalan yang sama**.
3. Mengirim datagram UDP IPv6 multicast dan membalasnya unicast, dibuktikan dari alamat sumber yang tercetak di log.
4. Mengukur latency PING→PONG dan packet loss pada minimal 4 jarak, serta menjelaskan gejala khas bila prefix mesh-local berbeda.

**Kriteria keberhasilan**

- ☐ Kedua node attach (satu Leader, satu Child) dan mencetak mesh-local EID dengan **awalan yang sama**.
- ☐ PING multicast dibalas PONG unicast secara periodik.
- ☐ Latency PING→PONG rata-rata dihitung dari ≥ 10 sampel.
- ☐ Tabel jarak–RSSI–latency–loss terisi dari pengukuran sendiri.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (MLE,
Router ID assignment, MPL forwarding, keamanan DTLS/commissioning) ada di buku
teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Thread | Protokol jaringan mesh berbasis IPv6 di atas IEEE 802.15.4. |
| Leader | Node yang mengelola router ID dan dataset jaringan; terpilih otomatis. |
| Child | Node yang attach ke parent (Leader/Router) untuk berkomunikasi. |
| Active Dataset | Parameter jaringan — nama `ESP_OT_P2P`, channel 15, PAN ID `0xABCD`, ext PAN ID `DE:AD:00:BE:EF:00:CA:FE`, network key 16 byte, **mesh-local prefix `fdde:ad00:beef::/64`**. |
| Mesh-Local prefix | Prefix `/64` milik seluruh jaringan; semua alamat mesh-local diturunkan darinya. Harus **sama persis** di setiap node. |
| Mesh-Local EID | Alamat IPv6 mesh-local tiap node (`fdde:ad00:beef:0:...`), dicetak via `getMeshLocalEid()`. |
| Link-local (`fe80::`) | Alamat per-interface untuk komunikasi 1 hop antar tetangga. |
| Multicast `ff03::abcd` | Realm-local: diteruskan ke seluruh mesh, bukan hanya tetangga langsung. |
| "ping" | Di lab ini diwakili pola PING/PONG aplikasi di atas UDP, bukan ICMPv6 echo. |

**Mengapa dataset di-commit ulang tiap boot.** `DataSet::initNew()` memanggil
`otDatasetCreateNewNetwork()`, yang **mengacak** network key, ext PAN ID, *dan*
mesh-local prefix. Kode modul ini menimpa empat field pertama dengan konstanta,
lalu memaksa prefix mesh-local lewat `otThreadSetMeshLocalPrefix()` sebelum
`OThread.start()`:

```cpp
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] =
    {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};   // fdde:ad00:beef::/64
```

Tanpa langkah itu tiap board memakai prefix acak sendiri. Gejalanya
menyesatkan: kedua node **tetap attach** (MLE hanya mencocokkan channel, PAN ID,
ext PAN ID, dan network key) dan Serial Monitor tampak normal, tetapi tidak satu
pun paket multicast `ff03::` sampai — karena penerusan multicast realm-local
terikat pada prefix mesh-local jaringan. Cirinya: dua node dengan awalan
Mesh-Local EID berbeda, misal `fdcd:8b6:7a73:...` di satu sisi dan
`fd99:6dd0:2d68:...` di sisi lain.

**Sekuens protokol yang diamati**

```
 Node2 (pengirim)                       Node1 (penjawab)
   │ ──── PING multicast ff03::abcd:5050 ────► │
   │ ◄─── PONG unicast ke mesh-local EID ───── │
```

## 5 · Topologi

```
       BOARD #1                                        BOARD #2
 +----------------+  PING (multicast ff03::abcd:5050)  +----------------+
 |    ESP32-H2    | <---------------------------------- |    ESP32-H2    |
 |     Node1      |                                     |     Node2      |
 | (penjawab)     |  PONG (unicast ke mesh-local EID)   | (pengirim)     |
 +----------------+ ---------------------------------> +----------------+
    env: node1                                             env: node2
        Thread: ESP_OT_P2P, channel 15, PAN 0xABCD,
                mesh-local prefix fdde:ad00:beef::/64
```

| Node | Board | Environment | Role Thread | Aksi |
|---|---|---|---|---|
| Node1 | ESP32-H2 DevKitM-1 | `node1` | Leader **atau** Child (dinamis) | bind multicast + unicast, balas `PONG` |
| Node2 | ESP32-H2 DevKitM-1 | `node2` | Leader **atau** Child (dinamis) | kirim `PING` multicast tiap 3 s |

Keduanya **ESP32-H2 DevKitM-1** (radio 802.15.4). ESP32-C6 baru masuk di Modul
13 saat Thread perlu disambungkan ke Wi-Fi.

> **Role Thread tidak ditentukan oleh nama environment.** Leader dipilih
> otomatis oleh stack — biasanya board yang selesai boot lebih dulu. Pada uji
> referensi, `node2` justru menjadi Leader dan `node1` menjadi Child, dan
> PING/PONG tetap berjalan normal. Yang harus sama di kedua board adalah
> **dataset**, bukan role.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 (env `node1`, penjawab PONG) | 1 |
| 2 | Board ESP32-H2 | DevKitM-1 (env `node2`, pengirim PING) | 1 |
| 3 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 4 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 5 | Power bank / catu daya USB | untuk uji jarak | 2 |

Tidak ada library eksternal — `OThread`/`OThreadUDP` bawaan Arduino core 3.x.

**Parameter jaringan yang wajib identik**

| Parameter | Nilai |
|---|---|
| Network name | `ESP_OT_P2P` |
| Channel / PAN ID | 15 / `0xABCD` |
| Ext PAN ID | `DE:AD:00:BE:EF:00:CA:FE` |
| Network key | `00 11 22 … ee ff` (16 byte) |
| Mesh-local prefix | `fdde:ad00:beef::/64` |
| Grup multicast / port | `ff03::abcd` : 5050 |

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, dua port dicatat dan diisikan pada tiap env.
- ☐ Flash environment `node1` dan `node2` (role Leader/Child dipilih otomatis oleh stack, bukan oleh nama environment).
- ☐ Mesh-local prefix di kedua firmware sama: `fdde:ad00:beef::/64`.
- ☐ **Hapus dataset lama** bila board pernah dipakai modul Thread lain: `pio run -e node1 -t erase`.
- ☐ Serial Monitor 115200 baud pada kedua board.
- ☐ Tabel pencatat jarak/RSSI/latency/loss siap.

**Deploy**

```bash
pio run -d week11_thread_p2p -e node1 -t erase
pio run -d week11_thread_p2p -e node2 -t erase
pio run -d week11_thread_p2p -e node1 -t upload
pio run -d week11_thread_p2p -e node2 -t upload -t monitor
```

## 7 · Percobaan

### EXP-01 — Pembentukan Jaringan & Attach

Nyalakan kedua board. Keduanya men-commit dataset identik (termasuk prefix
mesh-local), start Thread, dan menunggu role minimal CHILD. Board yang selesai
boot lebih dulu umumnya menjadi Leader — urutannya boleh berbeda tiap percobaan.

```
 [board A] dataset (+ ML prefix) ──► start ──► Leader
 [board B] dataset (+ ML prefix) ──► start ──► scan ──► attach ──► Child
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Role Node1 | … (Leader atau Child) |
| Role Node2 | … (Leader atau Child) |
| Awalan Mesh-Local EID sama di kedua node? | … (harus `fdde:ad00:beef:0:`) |
| Mesh-Local EID Node1 | |
| Mesh-Local EID Node2 | |
| Waktu attach tiap node (detik) | |

**Buka abstraksinya** — komentari baris `applyMeshLocalPrefix();` pada **salah
satu** node, flash ulang, dan amati: kedua node tetap mencetak `Attached as:`,
tetapi tidak ada satu pun baris `RX`. Bandingkan awalan EID keduanya —
di situlah bukti kegagalannya. Kembalikan kodenya. Percobaan ini mengajarkan
sesuatu yang jarang terlihat: **jaringan bisa "terbentuk" tetapi tidak
berfungsi**, dan log status saja tidak cukup untuk menyimpulkan keberhasilan.

> **CHECKPOINT** — Kedua node mencetak `Attached as: ...` **dan** awalan EID
> keduanya sama (`fdde:ad00:beef:0:`). Kalau awalannya berbeda, jangan lanjut —
> tidak akan ada paket yang sampai.

### EXP-02 — PING Multicast / PONG Unicast

Node1 bind grup multicast port 5050 dan juga unicast; Node2 mengirim `PING`
multicast tiap 3 detik lalu Node1 membalas `PONG` unicast.

```
 [N2] TX PING (multicast ff03::abcd:5050) ──3 s──►
      [N1] RX PING ──► TX PONG (unicast ke EID N2)
 [N2] RX PONG dari EID Node1
```

**Expected output — Node1**

```
Node1 (Thread Leader) starting...
Menunggu attach...
Attached as: Leader        <- bisa juga Child, tergantung urutan boot
Mesh-Local EID: fdde:ad00:beef:0:xxxx:xxxx:xxxx:xxxx
Mendengarkan [ff03::abcd]:5050 (dan unicast)
RX [fdde:ad00:beef:0:xxxx:...]:5050 -> 'PING'
TX PONG (unicast ke pengirim)
```

**Expected output — Node2**

```
Node2 (Thread Child) starting...
Menunggu join ke network Leader...
Attached as: Child         <- bisa juga Leader, tergantung urutan boot
Mesh-Local EID: fdde:ad00:beef:0:yyyy:...
TX PING (multicast)
RX [fdde:ad00:beef:0:xxxx:...]:5050 -> 'PONG'
```

> **CHECKPOINT** — Alamat yang tercetak pada baris `RX` di Node2 harus **sama
> persis** dengan Mesh-Local EID Node1. Kalau tidak cocok, ada node lain di
> ruangan yang ikut membalas — catat, itu temuan menarik untuk analisis.

### EXP-03 — Jarak, Kehilangan Peer, dan Latency

1. **Jarak** — geser Node2 dari 1 → 15 m; hitung jumlah PONG diterima per 10 PING pada tiap jarak.
2. **Kehilangan peer** — matikan Node1 selama 30 detik; amati Node2 tetap mencetak `TX PING (multicast)` tanpa `RX PONG`, lalu nyalakan lagi dan amati pemulihan **tanpa** intervensi manual.
3. **Latency** — ukur selisih waktu antara `TX PING` di Node2 dan `RX ... 'PONG'` pada 10 sampel, hitung rata-rata.

**Data capture**

| Parameter | Hasil |
|---|---|
| PONG diterima / 10 PING (1 m) | |
| Perilaku Node2 saat Node1 mati | |
| Waktu pemulihan setelah Node1 hidup lagi | |
| Latency rata-rata (10 sampel) | |

> **CHECKPOINT** — Setelah Node1 dinyalakan lagi, `RX PONG` kembali muncul di
> Node2 **tanpa** kamu mereset Node2. Bandingkan dengan M06 (relay BLE) yang
> tidak pulih sendiri — perbedaan ini adalah nilai jual Thread.

### Verifikasi hardware (log referensi)

Dijalankan pada 2 × **ESP32-H2 DevKitM-1** (flash di-erase lebih dulu),
capture 45 detik.

```
# Node1 (ESP32-H2, env node1)              # Node2 (ESP32-H2, env node2)
[9.416] Attached as: Child                 [7.414] Attached as: Leader
[9.416] Mesh-Local EID:                    [7.414] Mesh-Local EID:
        fdde:ad00:beef:0:9fd0:c175:...             fdde:ad00:beef:0:407e:e905:...
[9.416] Mendengarkan [ff03::abcd]:5050     [7.414] TX PING (multicast)
[10.418] RX [fdde:ad00:beef:0:407e:...]    [10.419] TX PING (multicast)
         :5050 -> 'PING'                   [10.419] RX [fdde:ad00:beef:0:9fd0:...]
[10.418] TX PONG (unicast ke pengirim)              :5050 -> 'PONG'
```

| Parameter | Hasil terukur |
|---|---|
| Waktu attach Node2 / Node1 | 7,4 s / 9,4 s sejak boot |
| Awalan Mesh-Local EID kedua node | `fdde:ad00:beef:0:` (identik — syarat wajib) |
| PING dikirim / PONG diterima | 12 / 12 (0 % loss) |
| Latency PING→PONG | < 1 ms terukur di Serial (satu hop) |

> Baris `E OT_STATE: handle_ot_role_change(105): Failed to get the active
> dataset` muncul sekali saat boot dan tidak berbahaya: role sempat berubah
> sebelum dataset selesai dibaca netif. Jaringan tetap terbentuk normal
> sesudahnya.

## 8 · Pengukuran

| Jarak | RSSI | Latency (ms) | Success |
|---|---|---|---|
| 1 m | | | … / 10 |
| 3 m | | | … / 10 |
| 5 m | | | … / 10 |
| 10 m | | | … / 10 |
| 15 m | | | … / 10 |

Success = jumlah PONG diterima dari 10 PING; latency = waktu PING→PONG (ms).

**Bandingkan dengan M07 dan M08.** Radionya sama (802.15.4 channel 15), jadi
selisih jangkauan berasal dari lapisan di atasnya:

| Protokol | Modul | Jarak 100 % berhasil | Overhead per pesan |
|---|---|---|---|
| 802.15.4 raw | M07 | | 11 byte MHR |
| Zigbee | M08 | | |
| Thread (IPv6/UDP) | M11 | | header IPv6 + UDP |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Berapa latency rata-rata round-trip PING→PONG pada jarak 1 m dan 10 m?
2. Bagaimana tren RSSI dan success rate terhadap peningkatan jarak?
3. Mengapa PING dikirim multicast sedangkan PONG unicast? Apa keuntungannya untuk jaringan berisi banyak node?
4. Apa perbedaan alamat mesh-local EID (`fd...`) dan link-local (`fe80::`) pada jaringan Thread, dan yang mana yang muncul di lognmu?
5. Apa yang terjadi di Node2 ketika Node1 dimatikan? Mengapa PING tetap terkirim, dan apa artinya bagi desain aplikasi?

## 10 · Concept Check

1. Apa itu Active Dataset dan parameter apa saja yang di-set sebelum `OThread.start()`?
2. Bagaimana sebuah node menjadi Leader pada jaringan Thread?
3. Jelaskan perbedaan alamat realm-local multicast `ff03::abcd` dengan unicast mesh-local EID.
4. Mengapa komunikasi Thread memakai IPv6 dibanding alamat 16-bit seperti Zigbee? Apa untungnya untuk Modul 13?
5. Apa fungsi `OtUdp.begin(PORT)` pada Node2 dibanding `beginMulticast()` pada Node1?

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Node ketiga.** Tambah `node3` (salin `src/node2`, tambahkan env di `platformio.ini`). Amati bahwa PONG dari Node1 tetap hanya dikirim ke pengirim aslinya, dan bandingkan EID ketiga node — awalannya harus sama, sisanya berbeda.

- **CH-2 — Packet loss (wajib).** Beri nomor urut pada PING (`PING:1`, `PING:2`, …) dan hitung loss di sisi penerima. Contoh: 60 PING dikirim, 55 PONG diterima → loss = (60−55)/60 × 100 % = 8,33 %. Pisahkan: PING yang hilang vs PONG yang hilang.

- **CH-3 — Statistik latency.** Ukur latency 30 sampel, hitung min/max/rata-rata dan simpangannya. Bandingkan dengan latency Zigbee M08 pada jarak yang sama.

- **CH-4 — Prefix salah, sengaja.** Ubah `OT_ML_PREFIX` di **satu** node saja (mis. byte kedua jadi `0xdd`), flash, dan dokumentasikan gejalanya secara lengkap: apa yang tetap normal, apa yang gagal, dan bagaimana kamu mendiagnosisnya dari log. Ini melatih membaca *kegagalan senyap*.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (Thread, Leader/Child, Active Dataset, mesh-local prefix & EID, multicast realm-local)
3. Konfigurasi — env `node1`/`node2`, dataset lengkap, port 5050, grup `ff03::abcd`, interval 3 s
4. Hasil eksperimen — log attach, EID kedua node, sesi PING–PONG, hasil percobaan "buka abstraksinya"
5. Data pengukuran — tabel Bagian 8 + tabel pembanding M07/M08/M11
6. Analisis + concept check
7. Challenge — minimal CH-2 dan CH-4
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
