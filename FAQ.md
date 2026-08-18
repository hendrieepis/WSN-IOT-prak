# FAQ

## Ringkasan modul Week 1–16

| Minggu | Modul | Topik | Keterangan |
|---|---|---|---|
| 1 | `week01_ble_p2p` | Establish a BLE Link (koneksi P2P H2↔H2) | BLE |
| 2 | `week02_ble_p2p_data` | Exchange Data (notify + write dua arah) | BLE |
| 3 | `week03_ble_client_server` | Build a BLE Service (GATT read/write) | BLE |
| 4 | `week04_ble_telemetry` | Stream Telemetry (server → client notify) | BLE |
| 5 | `week05_ble_multinode` | Connect Multiple Devices (1 pusat ↔ banyak node) | BLE |
| 6 | `week06_ble_mesh` | Build a BLE Mesh (relay H2↔H2↔H2) | **BLE mesh** |
| 7 | `week07_802154_p2p` | Speak Raw 802.15.4 (frame mentah H2↔H2) | 802.15.4 mentah |
| 8 | `week08_zigbee_p2p` | Join a Zigbee Network (Coordinator ↔ End Device) | Zigbee (di atas 802.15.4) |
| 9 | `week09_zigbee_multinode` | Scale the Network (Coordinator ↔ beberapa ED) | Zigbee (di atas 802.15.4) |
| 10 | `week10_zigbee_mesh` | Route Through the Mesh (Coordinator ↔ Router ↔ ED) | **Zigbee mesh** (di atas 802.15.4) |
| 11 | `week11_thread_p2p` | Speak IPv6 over Thread (UDP H2↔H2) | Thread (di atas 802.15.4) |
| 12 | `week12_thread_mesh` | Mesh the Internet (mesh IPv6 multi-node) | **Thread mesh** (di atas 802.15.4) |
| 13 | `week13_thread_wifi_gateway` | Bridge Thread to Wi-Fi (H2 → C6 → Wi-Fi) | Thread + Wi-Fi |
| 14 | `week14_mqtt` | Publish to the Cloud (C6 → broker MQTT) | Wi-Fi/MQTT |
| 15 | `week15_e2e_iot` | Build End-to-End IoT System (H2 → Thread → C6 → MQTT) | Thread + Wi-Fi/MQTT |
| 16 | `week16_comparative` | Prove Your Protocol (benchmark BLE/Zigbee/Thread) | BLE/Zigbee/Thread → MQTT |

Rangkuman: 1–6 BLE (P2P → mesh), 7 802.15.4 mentah, 8–10 Zigbee, 11–12 Thread, 13–15 integrasi gateway/MQTT/end-to-end, 16 perbandingan protokol berbasis data.

## Pertanyaan umum

### Yang hanya 802.15.4 itu week berapa saja?

Hanya **week 7** (`week07_802154_p2p`) yang memakai 802.15.4 mentah/telanjang.
Week 8–10 (Zigbee) dan 11–12 (Thread) juga berjalan di atas radio 802.15.4,
tapi sudah sebagai protokol lapisan atas.

### Yang mesh itu week berapa saja?

- **week 6** — BLE mesh (relay)
- **week 10** — Zigbee mesh (routing)
- **week 12** — Thread mesh (IPv6)

### Apa yang dilakukan week 7?

Week 7 (`week07_802154_p2p`) adalah **raw 802.15.4 P2P**: menyusun frame MAC
802.15.4 byte demi byte (Len + MHR 11 byte + payload) tanpa stack
Zigbee/Thread/BLE, lalu mengirim PING/PONG langsung antar dua ESP32-H2 lewat
API ESP-IDF `esp_ieee802154.h` (channel 15, PAN ID `0xCAFE`, short addr
`0x0001`/`0x0002`), mengukur RSSI, latency RTT, dan packet loss tiap arah.
Ini jadi baseline radio untuk M16.

### Di week 7 masing-masing jadi end device kah?

Tidak. Week 7 tidak ada konsep Coordinator/End Device — radio 802.15.4 dipakai
telanjang tanpa stack Zigbee. Kedua ESP32-H2 adalah **peer setara**: Node1
(`0x0001`) pengirim PING + penerima balasan, Node2 (`0x0002`) penerima +
pembalas PONG. Peran Coordinator ↔ End Device baru muncul di week 8–10 (Zigbee).

