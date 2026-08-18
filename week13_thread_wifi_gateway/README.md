```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
       MODUL 13 — Gateway Thread → Wi-Fi (H2 + C6)

  ESP32-H2 + ESP32-C6 · THREAD → HTTP · Level: Advanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 13 |
| Misi | Menjembatani dua radio dalam satu perangkat dan membawa data sensor keluar ke jaringan IP |
| Platform | ESP32-H2 (node Thread) + ESP32-C6 (gateway Thread + Wi-Fi) |
| Durasi | 3 × 50 menit |
| Mode | Gateway dwi-radio |
| Level | Advanced |
| Instrumen | Serial Monitor 115200 baud (2 terminal) + kode respons HTTP |

## 2 · Keterkaitan Antar-Modul

Sampai M12 data tidak pernah keluar dari jaringan 802.15.4. Modul ini adalah **titik keluar**: ESP32-C6 menjalankan dua stack sekaligus dan meneruskan payload apa adanya ke server HTTP. Ini juga modul pertama yang benar-benar membutuhkan **dua jenis board** — sebuah batasan perangkat keras, bukan firmware.

| | Cakupan |
|---|---|
| Prasyarat | M11–12 — Active Dataset, mesh-local prefix, UDP multicast; M04/M06 — konsep transparent forwarding |
| Dibangun di modul ini | Gateway dwi-radio (Thread + Wi-Fi bersamaan), penerusan UDP → HTTP POST, partisi `huge_app.csv`, penanganan Wi-Fi putus |
| Dipakai lagi di | M14 (sisi IP diganti MQTT, tanpa Thread) → M15 (kedua sisi digabung jadi pipeline penuh) → M16 (arsitektur gateway dipakai untuk membandingkan protokol) |

**Peta modul blok integrasi**

| Modul | Fokus (yang ditumpuk di atas modul sebelumnya) |
|---|---|
| 11–12 | Thread: IPv6 dan mesh — data masih di dalam 802.15.4 |
| **13 (ini)** | **Gateway: Thread bertemu Wi-Fi, data keluar ke IP (HTTP)** |
| 14 | Sisi IP diperdalam: MQTT publish/subscribe di C6 |
| 15 | M12 + M13 + M14 digabung: sensor → Thread → C6 → MQTT → dashboard |

**Kontrak data lab ini.** Payload `suhu:XX.X` diteruskan **tanpa diubah** dari Thread ke HTTP; gateway hanya membungkusnya dalam JSON. Prinsip ini (*transparent forwarding*, sama seperti relay M06) membuat M15 bisa mengganti HTTP dengan MQTT tanpa menyentuh firmware node sensor sama sekali.

## 3 · Capaian Pembelajaran

Setelah menyelesaikan modul ini, mahasiswa mampu:

1. Mengonfigurasi satu ESP32-C6 sebagai Thread Leader **dan** Wi-Fi STA secara bersamaan, serta menunjukkan urutan inisialisasi keduanya di kode.
2. Menerima datagram UDP multicast Thread dari node ESP32-H2 di sisi gateway dan menampilkan alamat sumbernya.
3. Meneruskan payload ke server HTTP dan memverifikasi keberhasilannya dari kode respons (HTTP 200).
4. Menghitung packet loss pada dua hop terpisah — Thread (H2 → C6) dan Wi-Fi/HTTP (C6 → server) — dan menentukan hop mana yang menjadi penyebab bila ada data hilang.

**Kriteria keberhasilan**

- ☐ Pesan `suhu:XX.X` dari H2 tiba di server HTTP dengan status **HTTP 200**.
- ☐ Latency end-to-end terukur pada tiga skenario jarak.
- ☐ Packet loss Thread → gateway terhitung terpisah dari loss Wi-Fi → server.
- ☐ Perilaku saat Wi-Fi diputus diuji dan tercatat.

## 4 · Dasar Teori (secukupnya)

Teori dibatasi pada apa yang dipakai di percobaan. *Pembahasan mendalam (Thread Border Router penuh, SRP/DNS-SD, NAT64, koeksistensi radio) ada di buku teori terpisah.*

| Istilah | Definisi kerja di lab ini |
|---|---|
| Gateway | Perangkat yang menghubungkan dua jaringan berbeda protokol (Thread ↔ Wi-Fi) dan meneruskan data antar keduanya. |
| Border Router | Router tepi jaringan Thread yang menyediakan konektivitas ke jaringan IP eksternal — C6 di sini berfungsi sebagai versi sederhananya. |
| Thread Leader | Perangkat Thread yang mengelola dataset aktif jaringan. |
| UDP Multicast | Pesan dikirim ke grup IPv6 `ff03::abcd` port 5050 sehingga semua anggota grup menerimanya. |
| Wi-Fi STA | Mode station: C6 bergabung ke access point dan memperoleh alamat IP. |
| HTTP POST | Pengiriman data ke server; payload dibungkus JSON `{"sensor":"h2","data":"..."}`. |
| `huge_app.csv` | Tabel partisi besar; firmware Thread + Wi-Fi + HTTP melebihi partisi app default 1,25 MB. |

**Mengapa H2 dan C6 wajib memakai prefix mesh-local yang sama.** `DataSet::initNew()` mengacak network key, ext PAN ID, dan **prefix mesh-local** di tiap board. Kedua firmware karena itu menimpa field-field tersebut dengan konstanta dan memaksa prefix lewat `otThreadSetMeshLocalPrefix()` sebelum `OThread.start()`:

```cpp
const uint8_t OT_ML_PREFIX[OT_MESH_LOCAL_PREFIX_SIZE] =
    {0xfd, 0xde, 0xad, 0x00, 0xbe, 0xef, 0x00, 0x00};   // fdde:ad00:beef::/64
