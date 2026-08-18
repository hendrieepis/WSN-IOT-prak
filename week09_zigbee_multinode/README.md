```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
     MODUL 09 — Zigbee Multi-Node & Binding Table

  ESP32-H2 · ZIGBEE · 1 ZC + 2 ZED · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan

Modul 09 dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah. Misinya menskalakan satu coordinator ke banyak end device tanpa satu perintah pun hilang. Percobaan berjalan sebagai jaringan Zigbee multi-node dengan satu coordinator dan dua end device, diamati melalui tiga terminal Serial Monitor pada 115200 baud dengan LED RGB bawaan sebagai penanda visual.

M08 mengikat **satu** lampu ke satu switch. Di sini `allowMultipleBinding(true)` dinyalakan, dan coordinator harus menyimpan **daftar** tujuan — inilah binding table. Masalah yang muncul identik dengan M05 di dunia BLE (satu pusat, banyak sumber), tetapi jawabannya berbeda: BLE memakai objek koneksi per node, Zigbee memakai `endpoint + short address`. Perbandingan dua cara ini adalah bahan analisis modul ini.

Prasyaratnya adalah M08: join, binding, endpoint, dan penghapusan NVS sebelum flash. Yang dibangun di sini adalah pemakaian `allowMultipleBinding(true)`, iterasi binding table melalui `getBoundDevices()`, pengalamatan per endpoint, perhitungan loss per node, serta pengamatan perilaku sistem saat satu node hilang. Semuanya dipakai lagi pada M10 ketika jenis anggota jaringan bertambah dengan hadirnya router, M12 pada komunikasi many-to-many di Thread, dan M16 ketika skalabilitas menjadi kriteria pemilihan protokol.

**Peta modul blok Zigbee**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 07 | 802.15.4 telanjang |
| 08 | Jaringan Zigbee terbentuk: join, binding, cluster ON/OFF |
| **09 (ini)** | **Satu coordinator melayani banyak end device (binding table)** |
| 10 | Router menambah hop — routing multi-hop otomatis |

**Kontrak data lab ini.** Identitas node di Zigbee adalah pasangan **`endpoint` + `short address`** — bukan prefiks di dalam payload seperti M05 (`A:`, `B:`). Catat perbedaannya: identitas di sini dikelola **jaringan**, bukan aplikasi. Konsekuensinya muncul langsung di modul ini (lihat catatan `0xFFFF` di bagian Percobaan).

## 2 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Membangun jaringan Zigbee satu coordinator dengan dua end device pada satu window join, dan menampilkan isi binding table beserta endpoint tiap node.
2. Mengirim perintah ke node tertentu berdasarkan `endpoint + short address` dan membuktikan node yang dituju bereaksi.
3. Menghitung packet loss **per node** (EP 10 vs EP 11) pada jarak yang sama dan pada jarak berbeda.
4. Menjelaskan perilaku coordinator ketika satu end device menghilang, berdasarkan log — termasuk apakah perintah tetap dikirim ke node yang sudah mati.

**Kriteria keberhasilan**

- ☐ Coordinator mencetak `Total 2 device.` pada daftar binding.
- ☐ Kedua lampu merespons pada siklus yang sama.
- ☐ Loss per node terukur terpisah (EP 10 vs EP 11).
- ☐ Skenario satu node dimatikan diuji dan perilakunya tercatat.

## 3 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (tabel routing Zigbee, addressing mode APS, group addressing) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Coordinator (ZC) | Membentuk jaringan, mengelola PAN, mengizinkan join. |
| End Device (ZED) | Node akhir (child) rendah daya, tidak meneruskan trafik. |
| Join | Node bergabung ke jaringan; dibuka 180 detik setelah reboot (`setRebootOpenNetwork(180)`). |
| Binding table | Daftar tujuan yang dipegang switch; dibaca lewat `getBoundDevices()`. |
| Endpoint | Titik komunikasi aplikasi; Switch EP 5, Light1 EP 10, Light2 EP 11. |
| Cluster On/Off | Perintah standar; dipanggil per tujuan lewat `lightOn(ep, addr)`. |
| Short address | Alamat 16-bit node Zigbee, dicetak coordinator sebagai `0x%04X`. |

**Mengapa endpoint kedua lampu harus berbeda?** Karena binding table mengidentifikasi tujuan dari pasangan `endpoint + address`. Bila dua lampu memakai endpoint yang sama, entri binding menjadi ambigu dan perintah bisa menyasar. Endpoint adalah "nomor kamar" — dua kamar tidak boleh bernomor sama di satu daftar tujuan.

**Sekuens protokol yang diamati**

```
 Coordinator                        Light1 / Light2
     │  ──── open network (180 s) ──►      │
     │  ◄────────── join request ───────── │
     │  ──── assign short address ───────► │
     │  ◄────────── binding request ────── │
     │  ── lightOn/lightOff (tiap 5 s) ──► │  (dikirim per entri binding)
