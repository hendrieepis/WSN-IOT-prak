```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
   MODUL 05B — Mini Project: Smart Sensor Jendela & Pintu

  ESP32-H2 · BLE · STAR / 2 SENSOR · Level: Intermediate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Pendahuluan


Modul 05B adalah mini project lanjutan dari `week05_ble_multinode`, dirancang untuk tiga pertemuan (3 × 50 menit) pada tingkat menengah. Misinya mengubah topologi bintang M05 dari sekadar pengirim counter menjadi **sistem keamanan sederhana**: dua smart sensor bukaan yang melapor ke satu hub. Percobaan berjalan dalam topologi bintang dengan satu hub dan dua sensor, diamati melalui tiga terminal Serial Monitor pada 115200 baud dengan LED RGB onboard sebagai penanda visual.

M05 membuktikan satu central sanggup memegang dua koneksi, tetapi datanya masih counter (`A:1`, `B:1`) yang tidak berarti apa-apa. Modul ini mengganti counter itu dengan **kejadian nyata dari sensor**, dan di situlah karakter lalu lintas berubah total: dari periodik menjadi *event-driven*.

Prasyaratnya adalah M05: dua koneksi simultan dan pemisahan aliran per sumber. Yang dibangun di sini adalah pemakaian input digital sebagai sumber data, transmisi berbasis kejadian, payload berstruktur `ID:STATE:seq`, penyimpanan state ruangan di hub, serta indikator lokal dan terpusat. Semuanya dipakai lagi pada M09 ketika end device melaporkan state alih-alih counter, M14 dan M15 ketika payload sensor naik ke MQTT, dan M16 ketika perbandingan protokol memakai beban event-driven.

**Yang berubah dari M05**

| | M05 | M05B (ini) |
|---|---|---|
| Sumber data | `millis()` — timer | Tombol BOOT (GPIO9) — proximity switch simulasi |
| Pola trafik | Periodik, 2 s dan 3 s | Event-driven, hanya saat status berubah |
| Payload | `A:n` / `B:n` | `JENDELA1:OPEN:3` / `PINTU1:CLOSED:4` |
| Output di node | Serial saja | Serial + kedip LED RGB (GPIO8) |
| Peran central | Mencetak apa yang diterima | Menyimpan state ruangan + lampu status |
| Sensor hilang | Koneksi mati sampai central di-reset | Disambungkan ulang otomatis, waktu pemulihan dicetak |

**Kontrak data lab ini.** Payload berbentuk `<ID>:<STATE>:<nomor_event>`: identitas sensor, statusnya, dan nomor urut kejadian. Nomor urut inilah yang membuat *kejadian yang hilang* bisa dideteksi — pada trafik event-driven, pesan yang hilang tidak terlihat sebagai jeda seperti pada trafik periodik.

## 2 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Menggabungkan input digital (proximity switch simulasi) dan output visual (LED WS2812) dengan komunikasi BLE dalam satu firmware node.
2. Menjelaskan perbedaan trafik periodik dan event-driven, serta konsekuensinya pada deteksi packet loss.
3. Merancang payload berstruktur yang membawa identitas, status, dan nomor urut, lalu mem-parsing-nya di sisi hub.
4. Menjelaskan bahwa hub mengetahui asal pesan dari **objek koneksi**, bukan dari isi payload — dan mengapa prefiks pada payload tetap diperlukan.
5. Menganalisis keandalan sistem alarm sederhana: kejadian hilang, sensor terputus, dan state hub yang tidak lagi mencerminkan kondisi nyata.
6. Menjelaskan cara kerja sambung ulang otomatis (retry ke alamat lama → scan ulang) dan membedakan apa yang dipulihkannya (tautan) dari apa yang tidak (data yang telanjur hilang).

**Kriteria keberhasilan**

- ☐ Hub memegang dua koneksi aktif (`Semua sensor terpantau — sistem siaga`).
- ☐ Tombol BOOT di node jendela → LED node berkedip **dan** hub mencetak `[ALARM] Jendela 1 TERBUKA`.
- ☐ Tombol BOOT di node pintu → hub mencetak `[ALARM] Pintu 1 TERBUKA`, tanpa tertukar label.
- ☐ LED hub kuning saat ada sensor hilang, merah saat ada bukaan, hijau saat semua aman.
- ☐ Sensor yang dimatikan lalu dihidupkan kembali tersambung **otomatis** (`[PULIH]`), tanpa reset hub.
- ☐ Waktu pemulihan tercatat, minimal 3 percobaan.

## 3 · Dasar Teori (secukupnya)

| Istilah | Definisi kerja di lab ini |
|---|---|
| Proximity / reed switch | Sakelar yang menutup-membuka mengikuti posisi daun jendela/pintu. Di lab disimulasikan tombol BOOT. |
| Active low | Tombol BOOT tersambung ke GND lewat `Key2` dengan pull-up 10K di board: tidak ditekan = `HIGH`, ditekan = `LOW`. |
| Debounce | Kontak mekanis memantul beberapa milidetik saat ditekan; tanpa penyaringan, satu tekanan terbaca sebagai banyak kejadian. |
| Event-driven | Node hanya mengirim saat **status berubah**, bukan tiap interval tetap. Hemat energi, tetapi tiap paket jadi berharga. |
| Notify | Peripheral mendorong data ke hub setelah di-subscribe — cocok untuk alarm karena hub tidak perlu polling. |
| State di hub | Salinan kondisi lapangan yang disimpan hub. Bisa **basi** bila sebuah kejadian hilang. |
| Sambung ulang otomatis | Hub mencoba menyambung lagi tiap 3 detik ke sensor yang hilang; setelah 3 kali gagal, alamatnya dicari ulang lewat scan. |
| CCCD | Penanda "aku mau notify" di sisi sensor. Hilang saat koneksi putus (tidak ada bonding), jadi **subscribe wajib diulang** tiap kali menyambung. |

**Mengapa event-driven lebih rawan daripada periodik?** Pada M05, kehilangan satu `A:7` langsung terlihat — nomor urut melompat dan pengiriman berikutnya datang 2 detik lagi. Di sini, jika kejadian `OPEN` hilang, tidak ada pengiriman berikutnya sampai seseorang menyentuh jendela lagi. Hub akan terus menampilkan "tertutup" padahal jendela terbuka: **kegagalan yang senyap**. Itulah alasan nomor urut disertakan di payload.

**Sekuens yang diamati**

```
 Sensor Jendela            Hub (central)             Sensor Pintu
 (advertise) ────► scan 5 s ────► (temukan keduanya)
              connect ──────────► subscribe notify
 [tombol ditekan]
 LED kedip merah
 "JENDELA1:OPEN:1" ──notify──►  [ALARM] Jendela 1 TERBUKA
                                LED hub → MERAH
                                          ◄──notify── "PINTU1:OPEN:1"
 [tombol dilepas]
 LED kedip hijau
 "JENDELA1:CLOSED:2" ─notify─►  [INFO ] Jendela 1 tertutup kembali
                                LED hub tetap MERAH (pintu masih terbuka)