```

Tanpa itu H2 dan C6 tetap attach dan Serial Monitor keduanya tampak sehat, tetapi gateway tidak pernah mencetak satu pun baris `RX via Thread` — paket multicast `ff03::abcd` tidak diteruskan antar prefix mesh-local yang berbeda. Pemeriksaan cepat: awalan Mesh-Local EID kedua board harus sama persis.

**Sekuens protokol yang diamati**

```
[ H2 sensor ] ──(Thread UDP)──► [ C6 gateway ] ──(HTTP POST JSON)──► [ Server ]
   readSensor      OtUdp            parsePacket       HTTPClient
   "suhu:25.3"     multicast        forwardToWifi()   http.POST()
```

## 5 · Topologi

```
    BOARD #1 (H2)                        BOARD #2 (C6)
+-----------------+   Thread / 802.15.4   +------------------+     Wi-Fi / HTTP      +---------------+
|    ESP32-H2     | --------------------> |    ESP32-C6      | --------------------> | Server HTTP   |
|   DevKitM-1     |  "suhu:XX.X" ke       |   DevKitC-1      |  POST JSON            | (httpbin.org) |
|  node sensor    |  ff03::abcd:5050      | gateway Thread + |  {sensor,data}        +---------------+
|  env: h2_node   |  ch 15, PAN 0xABCD    | Wi-Fi STA        |
+-----------------+                       | env: c6_gateway  |
                                          +------------------+
   radio: 802.15.4 saja                     radio: 802.15.4 + Wi-Fi 2,4 GHz
   ML prefix fdde:ad00:beef::/64            ML prefix fdde:ad00:beef::/64