```

## 4 · Topologi

```
                       BOARD #1
                 +----------------+
                 |    ESP32-H2    |
                 |  Coordinator   |
                 |  (Switch, EP 5)|
                 +--------+-------+
                          |  binding
              +-----------+-----------+
              |                       |
        BOARD #2                 BOARD #3
     +--------v-------+     +---------v------+
     |    ESP32-H2    |     |    ESP32-H2    |
     |   Light #1     |     |   Light #2     |
     | ZED, EP 10     |     | ZED, EP 11     |
     +----------------+     +----------------+
       env: light1            env: light2
```

| Node | Board | Environment | Peran | Endpoint |
|---|---|---|---|---|
| Coordinator | ESP32-H2 DevKitM-1 | `coordinator` | ZC + switch (ZCZR) | EP 5 |
| Light #1 | ESP32-H2 DevKitM-1 | `light1` | ZED + light | EP 10 |
| Light #2 | ESP32-H2 DevKitM-1 | `light2` | ZED + light | EP 11 |

Ketiganya **ESP32-H2 DevKitM-1** dengan radio 802.15.4; peran ditentukan oleh `build_flags` dan tabel partisi, bukan oleh jenis board.

## 5 · Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) + library `Zigbee` bawaan.

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1, LED RGB bawaan | 3 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 3 |
| 3 | PC/Laptop | PlatformIO Core/IDE, idealnya 3 port USB bebas | 1 |
| 4 | Power bank / catu daya USB | untuk node yang dipindah saat uji jarak | 2 |
| 5 | Tabel partisi | `partitions_zczr.csv` (ZC), `partitions_ed.csv` (ED) — sudah ada di folder modul | — |

**platformio.ini — tiga environment**

```ini
[env:coordinator]
build_src_filter = +<coordinator/*.cpp>
build_flags = -DZIGBEE_MODE_ZCZR -lesp_zb_api.zczr -lzboss_stack.zczr -lzboss_port.native
board_build.partitions = partitions_zczr.csv
upload_port = /dev/ttyACM0

[env:light1]
build_src_filter = +<light1/*.cpp>
build_flags = -DZIGBEE_MODE_ED -lesp_zb_api.ed -lzboss_stack.ed -lzboss_port.native
board_build.partitions = partitions_ed.csv
upload_port = /dev/ttyACM2

[env:light2]
build_src_filter = +<light2/*.cpp>
build_flags = -DZIGBEE_MODE_ED -lesp_zb_api.ed -lzboss_stack.ed -lzboss_port.native
board_build.partitions = partitions_ed.csv
upload_port = /dev/ttyACM4
```

> **Pilih port USB-to-UART, bukan USB native.** Setiap board ESP32-H2 muncul sebagai **dua** port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan USB-Serial/JTAG bawaan chip (`303a:1001`). Proses flash pada lab ini memakai **jembatan UART**, karena jalur itulah yang tersambung ke rangkaian *auto program* (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan tombol. Pada Linux keduanya berselang-seling: port **genap** adalah UART, port **ganjil** adalah USB native. Dengan demikian satu board memakai `/dev/ttyACM0`, dua board memakai `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board memakai `/dev/ttyACM0`, `/dev/ttyACM2`, dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port ber-Hardware ID `1A86:55D3`.

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, tiga port dicatat dan diisikan di atas.
- ☐ **Hapus NVS ketiga board** (`-t erase`) sebelum flash pertama.
- ☐ Flash `coordinator` (ZCZR, `partitions_zczr.csv`).
- ☐ Flash `light1` dan `light2` (ED, `partitions_ed.csv`) **dalam window 180 detik**.
- ☐ Serial Monitor 115200 baud pada tiap board.
- ☐ Tabel pencatat jarak/RSSI/latency siap.

**Deploy**

```bash
for e in coordinator light1 light2; do pio run -d week09_zigbee_multinode -e $e -t erase; done
pio run -d week09_zigbee_multinode -e coordinator -t upload -t monitor
pio run -d week09_zigbee_multinode -e light1 -t upload      # dalam 180 s
pio run -d week09_zigbee_multinode -e light2 -t upload      # dalam 180 s
```

## 6 · Percobaan

### EXP-01 — Pembentukan Jaringan & Join Ganda

Nyalakan coordinator lebih dulu. Jaringan terbuka 180 detik setelah reboot; dalam window ini nyalakan `light1` dan `light2` agar join dan binding.

```
 [ZC reboot] ──► open network 180 s ──► [ZED1 join] [ZED2 join] ──► bound
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Waktu join Light1 (detik) | |
| Waktu join Light2 (detik) | |
| Status LED saat join | |
| Apakah keduanya masuk dalam satu window? | |

> **CHECKPOINT** — Kedua light mencetak `tergabung ke network!`. Jika hanya satu, window join sudah habis untuk yang kedua — reboot coordinator (window terbuka lagi) lalu ulangi. Jangan lanjut dengan satu node saja.

### EXP-02 — Binding Table & Kontrol Otomatis

Setelah minimal satu light ter-bind, coordinator menunggu 5 detik tambahan (agar light kedua sempat join & bind), mencetak daftar device ter-bind, lalu men-toggle semua light setiap 5 detik.

```
 [ZC] getBoundDevices() ──► endpoint + short addr
 [ZC] lightOn(ep, addr) / lightOff(ep, addr)  tiap 5 s
```

**Expected output — Coordinator**

```
Menunggu light ter-binding (join dalam 180 detik)...
Daftar device ter-bind:
 - endpoint 10, short addr 0xXXXX
 - endpoint 11, short addr 0xYYYY
Total 2 device.
-> Light 0xXXXX ON
-> Light 0xYYYY ON
-> Light 0xXXXX OFF
-> Light 0xYYYY OFF
```

> Salah satu `short addr` sering tercetak `0xFFFF`. Itu **bukan** kegagalan binding — lihat catatan pada "Verifikasi hardware" di bawah.

**Expected output — Light1 / Light2**

```
Light1 tergabung ke network!
Light1 ON
Light1 OFF
```

**Buka abstraksinya** — `getBoundDevices()` mengembalikan `std::list` berisi `zb_device_params_t`. Cetak **seluruh** field struct itu (bukan hanya endpoint dan short address) dan cocokkan dengan alamat IEEE (MAC 64-bit) tiap board yang diperoleh dari `esptool chip_id`. Jawab: entri mana yang benar-benar unik dan stabil — short address atau alamat IEEE?

> **CHECKPOINT** — Baris `Total 2 device.` muncul, dan setelah itu ada **dua** baris `-> Light 0x....` untuk tiap siklus ON dan tiap siklus OFF. Jika hanya satu baris per siklus, binding kedua gagal.

### EXP-03 — Jarak & Kehilangan Node

1. Letakkan Light2 pada jarak bertambah (1 → 3 → 5 → 10 m) dari coordinator; amati apakah perintah tetap diterima sementara Light1 tetap dekat.
2. Matikan (cabut daya) Light1 saat sistem berjalan; amati apakah coordinator **masih mencetak** `-> Light 0xXXXX ON` untuk node yang sudah mati.
3. Nyalakan kembali Light1 setelah window 180 detik berlalu; catat apakah dapat kembali sendiri dan apa yang perlu dilakukan.

**Data capture**

| Parameter | Hasil |
|---|---|
| Success Light2 pada 10 m | |
| Apakah loss Light1 terpengaruh oleh Light2 yang jauh? | |
| Perilaku coordinator saat Light1 mati | |
| Light1 kembali otomatis? (ya/tidak) + alasan | |

> **CHECKPOINT** — Praktikan dapat menjelaskan mengapa coordinator tetap mengirim perintah ke node yang sudah mati (petunjuk: binding table adalah daftar statis, bukan daftar node yang sedang hidup). Ini temuan penting untuk desain sistem nyata.

### Verifikasi hardware (log referensi)

Dijalankan pada 3 × **ESP32-H2 DevKitM-1** (flash di-erase lebih dulu), capture 70 detik.

```
# Coordinator (ESP32-H2, ZCZR)
[0.401] Menunggu light ter-binding (join dalam 180 detik)...
[5.409] Daftar device ter-bind:
[5.409]  - endpoint 10, short addr 0xFFFF
[5.409]  - endpoint 11, short addr 0x1DA3
[5.409] Total 2 device.
[5.409] -> Light 0xFFFF ON
[5.409] -> Light 0x1DA3 ON

# Light1 (ESP32-H2, ED)            # Light2 (ESP32-H2, ED)
[0.602] Light1 tergabung ...       [3.208] Light2 tergabung ...
[5.411] Light1 ON                  [5.411] Light2 ON
[10.421] Light1 OFF                [10.419] Light2 OFF
```

| Parameter | Hasil terukur |
|---|---|
| Device ter-bind terdeteksi | 2 (EP 10 dan EP 11) |
| Perintah dikirim per light | 14 |
| Aksi terjadi di Light1 / Light2 | 14 / 14 (0 % loss) |
| Waktu join Light1 / Light2 | 0,6 s / 3,2 s |

> **Short addr `0xFFFF` itu normal.** Entri binding yang dibuat lewat alamat IEEE (bukan alamat pendek) disimpan library dengan `short_addr = 0xFFFF`. `lightOn(ep, 0xFFFF)` tetap sampai ke node yang benar — buktinya Light1 tetap menyala. Yang perlu dicatat pada laporan adalah jumlah device ter-bind dan keberhasilan aksinya, bukan nilai alamatnya.

## 7 · Pengukuran

**Tabel jarak** (geser Light2, Light1 tetap di 1 m; amati LED + Serial Monitor):

| Jarak Light2 | RSSI | Latency | Success Light2 | Success Light1 |
|---|---|---|---|---|
| 1 m | | | … / 10 | … / 10 |
| 3 m | | | … / 10 | … / 10 |
| 5 m | | | … / 10 | … / 10 |
| 10 m | | | … / 10 | … / 10 |
| 15 m | | | … / 10 | … / 10 |

**Tabel per-node** (jarak tetap 3 m, amati 20 perintah):

| Node | RSSI | Paket diterima | Loss (%) |
|---|---|---|---|
| Light1 (EP 10) | | … / 20 | |
| Light2 (EP 11) | | … / 20 | |

**Bandingkan dengan M05.** Isi tabel berikut memakai data BLE multi-node:

| Aspek | BLE bintang (M05) | Zigbee multi-node (M09) |
|---|---|---|
| Cara pusat membedakan node | | |
| Loss node dekat saat node lain jauh | | |
| Perilaku saat satu node mati | | |
| Batas jumlah node (perkiraan + alasan) | | |

## 8 · Analisis

Jawab berdasarkan tabel bagian Pengukuran:

1. Berapa waktu rata-rata proses join dari menyala hingga pesan `tergabung ke network`?
2. Apakah kedua light menerima perintah ON/OFF pada siklus yang sama? Buktikan dari urutan baris log coordinator.
3. Bagaimana pengaruh jarak terhadap success rate perintah ON/OFF, dan apakah node yang dekat ikut terdampak?
4. Apa yang terjadi di coordinator ketika salah satu light dimatikan? Masihkah perintah dikirim ke node itu, dan apa implikasinya untuk sistem nyata?
5. Mengapa endpoint light1 dan light2 harus berbeda (10 vs 11)? Apa yang akan terjadi jika sama?

## 9 · Concept Check

1. Apa fungsi `allowMultipleBinding(true)` pada switch coordinator?
2. Apa yang dimaksud window join 180 detik pada `setRebootOpenNetwork(180)`, dan mengapa tidak dibuka selamanya?
3. Jelaskan perbedaan peran ZC dan ZED dalam topologi multi-node ini.
4. Bagaimana coordinator mengidentifikasi setiap light secara unik (endpoint + short address)?
5. Apa keuntungan multi-binding dibanding broadcast ke semua node?

## 10 · Challenge (tugas modifikasi)

- **CH-1 — Node ketiga.** Tambahkan **light3** (endpoint 12): salin `src/light2`, ubah `ZigbeeLight(11)` → `ZigbeeLight(12)` dan teks `Light2` → `Light3`, tambahkan env `light3` di `platformio.ini`. Amati `Total 3 device.` pada coordinator dan periksa apakah interval siklus bergeser.

- **CH-2 — Loss per node otomatis.** Catat jumlah perintah TX (`-> Light 0xXXXX ON/OFF`) vs jumlah `LightX ON/OFF` yang diterima tiap node selama 2 menit. Contoh: TX = 24, RX = 22 → loss = (24−22)/24 × 100 % = 8,33 %. Sajikan terpisah per endpoint.

- **CH-3 — Kontrol selektif.** Ubah coordinator agar menyalakan Light1 dan mematikan Light2 pada saat yang sama (bukan toggle serentak). Ini membuktikan perintah benar-benar dialamatkan per node, bukan disiarkan.

- **CH-4 — Deteksi node hilang.** Tambahkan mekanisme di coordinator untuk menandai node yang tidak merespons (mis. hitung berapa siklus berturut-turut tanpa laporan balik dari CH-2 M08). Cetak `Node 0xXXXX tidak merespons` setelah 3 siklus.

## 11 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (Zigbee multi-node, ZC/ZED, binding table, endpoint, cluster)
3. Konfigurasi — env `coordinator`/`light1`/`light2`, endpoint 5/10/11, interval 5 detik
4. Hasil eksperimen — log join, daftar binding, log ketiga board (EXP-01…03 + checkpoint)
5. Data pengukuran — tabel jarak, tabel per-node, dan tabel perbandingan dengan M05
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