### Bukannya 802.15.4 juga ada end device, router, dan koordinator?

Sebagian benar — jawabannya campuran:

**Ada di 802.15.4 (tingkat PHY/MAC):**
- **FFD** (Full Function Device) dan **RFD** (Reduced Function Device), serta
  **PAN Coordinator** — perangkat yang boleh memulai PAN. Konsep ini
  didefinisikan standar 802.15.4 sendiri.

**Tapi "Router" dan End Device sebagai peran jaringan:**
- **802.15.4 murni TIDAK punya routing.** Frame hanya point-to-point (atau
  broadcast); tidak ada multi-hop. Jadi konsep "router" yang mem-forward paket
  untuk node lain adalah **bukan** 802.15.4 — itu di lapisan atas.
- **Zigbee** (di atas 802.15.4) mendefinisikan **ZC/ZR/ZED** (Zigbee
  Coordinator, Router, End Device).
- **Thread** punya role sendiri yang beda lagi: Leader, Router, REED, dan End
  Device (SED).

Jadi di week 7 kedua board adalah RFD/FFD telanjang tanpa peran jaringan —
makanya disebut "peer setara".

### Kalau 3 device saling komunikasi, termasuk yang mana: node, RFD, FFD, atau PAN Coordinator?

Bergantung lapisannya:

**Di 802.15.4 murni (kalau menerapkan standar penuh, termasuk beacon & association):**
- Harus ada **minimal satu FFD yang jadi PAN Coordinator** (yang memulai PAN).
- Device lain bisa FFD (boleh jadi coordinator biasa) atau RFD (hanya paling
  sederhana: tidak boleh koordinator).
- Jadi 3 device itu: 1 PAN Coordinator (FFD) + sisanya FFD/RFD sesuai kemampuan.

**Di lab week 7 (802.15.4 "telanjang"):**
- Kode tidak memakai beacon/association/role sama sekali — semua device hanya
  dikonfigurasi channel + PAN ID + short addr, lalu saling kirim. Maka
  ketiganya **cukup disebut "node"** (peer), tidak ada yang diangkat jadi PAN
  Coordinator. Secara formal ini *peer-to-peer topology* 802.15.4 yang tidak
  memakai peran.

**Di Zigbee (week 9, 3 device):**
- Baru dipetakan eksplisit: 1 **ZC** (Coordinator) + sisanya **ZED** (End
  Device) — atau ZR kalau ikut routing.

### Tanpa ZED, hanya pakai protokol 802.15.4 apa bisa saling komunikasi?

Bisa, dan itu justru yang dibuktikan week 7: dua (atau lebih) device cukup
dikonfigurasi **channel + PAN ID + short address** lalu langsung saling kirim
frame — tanpa stack Zigbee, tanpa ZED/ZC. ZED itu peran lapisan Zigbee, bukan
prasyarat komunikasi 802.15.4.

### Apa nggak saling tabrakan ketika 5 device saling komunikasi di 802.15.4 tanpa Zigbee?

Sebagian besar tidak, karena **lapisan MAC 802.15.4 sudah punya mekanisme
anti-tabrakan bawaan**: sebelum kirim, radio melakukan **CSMA/CA** —
mendengarkan kanal dulu (CCA), kalau sibuk menunggu mundur secara acak
(backoff), baru kirim. Tapi catatannya:

- CSMA/CA **mengurangi, bukan menghilangkan** tabrakan — dua device yang mulai
  kirim bersamaan tetap bisa bentrok.
- Di week 7 tidak dipakai ACK/retransmit (frame mentah), jadi frame yang
  tabrakan **hilang** — terlihat sebagai packet loss.
- Tidak ada slot terjadwal (TDMA), karena tidak ada beacon/koordinator.

Makanya di Zigbee/Thread ada lapisan tambahan: ACK, retry, routing.

### Apa yang harus disamakan jika 5 device ingin saling berkomunikasi di 802.15.4 tanpa Zigbee/Thread?