```

| Node | Board | Environment | Peran | Aksi |
|---|---|---|---|---|
| Node sensor | **ESP32-H2** DevKitM-1 | `h2_node` | Thread node (Child) | TX `suhu:XX.X` multicast tiap 3 s |
| Gateway | **ESP32-C6** DevKitC-1 | `c6_gateway` | Thread Leader + Wi-Fi STA | RX Thread → HTTP POST |

**Inilah modul pertama yang benar-benar butuh dua jenis board.** ESP32-H2 punya radio 802.15.4 tetapi **tidak punya Wi-Fi**; ESP32-C6 punya keduanya, sehingga hanya C6 yang bisa memegang kaki Thread dan kaki Wi-Fi sekaligus. Menukar peran (H2 sebagai gateway) tidak mungkin — bukan soal firmware, tetapi soal radio yang tersedia di chip. Karena itu `platformio.ini` modul ini memakai `board` berbeda per environment (`esp32-h2-devkitm-1` vs `esp32-c6-devkitc-1`), tidak seperti Modul 01–12 yang seragam ESP32-H2.

## 6 · Persiapan

**Alat & bahan**

| No | Peralatan | Spesifikasi | Jumlah |
|---|---|---|---|
| 1 | Board ESP32-H2 | DevKitM-1 — node sensor Thread | 1 |
| 2 | Board ESP32-C6 | DevKitC-1 — gateway Thread → Wi-Fi | 1 |
| 3 | Kabel USB data | kabel data, bukan charge-only | 2 |
| 4 | PC/Laptop | PlatformIO Core/IDE, 2 port USB bebas | 1 |
| 5 | Wi-Fi / hotspot | 2,4 GHz, ada akses internet (C6 tidak mendukung 5 GHz) | 1 |
| 6 | Server HTTP tujuan | default `http://httpbin.org/post`, atau server lokal (`http_sink.py`) | 1 |

**Konfigurasi jaringan**

| Parameter | Nilai |
|---|---|
| Thread network | `ESP_OT_GW`, channel 15, PAN `0xABCD` |
| Mesh-local prefix | `fdde:ad00:beef::/64` (identik di H2 dan C6) |
| Grup multicast / port | `ff03::abcd` : 5050 |
| Interval telemetri | 3000 ms |
| Topic/URL tujuan | `SERVER_URL` di `src/c6_gateway/main.cpp` |

**Server HTTP lokal — `http_sink.py`**

Bila `httpbin.org` terblokir (gejala di Serial Monitor: `HTTP -1`), gunakan server HTTP lokal yang sudah disertakan di folder modul ini (`http_sink.py`). Server ini mendengarkan POST di `0.0.0.0:8080`, mencetak tiap POST yang masuk dengan timestamp, lalu membalas HTTP 200 + JSON — berfungsi sebagai pengganti `httpbin.org` sekaligus bukti bahwa hop Wi-Fi/HTTP benar-benar sampai.

```bash
# 1. cari IP laptop di Wi-Fi yang sama dengan board
ip -4 addr show | grep inet        # mis. 192.168.1.5

# 2. jalankan server (dengar di 0.0.0.0:8080)
python3 http_sink.py
```

Arahkan `SERVER_URL` di `src/c6_gateway/main.cpp` ke IP laptop:

```cpp
const char *SERVER_URL = "http://192.168.1.5:8080/post";
```

Output contoh (setiap POST yang sampai):

```
[   0.000] http_sink siap di 0.0.0.0:8080 (POST -> HTTP 200)
[ 480.308] #1    POST /post from 192.168.1.39  ->  {"sensor":"h2","data":"suhu:23.1"}
```

Catatan: karena hop Wi-Fi/HTTP di gateway dwi-radio ini paling rapuh (koeksistensi Thread + Wi-Fi), sebagian besar POST bisa tercetak `HTTP -1` di Serial Monitor sedangkan server tidak menerima apa pun. Tugas pada modul ini menghitung berapa `RX via Thread` yang berhasil sampai ke server (lihat Bagian 8).

**platformio.ini — dua board berbeda dalam satu proyek**

```ini
[env:h2_node]
board = esp32-h2-devkitm-1
build_src_filter = +<h2_node/*.cpp>
upload_port  = /dev/ttyACM0

[env:c6_gateway]
board = esp32-c6-devkitc-1
board_build.partitions = huge_app.csv    ; firmware Thread+Wi-Fi+HTTP > 1,25 MB
build_src_filter = +<c6_gateway/*.cpp>
upload_port  = /dev/ttyACM1
```

**Pre-flight checklist**