```

## 4 · Topologi

```
                        BOARD #1
                 +---------------------+
                 |      ESP32-H2       |
                 |     HUB_RUMAH       |
                 | central, 2 koneksi  |
                 | LED: kuning/merah/  |
                 |      hijau          |
                 +----------+----------+
                /                     \
       koneksi 1                       koneksi 2
             /                           \
     BOARD #2                             BOARD #3
  +----------+---------+      +----------+---------+
  |     ESP32-H2       |      |     ESP32-H2       |
  |  SENSOR_JENDELA1   |      |   SENSOR_PINTU1    |
  |  BOOT(GPIO9) →     |      |  BOOT(GPIO9) →     |
  |  notify + LED kedip|      |  notify + LED kedip|
  +--------------------+      +--------------------+
     env: nodea                    env: nodeb
     dipasang di jendela           dipasang di pintu
```

| Node | Environment | Nama BLE | Peran | Payload |
|---|---|---|---|---|
| Hub | `central` | `HUB_RUMAH` | BLE Central, 2 koneksi, lampu status | — |
| Sensor jendela | `nodea` | `SENSOR_JENDELA1` | Peripheral | `JENDELA1:OPEN:n` / `JENDELA1:CLOSED:n` |
| Sensor pintu | `nodeb` | `SENSOR_PINTU1` | Peripheral | `PINTU1:OPEN:n` / `PINTU1:CLOSED:n` |

## 5 · Alat yang Digunakan

Modul ini dijalankan di atas ESP32-H2 (Arduino core 3.x) + PlatformIO + NimBLE-Arduino + Adafruit NeoPixel.

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | Waveshare ESP32-H2-DEV-KIT-N4 / DevKitM-1 | 3 |
| 2 | Kabel USB data | kabel data, bukan charge-only | 3 |
| 3 | PC/Laptop | PlatformIO Core/IDE, idealnya 3 port USB bebas | 1 |
| 4 | Library | `h2zero/NimBLE-Arduino@^2.2.3`, `adafruit/Adafruit NeoPixel@^1.15.5` | — |

**Pin yang dipakai (dari skematik board, sama di ketiga node)**

| Fungsi | GPIO | Keterangan |
|---|---|---|
| Proximity switch simulasi | **GPIO9** | Tombol BOOT (`Key2`), ke GND saat ditekan, pull-up 10K di board → active low |
| Indikator sensor / status | **GPIO8** | LED RGB WS2812 (`RGB_CTRL`), 1 pixel, order byte RGB |

Tidak ada wiring tambahan — tombol dan LED sudah ada di board. Bila ingin sensor sungguhan, reed switch cukup dipasang antara GPIO9 dan GND (lihat CH-4).

> **Catatan penting** — GPIO9 juga strapping pin mode download. Menahan tombol **saat board reset** membuat board masuk mode flash, bukan menjalankan program. Tekan tombol hanya setelah firmware berjalan.

**Struktur proyek**

```
week05b_ble_multinode_project/
├── platformio.ini           ← port tiap board sudah di-pin di sini
├── monitor_serial.py        ← pemantau 3 port serial sekaligus
├── logserial.md             ← log referensi hasil uji perangkat
└── src/
    ├── central/main.cpp     ← hub: 2 koneksi, parsing event, lampu status
    ├── nodea/main.cpp       ← sensor jendela
    └── nodeb/main.cpp       ← sensor pintu
