```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 10 — Zigbee Mesh: Routing Multi-Hop

   ESP32-H2 · ZIGBEE · ZC ↔ ZR ↔ ZED · Level: Advanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan

Modul 10 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat lanjut. Misinya membuktikan router benar-benar mengangkut trafik milik node lain, sekaligus mengukur harga hop keduanya. Percobaan berjalan sebagai mesh multi-hop dari coordinator ke router lalu ke end device, diamati melalui tiga terminal Serial Monitor pada 115200 baud dengan LED RGB bawaan sebagai penanda visual.

M06 sudah memperkenalkan hop — tetapi jalurnya ditulis sendiri di dalam kode. Di sini jalur ditentukan **stack**: end device memilih parent terbaik sendiri, dan router meneruskan trafik tanpa satu baris kode penerusan pun di sketch. Membandingkan dua pendekatan ini (relay manual M06 vs routing otomatis M10) adalah inti analisis modul ini, dan bekalnya dipakai lagi saat Thread melakukan hal serupa di atas IPv6 (M12).

Prasyaratnya ada dua: M09 untuk binding table, multi-node, dan penghapusan NVS; serta M06 untuk konsep hop dan loss per hop. Yang dibangun di sini adalah peran Router (ZR), pemilihan parent secara otomatis, routing multi-hop, perbandingan latency satu hop dengan dua hop, dan pengenalan status orphan. Semuanya dipakai lagi pada M12 ketika mesh Thread menambahkan role election, M13 ketika gateway berperan sebagai tepi jaringan, dan M16 ketika jangkauan mesh menjadi kriteria pemilihan protokol.

**Peta modul blok Zigbee (penutup blok)**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 07 | 802.15.4 telanjang |
| 08 | Jaringan Zigbee terbentuk: join, binding |
| 09 | Satu coordinator, banyak end device (binding table) |
| **10 (ini)** | **Router meneruskan trafik — jangkauan melampaui satu hop** |
| 11 | Pindah ke Thread: IPv6 di atas radio 802.15.4 yang sama |

**Kontrak data lab ini.** Ukur **latency 1 hop dan 2 hop** pada modul ini. Angka itu adalah pembanding langsung untuk latency relay manual M06 dan untuk mesh Thread M12 — tiga cara berbeda menyelesaikan masalah yang sama, di radio yang sama.

## 2 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membangun jaringan Zigbee tiga peran (ZC, ZR, ZED) dan menunjukkan dari log bahwa ketiganya berada dalam satu jaringan.
2. Membuktikan end device mencapai coordinator **melalui** router pada formasi garis, dengan cara memutus jalur langsung dan mengamati akibatnya.
3. Mengukur selisih latency 1 hop (formasi dekat) dan 2 hop (formasi garis) dan menyajikannya sebagai angka.
4. Menjelaskan status *orphan* pada end device saat router dimatikan, serta apakah dan bagaimana jaringan memulihkan diri.

**Kriteria keberhasilan**

- ☐ `Total device ter-bind: 2` tercetak di coordinator.
- ☐ EndLight tetap merespons pada formasi garis (ZC jauh dari ZED).
- ☐ Selisih latency 1 hop vs 2 hop terukur dan tercatat.
- ☐ Skenario router dimatikan diuji, perilaku ZED tercatat.

## 3 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (algoritma routing AODV Zigbee, tabel routing, many-to-one routing) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Coordinator (ZC) | Membentuk jaringan, membuka window join 180 detik, sumber perintah ON/OFF. |
| Router (ZR) | Node penuh yang **meneruskan paket node lain** (`Zigbee.begin(ZIGBEE_ROUTER)`); juga punya aplikasi lampu (EP 10). |
| End Device (ZED) | Child yang bergabung lewat parent (bisa router), tidak meneruskan trafik. |
| Parent selection | ZED memilih parent dengan kualitas tautan terbaik — bisa ZC, bisa ZR. |
| Mesh | Jalur alternatif otomatis; EndLight bisa mencapai ZC lewat ZR (2 hop) atau langsung (1 hop). |
| Orphan | Status ZED yang kehilangan parent dan belum menemukan pengganti. |
| Endpoint/Cluster | EP 5 (switch), EP 10 (router light), EP 11 (ED light), semua pada cluster On/Off. |

**Router bukan sekadar "node yang juga menyala".** Perbedaan sesungguhnya: router **selalu mendengarkan** (tidak tidur) dan menyimpan tabel routing. Itulah mengapa ZR memakai firmware ZCZR (lebih besar, partisi berbeda) dan mengapa ZR tidak cocok untuk node baterai. Catat konsekuensi daya ini — ia menjadi salah satu argumen di M16.

**Sekuens protokol yang diamati**

```
 ZC ──(lightOn/lightOff)──► ZR (EP10: nyala)
                 │
                 └── relay ──► ZED (EP11: nyala)