- ☐ ESP32-H2 dan ESP32-C6 terhubung ke PC via kabel USB, port dicatat lewat `pio device list`.
- ☐ `WIFI_SSID`, `WIFI_PASS`, dan `SERVER_URL` pada `src/c6_gateway/main.cpp` sudah disesuaikan.
- ☐ Hotspot/Wi-Fi **2,4 GHz** aktif dan kedua board berada dalam jangkauan sinyal.
- ☐ Server HTTP tujuan dapat diakses (cek `httpbin.org` dari browser, atau jalankan `python3 http_sink.py` untuk server lokal).
- ☐ Firmware `h2_node` dan `c6_gateway` berhasil di-build.
- ☐ Env gateway memakai `board_build.partitions = huge_app.csv`.
- ☐ Serial Monitor 115200 dibuka untuk masing-masing board.

**Deploy**

```bash
pio run -d week13_thread_wifi_gateway -e c6_gateway -t upload -t monitor
pio run -d week13_thread_wifi_gateway -e h2_node    -t upload
```

## 7 · Percobaan

### EXP-01 — Menyalakan Jaringan Thread

Deploy firmware `h2_node` ke ESP32-H2 dan `c6_gateway` ke ESP32-C6. Kedua board memakai dataset Thread identik. Gateway menjadi Leader, node menunggu hingga role mencapai Child.

```
+--------+   dataset sama: ESP_OT_GW / ch15 / 0xABCD   +----------+
|   H2   | <------------- attach as Child ------------>|    C6    |
| (node) |                                             | (leader) |
+--------+                                             +----------+
```

**Data capture**

| Parameter | Hasil |
|---|---|
| Nama jaringan Thread | |
| Channel / PAN ID | |
| Role H2 setelah attach | |
| Role C6 setelah attach | |
| Awalan Mesh-Local EID H2 dan C6 sama? | … (harus `fdde:ad00:beef:0:`) |
| Waktu hingga attach (± detik) | |

> **CHECKPOINT** — Kedua board mencetak `Attached as: ...` **dan** awalan EID keduanya sama. Jika berbeda, gateway tidak akan pernah menerima apa pun meski keduanya tampak "terhubung" — perbaiki dulu.

### EXP-02 — Telemetri lewat Thread

Setelah attach, H2 mengirim `suhu:XX.X` ke grup multicast tiap 3 detik. Amati pasangan TX/RX pada kedua Serial Monitor.

```
[H2 loop] ──tiap 3 s──► OtUdp.beginPacket(GROUP,5050) ──► "TX via Thread: suhu:25.3"
[C6 loop] ────────────► OtUdp.parsePacket()           ──► "RX via Thread [<EID sumber>]: suhu:25.3"
```

Catatan: alamat yang tercetak gateway adalah `OtUdp.remoteIP()` — mesh-local EID **node pengirim** (`fdde:ad00:...`), bukan alamat grup `ff03::abcd` yang dituju.

**Expected output — H2**

```
Sensor H2 (Thread node) starting...
Menunggu join ke gateway (C6)...
Attached as: child
TX via Thread: suhu:25.4
TX via Thread: suhu:26.1
```

**Expected output — C6**

```
Konek Wi-Fi NAMA_WIFI....
Wi-Fi OK, IP: 192.168.x.x
Menunggu attach Thread...
Thread attached as: leader
Gateway siap (Thread -> Wi-Fi).
RX via Thread [fdde:ad00:beef:0:xxxx:xxxx:xxxx:xxxx]: suhu:25.4
```

**Buka abstraksinya** — perhatikan urutan di `setup()` gateway: `OThread.begin()` dulu, lalu Wi-Fi, baru `OThread.start()`. Coba dua variasi, flash, dan catat gejalanya masing-masing:

1. Pindahkan blok Wi-Fi ke paling atas → board **panic** (`Failed to create OpentThread event loop` → `assert failed: otTaskletsSignalPending`).
2. Pindahkan blok Wi-Fi ke bawah `OThread.start()` → board hidup, tetapi Wi-Fi **tidak pernah** asosiasi (`status=6` terus).

Telusuri sebab (1) hingga menemukan `esp_event_loop_create_default()`: siapa yang membuatnya lebih dulu, dan mengapa satu stack menerima kondisi "sudah ada" sedangkan yang lain menganggapnya fatal? Untuk (2), kaitkan dengan *radio coexistence*: kedua radio berbagi satu antena 2,4 GHz.