Yang wajib sama: **channel radio, PAN ID, dan format frame** (Len/MHR yang
sama). Alamat (short addr) harus **berbeda** tiap device supaya penerima bisa
membedakan pengirim. Kalau mau semua saling dengar, bisa pakai alamat tujuan
`0xFFFF` (broadcast) — tapi tanpa ACK. Yang **tidak perlu** disamakan: tidak
ada ZC/ZED/router, tidak ada join, tidak ada dataset.

### Apakah ada mekanisme auto-join di 802.15.4?

Ada — standar 802.15.4 sendiri mendefinisikan **mekanisme association** (MLME):

1. **Scan**: device baru melakukan *active/passive scan* untuk mencari beacon
   dari coordinator.
2. **Associate**: mengirim *association request* ke coordinator yang ditemukan.
3. **Pemberian alamat**: coordinator menjawab, memberi **short address** baru,
   PAN ID, dst. — device otomatis masuk jaringan tanpa konfigurasi manual.

Tapi syaratnya: coordinator harus menjalankan **beacon-enabled mode**, dan
kedua pihak mengimplementasikan prosedur MLME (bukan sekadar API radio mentah).
`esp_ieee802154.h` di week 7 **tidak** menyediakan itu — API-nya hanya TX/RX
frame, jadi association harus ditulis manual. Secara praktis, itulah yang
dilakukan Zigbee/Thread: keduanya memakai asosiasi 802.15.4 sebagai fondasi.

### Jadi tanpa Zigbee/Thread tidak bisa otomatis join?

Tepatnya: **mekanismenya ada di standar 802.15.4** (prosedur association MLME +
beacon), jadi secara teori bisa tanpa Zigbee/Thread. Tapi praktiknya:

- Kamu harus **menulis sendiri** prosedur MLME: beacon mode di coordinator,
  scan, association request/response, management alamat — ratusan baris kode
  yang rawan salah.
- API mentah (`esp_ieee802154.h`) tidak menyediakannya.

Jadi singkatnya: *bisa secara teori, tidak praktis di lapangan*. Join otomatis
yang tinggal pakai memang praktisnya dari Zigbee/Thread.

### Apakah ada proteksi security standard di jaringan 802.15.4?

Ada, tapi opsional dan berlapis:

**Di 802.15.4 (MAC layer):**
- Mendukung **AES-128** dengan mode **CCM\*** (enkripsi + autentikasi),
  **frame counter** (anti-replay), dan **MIC** (cek integritas).
- Semua diset lewat *security suite* — paket bisa dienkripsi penuh atau hanya
  diautentikasi.
- **Tapi:** default di banyak implementasi (termasuk week 7) adalah **tanpa
  keamanan** — frame dikirim polos. Manajemen kunci juga lemah. Jadi kalau
  tidak diaktifkan, siapa pun dengan radio 802.15.4 di channel yang sama
  **bisa menyadap**.

**Di Zigbee:** menambah enkripsi APS layer (network key + link key).
**Di Thread:** menambah keamanan lapisan jaringan (DTLS, enkripsi IPv6, dll).

### Apakah proteksi standard itu bisa diimplementasikan di ESP32-H2?

Bisa — dengan catatan:

- **Hardware-nya mendukung**: ESP32-H2 punya **AES-128 accelerator** (dipakai
  lewat mbedTLS/esp_aes).
- **Tapi API raw `esp_ieee802154.h` tidak menyediakan "aktifkan security"
  instan** — tidak ada fungsi set security suite. Kalau mau frame raw
  terenkripsi, kamu **implementasikan sendiri AES-CCM\*** (enkripsi + MIC) di
  perangkat lunak, lalu tambahkan security header dan perhitungkan `Len` —
  persis seperti cara week 7 menyusun MHR manual.
- **Praktisnya**: Zigbee dan Thread di ESP32-H2 **sudah mengimplementasikan
  keamanan itu secara otomatis** di stack-nya.

### Apakah mungkin XBee 802.15.4 berkomunikasi dengan ESP32-H2?

Secara **fisik (PHY)** ya — keduanya sama-sama IEEE 802.15.4. Secara
**praktis: tidak langsung**, karena:

- **XBee (Seri 1/802.15.4) memakai firmware Digi** dengan format payload RF
  sendiri (header 8-byte alamat, RSSI, options byte) di dalam frame MAC
  802.15.4. XBee hanya bisa "ngobrol" lancar dengan sesama radio Digi.