```

## 4 · Topologi

```
     BOARD #1                  BOARD #2                   BOARD #3
 +----------------+        +------------------+        +----------------+
 |    ESP32-H2    |  RF    |     ESP32-H2     |  RF    |    ESP32-H2    |
 |  Coordinator   | <----> |  RouterLight     | <----> |   EndLight     |
 |  (Switch, EP 5)|        |  (ZR, EP 10)     |        |  (ZED, EP 11)  |
 +----------------+        +------------------+        +----------------+
   env: coordinator          env: router                 env: enddevice
        \                                                  /
         \_______________ (1 hop bila dekat) ____________/
```

| Node | Board | Environment | Peran | Endpoint |
|---|---|---|---|---|
| Coordinator | ESP32-H2 DevKitM-1 | `coordinator` | ZC + switch (ZCZR) | EP 5 |
| RouterLight | ESP32-H2 DevKitM-1 | `router` | ZR + light (ZCZR) | EP 10 |
| EndLight | ESP32-H2 DevKitM-1 | `enddevice` | ZED + light (ED) | EP 11 |

Ketiganya **ESP32-H2 DevKitM-1**. Router memakai firmware ZCZR (`partitions_zczr.csv`) sedangkan end device memakai ED (`partitions_ed.csv`) — satu-satunya perbedaan perangkat keras adalah peran yang diberikan, bukan chip.

**Rencana penempatan:** ZC — jarak — ZR — jarak — ZED, dalam satu garis. Formasi meja (semua < 1 m) hanya untuk pemanasan; ia **tidak** membuktikan multi-hop.

## 5 · Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) + library `Zigbee` bawaan.

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1, LED RGB bawaan | 3 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 3 |
| 3 | PC/Laptop | PlatformIO Core/IDE | 1 |
| 4 | Power bank / catu daya USB | wajib — ZC dan ZED harus bisa dijauhkan | 3 |
| 5 | Ruang uji | lorong / ruang panjang untuk formasi garis | — |

**platformio.ini — tiga peran, dua tabel partisi**

```ini
[env:coordinator]
build_flags = -DZIGBEE_MODE_ZCZR -lesp_zb_api.zczr -lzboss_stack.zczr -lzboss_port.native
board_build.partitions = partitions_zczr.csv

[env:router]                 ; ZR juga memakai firmware ZCZR
build_flags = -DZIGBEE_MODE_ZCZR -lesp_zb_api.zczr -lzboss_stack.zczr -lzboss_port.native
board_build.partitions = partitions_zczr.csv

[env:enddevice]
build_flags = -DZIGBEE_MODE_ED -lesp_zb_api.ed -lzboss_stack.ed -lzboss_port.native
board_build.partitions = partitions_ed.csv
```

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, tiga port dicatat dan diisikan pada tiap env.
- ☐ **Hapus NVS ketiga board** (`-t erase`) sebelum flash pertama.
- ☐ Flash `coordinator` (ZCZR), `router` (ZCZR, mulai sebagai `ZIGBEE_ROUTER`), `enddevice` (ED) — semuanya dalam window 180 detik.
- ☐ Serial Monitor 115200 baud pada ketiga board.
- ☐ Formasi penempatan (meja dulu, lalu garis) sudah direncanakan.

**Deploy** — urutan penting: ZC → ZR → ZED.

```bash
for e in coordinator router enddevice; do pio run -d week10_zigbee_mesh -e $e -t erase; done
pio run -d week10_zigbee_mesh -e coordinator -t upload -t monitor
pio run -d week10_zigbee_mesh -e router      -t upload    # dalam 180 s
pio run -d week10_zigbee_mesh -e enddevice   -t upload    # dalam 180 s
```

## 6 · Percobaan

### EXP-01 — Join Bertingkat

Nyalakan coordinator, lalu router, lalu end device (semua dalam window 180 detik). Router join langsung ke ZC; end device memilih parent terbaik.

```
 [ZC on] ──► open 180 s ──► [ZR join ke ZC] ──► [ZED join (parent = ZR/ZC)]
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Waktu join Router (detik) | |
| Waktu join End Device (detik) | |
| Total device ter-bind di ZC | |
| Role yang dicetak Router / ZED | |