> **CHECKPOINT** — Jumlah baris `TX via Thread` di H2 dan `RX via Thread` di C6 harus sama dalam periode pengamatan yang sama. Selisihnya adalah loss hop Thread — catat, jangan diabaikan.

### EXP-03 — Penerusan ke Wi-Fi (HTTP POST)

Setiap pesan yang diterima diteruskan gateway ke `SERVER_URL` sebagai JSON `{"sensor":"h2","data":"suhu:XX.X"}` dengan header `Content-Type: application/json`. Verifikasi kode respons HTTP (200 = sukses). Biarkan sistem berjalan 2–3 menit.

```
"RX via Thread" ──► forwardToWifi(buf) ──► HTTPClient ──► http.POST(JSON)
                ──► "Forward via Wi-Fi ... | HTTP 200"
```

```
Forward via Wi-Fi -> http://httpbin.org/post | HTTP 200
```

Variasi wajib: **matikan hotspot ± 15 detik** saat sistem berjalan. Amati baris `Wi-Fi terputus, skip forward` dan catat apakah data Thread yang datang selama itu hilang atau tertahan.

**Data capture**

| Parameter | Hasil |
|---|---|
| IP Wi-Fi gateway | |
| URL server tujuan | |
| HTTP status code yang diterima | |
| RSSI Wi-Fi gateway (`WiFi.RSSI()`) | |
| Paket Thread diterima vs di-POST (2 menit) | |
| Nasib data saat Wi-Fi putus | |

> **CHECKPOINT** — Tersedia **tiga** angka untuk periode yang sama: paket dikirim H2, paket diterima C6, dan POST berhasil (HTTP 200). Selisih antar ketiganya menunjukkan hop mana yang bermasalah — inilah yang membedakan laporan yang bisa dipertanggungjawabkan dari sekadar "sistem berjalan".

### Verifikasi hardware (log referensi)

Dijalankan pada **ESP32-H2 DevKitM-1** + **ESP32-C6 DevKitC-1** asli.

```
# H2 (env h2_node)                # C6 (env c6_gateway)
[0.401] Sensor H2 starting...     [2.004] Konek Wi-Fi ...
[1.203] Attached as: Router       [2.004] Wi-Fi OK, IP: 192.168.110.197 | RSSI: -83 dBm
[3.407] TX via Thread: suhu:25.6  [2.805] Thread attached as: Router
                                  [2.805] Default netif dikembalikan ke Wi-Fi STA (err=0)
                                  [3.406] RX via Thread [fdde:ad00:beef:0:385a:...]: suhu:25.6
                                  [8.413] Forward via Wi-Fi -> ... | HTTP -1
```

| Bagian rantai | Status |
|---|---|
| Build `h2_node` + `c6_gateway` (`huge_app.csv`) | ✅ sukses |
| C6 attach ke Thread `ESP_OT_GW` | ✅ 2,8 s sejak boot |
| Telemetri `suhu:XX.X` H2 → C6 lewat Thread | ✅ 13/13 paket, 0 % loss |
| C6 asosiasi Wi-Fi sambil Thread jalan | ✅ 2,0 s (setelah perbaikan urutan) |
| HTTP POST ke server | ⚠️ sampai di server, tetapi balasan sering timeout (`HTTP -11`) |
| Penanganan Wi-Fi gagal | ✅ setup() lanjut, dicoba ulang berkala di `loop()` |

**Koeksistensi Wi-Fi + 802.15.4 — syarat wajib yang ditemukan lewat uji.** Gateway ini menjalankan dua radio pada satu antena 2,4 GHz. Tanpa penanganan khusus, C6 tetap asosiasi Wi-Fi dan dapat IP yang benar, tetapi **seluruh TCP keluar gagal** — bahkan ke router sendiri:

```
diag: status=3 rssi=-82 ip=... gw=...
diag: tcp ke router = 0 (4002 ms)     <- paket tidak lewat sama sekali
```

Dua hal yang menyelesaikannya, keduanya sudah ada di kode:

1. **Urutan inisialisasi** — Wi-Fi disambungkan di antara `OThread.begin()` dan `OThread.start()`.
2. **Prioritas radio ke Wi-Fi** sebelum 802.15.4 aktif:

```cpp
#include "esp_coexist.h"
esp_coex_preference_set(ESP_COEX_PREFER_WIFI);   // sebelum OThread.start()
```

Setelah keduanya diterapkan, POST benar-benar sampai di server (`{"sensor":"h2","data":"suhu:22.9"}` tercatat di server penerima). Namun hop Wi-Fi tetap yang paling rapuh: **balasan** HTTP sering tidak kembali tepat waktu, tercetak sebagai `HTTP -11` (read timeout) walaupun datanya sudah diterima server. Karena itu `http.setConnectTimeout()`/`setTimeout()` dinaikkan ke 8 detik.

**Yang sudah dicoba dan tidak menyelesaikan:** mengganti channel 802.15.4 (15 → 25), memakai AP di kanal Wi-Fi yang tidak bertetangga, `WiFi.setSleep()` kedua nilainya, dan memaksa default netif ke Wi-Fi STA.

**Cara membaca kegagalan HTTP:**

| Kode | Arti | Tindakan |
|---|---|---|
| `200` | POST diterima server | — |
| `-1` | koneksi TCP gagal terbentuk | periksa server terjangkau; bila server lokal, pastikan satu subnet |
| `-11` | request terkirim, **balasan** timeout | perbesar `http.setTimeout()`; cek apakah data sudah masuk di sisi server |

**Yang harus dilakukan praktikan:** catat RSSI Wi-Fi gateway, dan isi tabel loss per hop di Bagian 8 dengan membandingkan `RX via Thread`, kode HTTP, dan log di sisi server. Bila `RX via Thread` normal tetapi POST bocor, itu bukan kegagalan praktikum — itu justru data yang diminta Bagian 9 nomor 1.

**Delapan perbaikan kode yang lahir dari uji ini**

| Masalah di perangkat nyata | Perbaikan |
|---|---|
| C6 **panic** saat boot: `Failed to create OpentThread event loop` → `assert failed: otTaskletsSignalPending` | `OThread.begin()` dipanggil **sebelum** Wi-Fi |
| Wi-Fi tidak pernah asosiasi bila `OThread.start()` sudah jalan | Wi-Fi disambungkan **di antara** `OThread.begin()` dan `OThread.start()` |
| `while (WiFi.status() != WL_CONNECTED)` menggantung selamanya bila SSID/password salah | dibatasi `WIFI_TIMEOUT_MS`, setup() lanjut, dicoba ulang di `loop()` |
| Gateway tidak pernah pulih setelah AP sempat mati | `maintainWifi()` menyambung ulang berkala |
| `WiFi.disconnect()` tiap percobaan ulang membatalkan asosiasi yang sedang berjalan | hanya `WiFi.begin()` ulang, jeda `WIFI_RETRY_MS` lebih panjang dari durasi asosiasi |
| Dua netif aktif (Wi-Fi + OpenThread) tanpa default yang pasti | `restoreWifiAsDefaultNetif()` memastikan rute IPv4 lewat Wi-Fi STA |
| Seluruh TCP keluar gagal saat stack Thread aktif | `esp_coex_preference_set(ESP_COEX_PREFER_WIFI)` sebelum `OThread.start()` |
| Balasan HTTP timeout (`HTTP -11`) padahal data sudah sampai server | `http.setConnectTimeout(8000)` dan `http.setTimeout(8000)` |

**Urutan inisialisasi yang benar** — inilah hasil terpenting modul ini:

```
1. OThread.begin(false)      // OT membuat event loop default
2. commit dataset + ML prefix
3. WiFi.mode()/begin()       // asosiasi selesai selagi radio 802.15.4 belum aktif
4. OThread.networkInterfaceUp() + OThread.start()
```

Membalik langkah 1 dan 3 membuat board **panic**; menaruh langkah 3 setelah langkah 4 membuat Wi-Fi **tidak pernah** asosiasi.

## 8 · Pengukuran