- ESP32-H2 raw (week 7) menyusun frame MAC polos. Jadi komunikasi perlu
  **mereplikasi format payload XBee** di sisi H2 + menyesuaikan addressing
  64-bit, kanal, PAN, dan menonaktifkan enkripsi XBee. Ini hack yang rapuh dan
  tidak didukung vendor.
- Kalau XBee **Seri 2 (Zigbee)**: pakai stack **Zigbee di ESP32-H2** (week
  8–10) sebagai Coordinator lalu pairing ke XBee S2 — interop Zigbee resmi.

Kesimpulan: cara mulus hanya **XBee ↔ XBee**, atau **H2-Zigbee ↔ XBee S2**.

### Berapa bit payload di week 7?

Payload default `"PING n"` ≈ **7 byte = 56 bit** (contoh `PING 38` di dump).
`Len` = 11 (MHR) + 7 (payload) + 2 (FCS) = **20 byte (0x14)**. Di CH-2 ada
opsi memperbesar payload jadi 40 byte.

### Apakah ada standar maksimal payload di 802.15.4?

Ada. Standar IEEE 802.15.4 menetapkan **frame PHY maksimal 127 byte** (PSDU):

- MHR minimal 11 byte (seperti week 7): payload maks ≈ **127 − 11 − 2 (FCS)
  = 114 byte**.
- MHR maksimal 25 byte (semua field alamat extended): payload ≈ 100 byte.
- Dengan security (AES-CCM\*): berkurang lagi sesuai security header + MIC.

Jadi batasnya bukan di aplikasi, tapi di **PHY: 127 byte** per frame.

### Range nilai PAN ID, address, dst. di week 7

| Parameter | Lebar | Range valid | Nilai di week 7 |
|---|---|---|---|
| Channel | — | 11–26 (2.4 GHz) | 15 |
| PAN ID | 16 bit | 0x0000–0xFFFF (`0xFFFF` = broadcast PAN) | `0xCAFE` |
| Short address | 16 bit | 0x0000–0xFFFF (`0xFFFF` = broadcast, `0xFFFE` = reserved) | `0x0001`, `0x0002` |
| Extended address | 64 bit | 0x0000…0xFFFF… | tidak dipakai |
| Len (frame PHY) | 8 bit | 1–127 byte | 20 byte (0x14) |
| FCS | 16 bit | dihitung hardware | otomatis |

Short address `0xFFFF` dipakai di CH-4 (broadcast) untuk mengirim ke semua node.

### Apa itu Matter?

Matter adalah **standar smart home bersama** (CSA — Apple, Google, Amazon,
Samsung, dll.) yang menyatukan protokol rumah pintar di atas **IP**:

- **Jalur transport utama**: Thread (di atas 802.15.4) untuk perangkat
  low-power, plus **Wi-Fi** untuk perangkat kaya sumber daya, dan **BLE** hanya
  untuk *commissioning* (onboarding awal).
- BLE dipakai sekali di setup (kode QR/pairing), lalu perangkat berkomunikasi
  via Thread/Wi-Fi.
- Thread di ESP32-H2 (week 11–13) adalah fondasi yang dipakai Matter — gateway
  Thread→Wi-Fi di week 13 itu analog dengan *Thread Border Router* dalam
  ekosistem Matter.
- Di atasnya Matter memakai **IPv6 + mDNS + CoAP** (bukan MQTT seperti lab).

### Layer Matter — diagram stack

```
┌───────────────────────────────────────────────────────────────┐
│  APLIKASI Smart Home (control, light, thermostat, sensor)     │
├───────────────────────────────────────────────────────────────┤
│  MATTER Application Layer (clusters, data model)              │
│  Interaction Model + Action Framing                           │
│  Security (Message Layer: encryption, node ID)                │
│  Transport: UDP (reliable via ACK layer) / TCP                │
├───────────────────────────────────────────────────────────────┤
│  IPv6  (mDNS discovery, per-node IPv6)                        │
├──────────────────┬────────────────────┬───────────┬───────────┤
│  THREAD          │      Wi-Fi         │ Ethernet  │    BLE    │
│  (IPv6 + 6LoWPAN)│    (IPv6)          │  (IPv6)   │ (hanya    │
│  ─────────────── │                    │           │  commis-  │
│  802.15.4 PHY/MAC│  802.11 PHY/MAC    │           │  sioning) │
└──────────────────┴────────────────────┴───────────┴───────────┘
```