```

## 6 · Build & Flash

Flash **sensor dulu**, hub belakangan, agar saat hub melakukan scan 5 detik kedua sensor sudah mengudara.

Port tiap environment sudah di-pin di `platformio.ini`, jadi tidak perlu `--upload-port` selama urutan port pada komputer yang dipakai sama:

| Environment | Port | Board |
|---|---|---|
| `nodea` | `/dev/ttyACM0` | sensor jendela |
| `nodeb` | `/dev/ttyACM2` | sensor pintu |
| `central` | `/dev/ttyACM4` | hub |

```bash
pio run -d week05b_ble_multinode_project -e nodea   -t upload
pio run -d week05b_ble_multinode_project -e nodeb   -t upload
pio run -d week05b_ble_multinode_project -e central -t upload
```

> **Pilih port USB-to-UART, bukan USB native.** Board ESP32-H2 muncul sebagai **dua** port serial: jembatan USB-to-UART CH343 (`1a86:55d3`) dan USB-Serial/JTAG bawaan chip (`303a:1001`). Flash dilakukan lewat **jembatan UART**, karena jalur itulah yang tersambung ke rangkaian *auto program* (DTR→IO9, RTS→EN) sehingga board masuk mode download tanpa menekan tombol. Pada Linux keduanya berselang-seling: port **genap** adalah UART, port **ganjil** adalah USB native. Satu board memakai `/dev/ttyACM0`, dua board `/dev/ttyACM0` dan `/dev/ttyACM2`, tiga board `/dev/ttyACM0`, `/dev/ttyACM2`, dan `/dev/ttyACM4`. Verifikasi dengan `pio device list` dan pilih port ber-Hardware ID `1A86:55D3`.

Jika port pada komputer yang dipakai berbeda, jalankan `pio device list` lalu sesuaikan `upload_port`/`monitor_port` pada `platformio.ini` (Windows memakai `COMx`).

**Memantau satu per satu dengan picocom**

Apabila pemantauan lebih nyaman dilakukan satu terminal per board, gunakan picocom (keluar: `Ctrl-A` lalu `Ctrl-X`):

```bash
picocom /dev/ttyACM4 -b115200 --imap crcrlf,lfcrlf   # central / hub
picocom /dev/ttyACM0 -b115200                        # nodea — sensor jendela
picocom /dev/ttyACM2 -b115200                        # nodeb — sensor pintu
```

`--imap crcrlf,lfcrlf` hanya perlu di central, dan sebabnya ada di kode, bukan di kabelnya: hub mencetak lewat `Serial.printf("...\n")` yang mengirim **LF saja**, sehingga kursor turun tanpa kembali ke kolom pertama — barisnya bertingkat seperti tangga. Kedua node memakai `Serial.println()` yang mengirim CR+LF, jadi tampil rapi tanpa opsi tambahan. Menambahkan `--imap` pada node juga tidak merusak apa pun, jadi aman dipakai seragam jika lebih mudah diingat.

**Memantau ketiga board sekaligus**

Membuka tiga Serial Monitor terpisah membuat urutan kejadian antar-board sulit dibaca — tiap terminal punya timestamp sendiri. Skrip `monitor_serial.py` menggabungkan ketiganya dalam satu jendela dengan satu sumbu waktu:

```bash
python3 week05b_ble_multinode_project/monitor_serial.py
python3 week05b_ble_multinode_project/monitor_serial.py --log sesi1.txt
python3 week05b_ble_multinode_project/monitor_serial.py --port JENDELA=/dev/ttyACM6
```

Contoh tampilan — sensor dan hub berdampingan, jadi latency kejadian bisa dibaca langsung dari selisih timestamp (log hasil uji nyata ada di `logserial.md`):

```
[   0.408] HUB     | Mencari smart sensor jendela dan pintu...
[   0.809] HUB     | Jendela 1 terhubung
[   1.610] PINTU   | Hub terhubung
[   2.211] HUB     | Semua sensor terpantau - sistem siaga
[  12.480] JENDELA | Notify: JENDELA1:OPEN:1
[  12.495] HUB     | [ALARM] [ 12.480 s] Jendela 1 TERBUKA (event #1)
```

Ctrl-C menghentikannya dan mencetak ringkasan jumlah baris per board.

> **Membuka monitor me-reset ketiga board** — persis seperti `pio device monitor`. Kernel mengaktifkan DTR/RTS saat port dibuka, dan pada board ini RTS terhubung ke EN. Karena itu **jalankan monitor lebih dulu**, baru mulai percobaan; banner startup ketiga board justru ikut terekam. Jangan membukanya di tengah percobaan yang sedang berjalan.

**Pre-flight checklist**

- ☐ `pio device list` dijalankan, tiga port dicatat.
- ☐ Ketiga ESP32-H2 terpasang dan terdeteksi.
- ☐ Serial Monitor 115200 baud siap (3 terminal).
- ☐ Label fisik ditempel di board: **JENDELA** dan **PINTU** — supaya tidak tertukar saat pengujian.

## 7 · Percobaan

### EXP-01 — Sensor Bekerja Sendiri (tanpa hub)

Nyalakan **hanya** kedua node sensor. Tekan tombol BOOT pada masing-masing.

**Expected output — sensor jendela**

```
Smart sensor JENDELA 1 (peripheral) starting...
Menunggu hub... (tekan tombol BOOT = jendela dibuka)
Sensor aktif tapi hub belum tersambung: JENDELA1:OPEN:1
Sensor aktif tapi hub belum tersambung: JENDELA1:CLOSED:2
```

**Data capture**

| Parameter | Hasil |
|---|---|
| LED berkedip saat tombol ditekan? (warna) | |
| LED berkedip saat tombol dilepas? (warna) | |
| Satu tekanan → berapa baris di Serial? | |
| Apakah nomor event naik satu per perubahan? | |

> **CHECKPOINT** — Satu tekanan harus menghasilkan **tepat satu** baris `OPEN` dan satu pelepasan menghasilkan **tepat satu** `CLOSED`. Jika muncul berkali-kali, debounce gagal — periksa `DEBOUNCE_MS` di `src/nodea/main.cpp`.

### EXP-02 — Hub Memantau Dua Sensor

Nyalakan hub. Hub melakukan active scan 5 detik, menemukan kedua sensor, membuka dua koneksi, dan subscribe notify.

**Expected output — hub**

```
Hub Smart Home (BLE central) starting...
Mencari smart sensor jendela dan pintu...
Jendela 1 ditemukan (RSSI -42 dBm)
Pintu 1 ditemukan (RSSI -49 dBm)
Jendela 1 terhubung
Pintu 1 terhubung
Semua sensor terpantau - sistem siaga
[ALARM] [ 12.480 s] Jendela 1 TERBUKA (event #1)
[INFO ] [ 14.902 s] Jendela 1 tertutup kembali (event #2)
[ALARM] [ 19.115 s] Pintu 1 TERBUKA (event #1)
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Waktu scan → dua koneksi aktif (s) | |
| RSSI jendela / pintu (dBm) | |
| Label hub cocok dengan board yang ditekan? | |
| Warna LED hub saat jendela terbuka | |
| Warna LED hub saat keduanya tertutup | |
| Warna LED hub saat jendela ditutup **tapi** pintu masih terbuka | |
| Warna LED hub saat satu sensor dicabut | |

**Buka abstraksinya** — di `src/central/main.cpp`, `handleEvent()` menerima `idx` sebagai argumen pertama. Cari dari mana `idx` itu berasal (petunjuk: lihat lambda pada `pChar->subscribe(...)`). Lalu jawab: jika kedua sensor mengirim payload identik `"OPEN"` tanpa prefiks ID, apakah hub masih bisa membedakannya? Jika ya, mengapa prefiks `JENDELA1:` tetap dipakai?

> **CHECKPOINT** — Tekan tombol di board jendela, pastikan yang muncul `Jendela 1`, bukan `Pintu 1`. Jika tertukar, kedua node kemungkinan di-flash dengan environment yang sama — cek ulang `-e nodea` / `-e nodeb`.

### EXP-03 — Keandalan Sistem Alarm

Uji tiga skenario kegagalan dan catat apa yang dilihat "pemilik rumah" (yaitu: apa yang ditampilkan hub).

| # | Skenario | Langkah | Hasil di hub |
|---|---|---|---|
| 1 | Sensor mati saat tertutup | Cabut USB node pintu | |
| 2 | Jendela dibuka saat sensornya mati | Cabut USB node jendela, tekan tombolnya, pasang lagi | |
| 3 | Kejadian di luar jangkauan | Bawa node jendela ±15 m / balik dinding, tekan tombol, kembali | |

**Data capture**

| Parameter | Hasil |
|---|---|
| Pesan hub saat sensor dicabut | |
| Apakah sensor lain tetap terpantau? | |
| Waktu pemulihan (`[PULIH] ... setelah X s`) | |
| Berapa kali `Gagal terhubung` sebelum pulih? | |
| Apakah `scan ulang` sempat terpicu? | |
| Setelah skenario 2, apakah state di hub sesuai kondisi nyata? | |
| Apakah baris `[LOSS ]` pernah muncul? | |

**Expected output — hub saat sensor mati lalu hidup lagi**

```
[WARN ] Jendela 1 terputus (reason 520) - mencoba sambung ulang
Gagal terhubung ke Jendela 1
Gagal terhubung ke Jendela 1
Gagal terhubung ke Jendela 1
Jendela 1 tidak menjawab 3 kali - scan ulang
Jendela 1 ditemukan (RSSI -27 dBm)
Jendela 1 terhubung
[PULIH] Jendela 1 tersambung lagi setelah 28.3 s
Semua sensor terpantau - sistem siaga
```

**Buka abstraksinya #2** — hub menyambung ulang lewat dua jalur berbeda: mencoba **alamat lama** (cepat), dan bila gagal 3 kali, **scan ulang** untuk mencari alamat baru. Cari keduanya di `maintainLinks()`. Lalu jawab: mengapa jalur kedua diperlukan padahal alamat BLE board biasanya tidak berubah? Dan mengapa `connect()` dibatasi 4 detik, bukan 30 detik bawaan library?

> **CHECKPOINT** — Skenario 2 adalah inti modul ini. Koneksinya memang pulih sendiri (`[PULIH]`), tetapi **kejadian yang terjadi selama sensor mati tetap hilang selamanya**: hub menampilkan "aman" padahal jendela terbuka, dan tidak ada baris `[LOSS ]` karena lompatan nomor event baru ketahuan pada kejadian berikutnya. Catat berapa lama kondisi salah ini bertahan, lalu simpulkan: sambung ulang otomatis memperbaiki **tautan**, bukan **data**.

### Verifikasi build (referensi)

```
Environment    Status    Duration
central        SUCCESS   00:00:03.756     Flash 54.8%  RAM 6.8%
nodea          SUCCESS   00:00:02.581     Flash 54.1%  RAM 6.8%
nodeb          SUCCESS   00:00:02.651     Flash 54.1%  RAM 6.8%
```

## 8 · Pengukuran

**A. Latency kejadian** — dari LED node berkedip sampai baris muncul di hub. Ukur dengan merekam video kedua layar, atau bandingkan timestamp Serial node dan hub (perhatikan: tiap board punya `millis()` sendiri, jadi yang dibandingkan adalah **selisih antar-kejadian**, bukan nilai absolutnya).

| Jarak | RSSI jendela | RSSI pintu | Latency rata-rata (ms, 10 tekanan) | Kejadian hilang / 10 |
|---|---|---|---|---|
| 1 m | | | | |
| 5 m | | | | |
| 10 m | | | | |
| Balik dinding | | | | |

**B. Uji beban event-driven** — tekan tombol secepat mungkin selama 30 detik pada satu node, lalu bandingkan nomor event terakhir di node dan di hub.

| Node | Event terakhir di node | Event terakhir di hub | Kejadian hilang | Loss (%) |
|---|---|---|---|---|
| Jendela | | | | |
| Pintu | | | | |

**C. Skenario asimetris** (wajib) — jendela didekatkan, pintu dijauhkan:

| Posisi jendela | Posisi pintu | Loss jendela (%) | Loss pintu (%) | Kesimpulan |
|---|---|---|---|---|
| 1 m | 10 m | | | |

**D. Waktu pemulihan sambung ulang** — matikan satu sensor, hidupkan lagi, catat angka pada baris `[PULIH]`. Ulangi 5 kali; dua di antaranya dengan sensor dimatikan lebih dari 15 detik, supaya jalur *scan ulang* ikut teruji.

| # | Sensor | Lama dimatikan (s) | `Gagal terhubung` (kali) | Scan ulang? | Waktu pemulihan (s) |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |

Selama sensor itu mati, tekan tombol pada sensor **yang lain** dan pastikan alarmnya tetap tampil di hub — pemulihan satu tautan tidak boleh membekukan tautan lainnya.

## 9 · Analisis

1. Berapa latency dari tombol ditekan hingga alarm tampil di hub? Apakah cukup cepat untuk sistem keamanan? Bandingkan dengan waktu respons manusia.
2. Pada uji beban (B), pada laju tekanan berapa kejadian mulai hilang? Apa penyebabnya — radio, debounce, atau kecepatan `loop()`?
3. Skenario EXP-03 #2 menghasilkan state hub yang salah tanpa satu pun pesan error. Rancang mekanisme yang membuat kegagalan ini **terdeteksi** (petunjuk: apa yang dilakukan sistem alarm komersial saat sensor diam terlalu lama?).
4. Sensor ini hanya mengirim saat ada perubahan. Bandingkan konsumsi energi dan keandalannya dengan pendekatan M05 yang mengirim tiap 2 detik. Kapan masing-masing lebih tepat?
5. Dari tabel D, apa yang paling menentukan lama pemulihan — `RETRY_MS`, `CONNECT_TIMEOUT_MS`, atau lama sensor mati? Apabila pemulihan dituntut selalu di bawah 5 detik, nilai mana yang diubah dan apa konsekuensinya?
6. Untuk rumah dengan 12 jendela dan 5 pintu, apakah topologi bintang BLE ini masih layak? Apa batasannya, dan protokol mana (Zigbee/Thread, M08–M12) yang lebih cocok? Berikan alasan teknis.

## 10 · Concept Check

1. Mengapa tombol BOOT dibaca dengan `INPUT_PULLUP` dan dianggap aktif saat `LOW`?
2. Apa yang terjadi bila `DEBOUNCE_MS` diset 0? Dan bila diset 2000?
3. Mengapa LED node dikedipkan dengan `millis()` (non-blocking) dan bukan `delay(300)`? Apa yang hilang jika memakai `delay()`?
4. Dari mana hub tahu sebuah notify berasal dari sensor jendela — dari isi payload, atau dari sesuatu yang lain?
5. Nomor event (`seq`) tidak dipakai oleh logika alarm sama sekali. Mengapa tetap dikirim?
6. Mengapa `subscribe()` harus dipanggil lagi setiap kali menyambung ulang, padahal objek `NimBLEClient`-nya sama?
7. Mengapa percobaan `connect()` dijalankan dari `loop()` dan bukan langsung di dalam callback `onDisconnect()`?
8. Sensor tetap mengedipkan LED walau hub belum tersambung. Apakah itu keputusan desain yang tepat untuk sebuah sistem keamanan? Jelaskan dengan alasan.

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Sensor ketiga.** Tambahkan `nodec` sebagai `SENSOR_PINTU2` (pintu belakang). Di hub, cukup tambahkan satu baris pada array `SENSORS[]` — buktikan tidak ada perubahan lain yang diperlukan, lalu jelaskan mengapa desain berbasis array itu penting.

- **CH-2 — Heartbeat anti-kegagalan senyap.** Sambung ulang otomatis menyelamatkan tautan, tapi tidak menyelamatkan kejadian yang terjadi saat sensor mati. Buat tiap sensor mengirim status terkininya (`JENDELA1:ALIVE:OPEN`) setiap 30 detik, dan buat hub **menimpa** state-nya dengan isi heartbeat itu. Uji dengan skenario EXP-03 #2 dan tunjukkan bahwa state hub kini kembali benar setelah pemulihan.

- **CH-3 — Alarm terpusat.** Buat LED hub **berkedip** merah (bukan menyala tetap) selama masih ada bukaan, dan tambahkan hitungan berapa lama tiap bukaan terbuka (`Jendela 1 sudah terbuka 45 detik`).

- **CH-4 — Sensor sungguhan.** Ganti tombol BOOT dengan reed switch magnetik (atau sensor IR proximity) antara GPIO9 dan GND. Bandingkan perilaku bounce-nya dengan tombol dan sesuaikan `DEBOUNCE_MS`. Catat hasil pengukurannya.

- **CH-5 — Perintah balik.** Tambahkan characteristic `WRITE` pada node agar hub bisa mengirim perintah `MUTE` yang mematikan kedip LED sensor. Ini mengubah sistem dari satu arah menjadi dua arah — kaitkan dengan M03.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (event-driven vs periodik, active low, debounce, state di hub)
3. Konfigurasi — environment `central`/`nodea`/`nodeb`, UUID, pin GPIO8/GPIO9, format payload
4. Hasil eksperimen — log serial tiga perangkat (EXP-01…03 + checkpoint), foto/video LED
5. Data pengukuran — tabel A, B, dan C pada bagian Pengukuran
6. Analisis + concept check
7. Challenge — minimal CH-1 dan CH-2
8. Kesimpulan — ditulis sendiri, khususnya soal keandalan sistem alarm event-driven