> **CHECKPOINT** — Router mencetak `role=ROUTER` dan end device mencetak `role=END_DEVICE`. Jika router mencetak `END_DEVICE`, `build_flags`-nya salah — perbaiki sebelum lanjut, karena tanpa ZR tidak ada hop kedua.

### EXP-02 — Kontrol Multi-Hop

Coordinator menunggu binding (plus 8 detik tambahan), mencetak daftar device, lalu men-toggle semua device tiap 5 detik. Perintah ke EndLight diteruskan router bila ZED memilih ZR sebagai parent.

```
 [ZC] ──── ON/OFF (5 s) ───► [ZR: RouterLight ON/OFF]
                  │
                  └── relay ──► [ZED: EndLight ON/OFF]
```

**Expected output — Coordinator**

```
Menunggu router & end device ter-binding...
Total device ter-bind: 2
 - endpoint 10, short addr 0xAAAA
 - endpoint 11, short addr 0xBBBB
-> 0xAAAA ON
-> 0xBBBB ON
```

**Expected output — Router**

```
Router tergabung (role=ROUTER).
RouterLight ON
RouterLight OFF
```

**Expected output — End device**

```
End device tergabung (role=END_DEVICE).
EndLight ON
EndLight OFF
```

**Buka abstraksinya** — cari di `src/router/main.cpp` baris kode yang **meneruskan** perintah ke end device. Baris itu tidak akan ditemukan: penerusan dikerjakan stack Zigbee, bukan aplikasi. Bandingkan dengan `src/nodeb/main.cpp` di Modul 06, tempat penerusan ditulis eksplisit. Tuliskan perbandingan itu — ia adalah jawaban pertanyaan analisis nomor 5.

> **CHECKPOINT** — Dua baris `-> 0x....` muncul tiap siklus dan kedua LED berubah. Jika EndLight tidak ikut berubah padahal ter-bind, dekatkan dulu semuanya (formasi meja) sebelum mencoba formasi garis.

### EXP-03 — Varian Topologi (inti modul)

1. **Formasi garis** (ZC ← 5 m → ZR ← 5 m → ZED): EndLight menerima perintah lewat router (2 hop). Amati apakah tetap ON/OFF sinkron.
2. **Formasi dekat**: letakkan ZED bersebelahan ZC; ZED mungkin memilih ZC sebagai parent (1 hop). Bandingkan latency nyala LED.
3. **Hilangkan router**: matikan ZR pada formasi garis; amati apakah ZED menjadi *orphan*, lalu apakah dapat re-join ke ZC bila jarak masih terjangkau.
4. Nyalakan ZR kembali dan catat waktu pemulihan.

**Data capture**

| Parameter | Hasil |
|---|---|
| Latency EndLight, formasi dekat (1 hop) | |
| Latency EndLight, formasi garis (2 hop) | |
| Selisih latency 1 hop vs 2 hop | |
| Perilaku ZED saat ZR dimatikan | |
| Waktu pemulihan setelah ZR hidup lagi | |

> **CHECKPOINT** — Tersedia **dua angka latency** dari dua formasi berbeda, bukan satu. Tanpa keduanya, klaim "multi-hop berhasil" tidak bisa dibuktikan.

### Verifikasi hardware (log referensi)

Dijalankan pada 3 × **ESP32-H2 DevKitM-1** (flash di-erase lebih dulu; ketiga board berdekatan, jadi ZED kemungkinan besar memilih ZC sebagai parent — 1 hop), capture 80 detik.

```
# Coordinator (ESP32-H2, ZCZR)
[0.401] Menunggu router & end device ter-binding...
[8.415] Total device ter-bind: 2
[8.415]  - endpoint 10, short addr 0xFFFF
[8.415]  - endpoint 11, short addr 0x727D
[8.415] -> 0xFFFF ON
[8.415] -> 0x727D ON

# Router (ESP32-H2, ZR)            # End device (ESP32-H2, ZED)
[0.401] Router tergabung           [3.206] End device tergabung
        (role=ROUTER).                     (role=END_DEVICE).
[8.416] RouterLight ON             [8.415] EndLight ON
[13.425] RouterLight OFF           [13.423] EndLight OFF
```