Posisi Matter: **lapisan aplikasi/protokol di atas IP**, tidak mengikat satu
radio:

- **di atas Thread** (Thread = IPv6 di atas 6LoWPAN di atas 802.15.4) → jalur
  utama perangkat low-power.
- **di atas Wi-Fi** → perangkat bertenaga listrik.
- **BLE** hanya saat commissioning, bukan jalur data.
- **Zigbee tidak ada di stack Matter** — dia protokol saudara di radio yang
  sama (802.15.4) dan masuk lewat *bridge* Matter↔Zigbee kalau perlu.

Dibanding lab: week 11–13 (Thread + gateway) ≈ dasar Matter; week 14 (MQTT)
itu jalur *alternatif* yang Matter tidak pakai — Matter memilih CoAP/IP
langsung.

### Kenapa Zigbee tidak digambar di stack Matter?

Karena Zigbee **memang bukan bagian dari stack Matter** — dia jalur paralel:

```
   ┌──────────────────────────────┐
   │        APLIKASI Smart Home   │
   ├──────────────────────────────┤
   │       MATTER (CSA)           │
   │  Application clusters        │
   │  Interaction Model / Framing │
   │  Message Layer (security)    │
   │  Transport UDP/TCP           │
   ├──────────────────────────────┤
   │        IPv6 + mDNS           │
   └──────┬───────────┬───────────┘
           │           │
  ┌───────┴─────┐ ┌───┴───────────────┐   ┌──────────────┐
  │   THREAD    │ │      Wi-Fi        │   │   BLE        │
  │ UDP/CoAP    │ │   UDP/TCP         │   │ GATT         │
  │ 6LoWPAN     │ │   802.11 PHY/MAC  │   │ (commissioning│
  │ mesh route  │ │                  │   │  saja)        │
  │ 802.15.4    │ │                  │   │              │
  └──────┬──────┘ └──────────────────┘   └──────────────┘
         │
  ┌──────┴──────────┐      ┌───────────────────────────┐
  │ IEEE 802.15.4   │◄────►│        ZIGBEE (jalur lain)│
  │ PHY/MAC bersama │      │ APS security              │
  │ (channel,PAN,   │      │ NWK routing (ZC/ZR/ZED)   │
  │  CSMA-CA, AES)  │      │ 802.15.4 PHY/MAC (sama)   │
  └─────────────────┘      └────────────┬──────────────┘
                                        │
                                  ┌─────┴─────┐
                                  │  Zigbee   │
                                  │ End Device│
                                  │ (lampu,dst│
                                  └───────────┘

  Hubungan Zigbee ↔ Matter: lewat BRIDGE
  ┌──────────────┐        ┌──────────────────────────┐
  │ Matter device│ ◄────► │  Bridge (Zigbee + Matter) │
  └──────────────┘        └─────────────┬────────────┘
                                        │
                                  ┌─────┴─────┐
                                  │ Zigbee    │
                                  │ network   │
                                  └───────────┘
```

Di mata Matter, Zigbee bukan "jalur IP" — perangkat Matter asli tidak pernah
berbicara Zigbee. Zigbee masuk hanya sebagai **jaringan lama yang
dijembatani** (bridge mengubah Zigbee cluster ↔ Matter cluster). Sedangkan
Thread, Wi-Fi, Ethernet, BLE semuanya di-support resmi di satu stack yang
sama. Konteks lab: week 8–10 (Zigbee) dan 11–13 (Thread) berbagi **radio
802.15.4 yang sama** — tapi hanya jalur Thread yang menjadi fondasi Matter.

### Apakah ESP32-H2 mendukung Matter?

Ya. ESP32-H2 justru chip yang ideal untuk Matter — radio yang dimilikinya
(BLE + IEEE 802.15.4/Thread) adalah persis yang dibutuhkan Matter:

- **Thread** sebagai jalur komunikasi utama (Matter over Thread, IPv6).
- **BLE** untuk commissioning (pairing kode QR pertama kali).
- Espressif menyediakan **ESP-Matter SDK** (berbasis connectedhomeip/CHIP)
  dengan ESP32-H2 sebagai salah satu chip resmi yang didukung.

Catatan: karena H2 tidak punya Wi-Fi, ia hanya bisa jadi **Matter End Device
over Thread** — bukan Thread Border Router (itu butuh Wi-Fi/ethernet, mis.
ESP32-C6 yang punya Wi-Fi + 802.15.4, persis combo yang dipakai di week
13/15).

### Apakah sudah ada library untuk Matter di ESP32-C6/ESP32-H2?

Ya, resmi dari Espressif:

- **ESP-Matter SDK** (`espressif/esp_matter` — komponen di ESP-IDF Component
  Registry). Berbasis **connectedhomeip (CHIP)** dari CSA, dan resmi
  mendukung **ESP32-H2** (Matter over Thread) dan **ESP32-C6** (Thread +
  Wi-Fi, bisa jadi Border Router).
- Juga ada **ESP Thread Border Router** (`esp-thread-br`) untuk C6 sebagai
  border router.
- Contoh siap pakai di repositori `esp-matter` (light, switch, thermostat,
  sensor) dengan contoh khusus `esp32h2`, `esp32c6`.

Catatan penting: **belum ada library Matter resmi untuk Arduino core** —
ESP-Matter berjalan di atas **ESP-IDF** (bukan PlatformIO/Arduino). Jadi kalau
mau coba Matter, jalurnya pindah ke project ESP-IDF + komponen `esp_matter`,
bukan menambah library di platformio.ini.

### Apakah masalah week 15 bisa di-fix dengan Matter?

Problem M15 (dari README): **bukan di Thread**, tapi di gateway C6 satu-chip
satu-antena — Wi-Fi + 802.15.4 rebutan airtime (0–36 % end-to-end, AP-3 cuma
5 %), plus MQTT QoS 0 yang `publish()` sukses palsu. Hop Thread sendiri selalu
0 % loss.

Apakah Matter memperbaiki? **Sebagian ya, inti masalahnya tidak:**

**Yang diperbaiki Matter:**
- **Hop Thread H2→C6.** M15 pakai UDP multicast tanpa ACK → paket tabrakan
  hilang. Matter memakai **unicast + ACK layer** (MAC ACK + retry Thread + ACK
  di Message Layer) → tabrakan *dipulihkan*, bukan di-drop. Di sisi sensor,
  justru **H2 Matter over Thread tidak butuh Wi-Fi sama sekali** → tidak ada
  koeksistensi di node sensor.
- **Hop MQTT hilang dari jalur utama.** Matter tidak memakai MQTT (pakai
  CoAP/UDP + ACK app layer) → masalah "publish sukses palsu" tidak relevan.

**Yang TIDAK diperbaiki Matter:**
- **Inti masalah M15: satu antena C6 membagi airtime Thread + Wi-Fi.** Border
  router Matter di C6 tetap menjalankan Thread + Wi-Fi bersamaan → masalah
  fisik yang sama tetap ada. Matter tidak mengubah hardware.
- Kalau dashboard/cloud tetap jadi tujuan akhir, tetap perlu jembatan keluar
  Wi-Fi → tetap hop yang sama.

**Kesimpulan**: Matter bukan "fix", melainkan **mengubah arsitektur ke arah
yang lebih benar** — reliable delivery unicast menggantikan multicast tanpa
ACK, dan perbaikan nyata untuk M15 yang direkomendasikan README sendiri tetap
berlaku: **border router dua-chip** (atau gateway khusus), bukan stack
pengganti.

### Efek parameter PAN ID / channel / broadcast — bisa diubah dari program saja?

Ya, hampir semuanya cukup ganti **4 `#define`** di `src/nodeX/main.cpp`
(`CHANNEL`, `PAN_ID`, `MY_ADDR`, `PEER_ADDR`) — tanpa ubah logika:

| Eksperimen | Yang diubah | Efek yang terlihat |
|---|---|---|
| PAN ID sama | `PAN_ID` sama (mis. `0xCAFE` dua node) | komunikasi normal |
| PAN ID beda | `PAN_ID` di salah satu node beda | TX tetap jalan, RX sunyi — frame **disaring hardware**, tidak ada callback |
| Channel sama | `CHANNEL` sama | komunikasi normal |
| Channel beda | `CHANNEL` salah satu node beda | RX sunyi total — radio **tuli**, tidak mendengar apa pun |
| Broadcast | `PEER_ADDR = 0xFFFF` | semua node di channel + PAN yang sama menerima frame yang sama |

Catatan praktis:

1. **Tiap ubah → unggah ulang node yang diubah** (parameter dikompilasi, tidak
   runtime). Isi tabel "channel sama/PAN beda → gejala" vs "channel beda/PAN
   sama → gejala" di laporan biar bedanya terlihat: yang satu *heard but
   filtered* (mendengar tapi disaring), yang satu *never heard* (tidak pernah
   terdengar).
2. **Broadcast butuh node ketiga** (`src/node3`, `MY_ADDR 0x0003`) supaya
   efeknya nyata — bukan sekadar "sama saja dengan unicast".
3. Bonus investigasi: `esp_ieee802154_set_promiscuous_mode(true)` → semua frame
   diterima walau PAN/alamat beda; ini membuktikan penyaringan terjadi di
   **hardware**, bukan di kode.

### Apakah 6LoWPAN didukung ESP32-H2?

Ya. ESP32-H2 mendukung 6LoWPAN — bukan sebagai library terpisah, tapi
**terintegrasi di stack OpenThread** (yang dipakai week 11–13): `OThread`/
ESP-IDF menyediakan IPv6 + 6LoWPAN (kompresi header, fragmentasi 802.15.4) di
atas radio 802.15.4. Buktinya UDP IPv6 multicast `ff03::abcd:5050` di week
11–13 jalan di atas 6LoWPAN.

Catatan: 6LoWPAN **tidak** tersedia lewat API radio mentah `esp_ieee802154.h`
(week 7) — itu hanya PHY/MAC telanjang. Kalau mau 6LoWPAN murni (tanpa stack
Thread penuh), jalur normalnya tetap via OpenThread.

### Di week 8 (Zigbee P2P) harus 1 End Device + 1 Coordinator? Bagaimana kombinasi lain?

**1. Haruskah 1 ZC + 1 ZED di week 8?** Ya, sesuai desain modul — bukan
sekadar kebiasaan. Network Zigbee **wajib punya tepat satu Coordinator (ZC)**
untuk membentuk PAN; tanpa ZC tidak ada jaringan yang bisa di-join. Week 8
juga memakai *find-and-bind* yang dikelola coordinator. Ini topologi paling
umum di dunia nyata (hub + perangkat).

**2. 2 End Device saling komunikasi?** Tidak bisa begitu saja:
- Dua ZED **tidak bisa membentuk jaringan** — ZED adalah daun (leaf), tidak
  boleh punya anak/penerus trafik.
- Mereka baru bisa berkomunikasi kalau **keduanya join ke jaringan yang sama**
  (jadi ZC tetap wajib ada), dan trafiknya lewat orang tua (star topology).
  Sebagai demo P2P ini tidak disarankan.

**3. 1 ZED + 1 Router?** Bisa dan umum di dunia nyata (router + sensor tidur),
tapi:
- **Router (ZR) tetap butuh jaringan** — murni ZED+ZR tanpa ZC tidak bisa
  berdiri sendiri.
- Di Arduino core 3.x, peran ZC dan ZR digabung dalam satu build flag
  `-DZIGBEE_MODE_ZCZR`: firmware itu **membentuk network sebagai ZC kalau
  belum ada**, atau **join sebagai ZR kalau network sudah ada**. Jadi
  kombinasi ZCZR + ED otomatis jadi ZC↔ZED di lab — dan dua board ZCZR akan
  jadi ZC↔ZR.

| Kombinasi | Bisa? | Umum? | Catatan |
|---|---|---|---|
| ZC + ZED | ✅ wajib sebagai dasar | paling umum | dipakai week 8 |
| ZED + ZED | ⚠️ lewat ZC/parent | tidak disarankan | dua daun tidak saling bicara langsung |
| ZR + ZED | ✅ setelah ada ZC | umum di lapangan | di kode kamu = ZCZR + ED |