| Skenario / Jarak H2–C6 | RSSI Wi-Fi (C6) | Latency end-to-end (TX→HTTP, ms) | Success (paket / 40) |
|---|---|---|---|
| 1 m, garis pandang | | | |
| 5 m, garis pandang | | | |
| 5 m + penghalang dinding | | | |

Latency diukur manual: cap waktu baris `TX via Thread` pada H2 vs `Forward via Wi-Fi ... HTTP 200` pada C6.

**Tabel loss per hop — wajib.** Inilah yang membedakan modul ini dari sekadar demo:

| Hop | Dikirim | Diterima | Loss (%) |
|---|---|---|---|
| H2 → C6 (Thread) | | | |
| C6 → server (Wi-Fi/HTTP) | | | |
| H2 → server (ujung-ke-ujung) | | | |

## 9 · Analisis

Jawab berdasarkan tabel Bagian 8:

1. Mengapa ESP32-C6 dapat menjadi Thread Leader dan Wi-Fi STA secara bersamaan, dan apa konsekuensinya (ukuran firmware, pembagian waktu radio)?
2. Bagaimana pengaruh jarak/penghalang terhadap jumlah paket Thread yang diterima gateway?
3. Berapa latency tambahan yang diperkenalkan hop Wi-Fi/HTTP dibanding bila data berhenti di gateway (bandingkan dengan latency Thread murni M11)?
4. Apa yang terjadi pada baris `Wi-Fi terputus, skip forward` — dan apakah data Thread tersebut hilang? Bagaimana cara memperbaikinya?
5. Kapan arsitektur Thread→Wi-Fi gateway lebih tepat dipakai dibanding node sensor Wi-Fi langsung? Jawab dari sisi daya, jangkauan, dan jumlah node.

## 10 · Concept Check

1. Apa perbedaan gateway dan border router dalam konteks jaringan Thread?
2. Mengapa komunikasi Thread pada praktikum ini memakai UDP multicast, bukan unicast?
3. Apa fungsi dataset (channel, PAN ID, network key, mesh-local prefix) dalam pembentukan jaringan Thread?
4. Bagaimana gateway mengetahui alamat sumber pesan Thread (perhatikan output `remoteIP`)?
5. Apa kelemahan forwarding via HTTP POST dibanding MQTT untuk telemetri periodik? (Jawaban ini adalah jembatan ke Modul 14.)

## 11 · Challenge (tugas modifikasi)

- **CH-1 — Dua sensor.** Tambahkan node Thread H2 kedua dengan payload berbeda (mis. `hum:XX`) dan pastikan gateway mem-forward keduanya. Bagaimana server membedakan sumbernya?

- **CH-2 — Payload lebih kaya.** Sertakan RSSI Thread dan nomor urut di dalam payload (`suhu:25.3,rssi:-62,#42`). Diskusikan: apakah ini masih *transparent forwarding*?

- **CH-3 — Loss per hop (wajib).** Hitung packet loss dengan sequence number pada payload. Contoh: 100 paket dikirim H2, 97 diterima gateway → loss Thread = 3 %. Lalu bandingkan dengan jumlah HTTP 200 untuk mendapatkan loss hop Wi-Fi.

- **CH-4 — Buffer saat Wi-Fi putus.** Ubah gateway agar menyimpan pesan Thread yang datang saat Wi-Fi mati (mis. antrean 20 pesan) dan mengirimkannya setelah koneksi pulih. Ukur berapa pesan yang berhasil diselamatkan.

## 12 · Laporan

**Deliverable**

1. Misi & capaian pembelajaran
2. Dasar teori ringkas (gateway, border router, Thread, Wi-Fi STA, UDP multicast, mesh-local prefix)
3. Konfigurasi — dataset Thread, SSID, URL server, port, `huge_app.csv`
4. Hasil eksperimen — log kedua board (EXP-01…03 + checkpoint), termasuk uji Wi-Fi diputus
5. Data pengukuran — tabel Bagian 8 **dan** tabel loss per hop
6. Analisis + concept check
7. Challenge — minimal CH-3
8. Kesimpulan — ditulis sendiri berdasarkan hasil pengujian