| Parameter | Hasil terukur |
|---|---|
| Waktu join router / end device | 0,4 s / 3,2 s |
| Semua node ter-bind | 2 light (EP 10 dan EP 11) pada detik 8,4 |
| Perintah dikirim per light | 15 |
| Aksi terjadi di RouterLight / EndLight | 15 / 15 (0 % loss) |

Formasi meja (semua node < 1 m) **belum membuktikan** routing multi-hop — untuk itu jalankan EXP-03 formasi garis dan matikan jalur langsung ZC ↔ ZED.

## 7 · Pengukuran

**Tabel jarak ZC ↔ ZED** (dengan ZR di tengah):

| Jarak total | RSSI | Latency | Success |
|---|---|---|---|
| 1 m | | | … / 10 |
| 3 m | | | … / 10 |
| 5 m | | | … / 10 |
| 10 m | | | … / 10 |
| 15 m | | | … / 10 |

**Tabel per-hop / per-node** (20 perintah):

| Node/Hop | RSSI | Paket diterima | Loss (%) |
|---|---|---|---|
| Router (EP 10, hop 1) | | … / 20 | |
| EndLight (EP 11, hop 2) | | … / 20 | |

**Tabel pembanding hop — wajib.** Isi dari data sendiri:

| Cara mencapai node jauh | Modul | Latency terukur | Siapa yang menentukan jalur |
|---|---|---|---|
| Relay manual (BLE) | M06 | | kode aplikasi |
| Routing otomatis (Zigbee) | M10 | | stack Zigbee |

## 8 · Analisis

Jawab berdasarkan tabel bagian Pengukuran:

1. Berapa lama waktu join router dan end device? Apakah urutan penyalaan memengaruhi keberhasilan?
2. Berdasarkan formasi dekat vs garis, kapan end device memilih router sebagai parent? Bagaimana hal itu dibuktikan dari log?
3. Bandingkan latency nyala EndLight pada 1 hop vs 2 hop; berapa selisihnya dan apakah sebanding dengan tambahan jangkauan?
4. Apa yang terjadi pada EndLight ketika router dimatikan? Sebutkan istilah status node tersebut dan berapa lama pemulihannya.
5. Bandingkan dengan relay manual M06: apa yang **diperoleh** dari routing otomatis, dan apa yang **hilang** (kendali, keterlihatan, ukuran firmware)?

## 9 · Concept Check

1. Apa perbedaan utama mode build ZCZR vs ED (lihat `build_flags` di `platformio.ini`)?
2. Mengapa router memakai `partitions_zczr.csv` sedangkan end device `partitions_ed.csv`?
3. Bagaimana mesh Zigbee menemukan jalur baru jika salah satu router mati?
4. Jelaskan hubungan endpoint 5/10/11 dengan binding pada percobaan ini.
5. Apa konsekuensi daya dari node yang berperan sebagai router dibanding end device, dan apa artinya untuk node bertenaga baterai?

## 10 · Challenge (tugas modifikasi)

- **CH-1 — Rantai dua router.** Tambahkan **router2** (salin `src/router`, tetap `ZigbeeLight(10)` tetapi ubah model string) dan susun rantai ZC → ZR1 → ZR2 → ZED. Amati berapa hop maksimum yang masih berfungsi dan berapa tambahan latency per hop.

- **CH-2 — Packet loss per hop.** Catat TX di ZC dan RX di tiap lampu selama 3 menit. Contoh: TX = 36, RX EndLight = 33 → loss = (36−33)/36 × 100 % = 8,33 %. Sajikan terpisah untuk hop 1 dan hop 2.

- **CH-3 — Lacak parent.** Amati alamat parent end device dengan memindahkan ZED bertahap, dan simpulkan pada jarak berapa jalur mulai di-router. Sajikan sebagai tabel jarak → parent.

- **CH-4 — Uji self-healing.** Pada formasi garis, matikan ZR lalu ukur berapa lama ZED butuh untuk kembali (baik lewat ZC langsung maupun setelah ZR hidup lagi). Bandingkan dengan perilaku relay manual M06 yang tidak pulih sendiri.

## 11 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (mesh Zigbee, ZR sebagai relayer, parent selection, orphan)
3. Konfigurasi — env `coordinator`/`router`/`enddevice`, endpoint 5/10/11, interval 5 detik, window 180 s
4. Hasil eksperimen — log ketiga node + skema formasi (meja dan garis) + checkpoint
5. Data pengukuran — tabel jarak, tabel per-hop, dan tabel pembanding hop M06 vs M10
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-3
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
