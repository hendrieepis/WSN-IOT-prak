# Koeksistensi Wi-Fi + Thread — kenapa Week 13 gagal sebagian tapi Week 15 gagal total

Dokumen ini menjelaskan **perbedaan** dua kegagalan yang terlihat mirip di lab:

- **Week 13** (`week13_thread_wifi_gateway`) — Thread → Wi-Fi → HTTP: mayoritas
  `HTTP -1`, sesekali `HTTP 200` sampai ke server (gagal **sebagian**).
- **Week 15** (`week15_e2e_iot`) — Thread → Wi-Fi → MQTT: `rc=-2` terus-menerus,
  0 % pesan sampai ke broker (gagal **total**).

Keduanya terjadi di board yang sama (ESP32-C6), dengan akar masalah yang sama,
tetapi manifestasinya berbeda. Paham bedanya = paham perbedaan model koneksi
HTTP vs MQTT, bukan sekadar "dua-duanya gagal".

## 1 · Akar masalah yang sama

| | Week 13 (HTTP) | Week 15 (MQTT) |
|---|---|---|
| Board | ESP32-C6 | ESP32-C6 |
| Stack bersamaan | Thread + Wi-Fi + HTTP | Thread + Wi-Fi + MQTT |
| Thread sehat? | ✅ Leader | ✅ Leader |
| Wi-Fi dapat IP? | ✅ `192.168.1.39` | ✅ `192.168.1.39` |
| Penyebab gagal | Koeksistensi radio | Koeksistensi radio |
| Kode kesalahan | `HTTP -1` | `MQTT rc=-2` |

Kedua kode itu **berarti hal yang sama**: koneksi TCP keluar gagal terbentuk.
Thread yang hampir selalu RX menyita airtime dari Wi-Fi di satu antena 2,4 GHz,
sehingga handshake TCP (SYN/SYN-ACK) kalah dan timeout.

- `HTTP -1`  = `CURLE_COULDNT_CONNECT` (TCP connect gagal).
- `MQTT rc=-2` = `MQTT_CONNECTION_TIMEOUT` (TCP connect ke broker gagal).

Jadi **bukan** HTTP-nya atau MQTT-nya yang "berbeda kualitas". Yang berbeda
adalah *model koneksinya*, yang menentukan apakah kegagalan itu terlihat
sebagian atau total.

## 2 · Kenapa Week 13 "sebagian" (HTTP)

HTTP di gateway memakai pola **satu koneksi TCP baru per request**:

```
setiap telemetri  ->  http.POST()  ->  buka TCP baru  ->  tutup (http.end())
```

- Tiap POST adalah usaha yang **independen**. Satu POST gagal (`-1`) tidak
  memengaruhi POST berikutnya.
- Karena keberhasilan TCP connect bersifat **probabilistik** (siapa yang
  menang airtime saat itu), kadang satu POST lolos: `suhu:23.0 -> HTTP 200`,
  lalu percobaan berikutnya `-1` lagi.
- Hasil: campuran `-1` dan sesekali `200` — **loss besar tapi tidak nol**.

Lihat log nyata: `week13_thread_wifi_gateway/logserial.md:35-49`.

## 3 · Kenapa Week 15 "total" (MQTT)

MQTT memakai pola **satu koneksi TCP yang persisten** untuk semua pesan:

```
mqtt.connect()  ->  satu TCP tetap terbuka  ->  semua publish lewat koneksi itu
```

- **Tanpa koneksi itu terbentuk, tidak ada satu pun pesan bisa keluar.**
  `mqtt.connect()` gagal `rc=-2`, lalu seluruh `publish()` gagal karena
  `mqtt.connected()` selalu `false`.
- Sifatnya **all-or-nothing**: koneksi harus berhasil dulu sekali, baru pesan
  bisa mengalir. HTTP tidak punya syarat "awal" seperti ini.
- Hasil: **0 % end-to-end** — total, bukan sebagian.

Lihat log nyata: `week15_e2e_iot/logserial.md:33-55`.

### Jebakan tambahan MQTT: `publish() == true` bukan bukti sampai

Pada QoS 0, `PubSubClient::publish()` hanya menulis ke buffer socket. Bila TCP
setengah mati, `publish()` bisa mengembalikan `true` padahal broker tak menerima
apa pun (tercatat di `week15_e2e_iot/README.md:353-358`). Karena itu keberhasilan
harus dicek dari **log broker**, bukan log gateway.

## 4 · Ringkasan perbandingan

| Aspek | Week 13 (HTTP) | Week 15 (MQTT) |
|---|---|---|
| Model koneksi | TCP baru per request | TCP persisten |
| Sifat kegagalan | per-request, independen | all-or-nothing |
| Gejala | `-1` mayoritas, sesekali `200` | `rc=-2` terus, 0 pesan |
| Kesan pengamat | "sebagian gagal" | "gagal total" |
| Perbaikan yang membantu | retry per POST | pastikan `connect()` sukses dulu, baru publish |

## 5 · Kontras: Week 16 (BLE + Wi-Fi) nyaris tanpa loss

Pembanding paling menentukan — gateway satu-chip yang sama, jaringan Wi-Fi dan
broker yang sama, hanya hop pertama diganti:

| Pipeline | Hop sensor | Hop Wi-Fi | End-to-end |
|---|---|---|---|
| BLE → C6 → MQTT (M16) | 98 % | 100 % | **98 %** |
| Thread → C6 → MQTT (M15) | 77 % | 29 % | **5 %** |

Sumber: `week15_e2e_iot/README.md:363-371`.

BLE + Wi-Fi nyaris tanpa ongkos koeksistensi karena connection event BLE pendek
dan terjadwal, sehingga mudah berbagi airtime dengan Wi-Fi. Thread yang hampir
selalu RX jauh lebih "rakus" di antena yang sama.

Kesimpulan yang benar **bukan** "Thread lebih buruk dari BLE", melainkan:
arsitektur gateway **satu-chip satu-antena tidak cocok untuk Thread + Wi-Fi**.
Border router dua-chip akan mengubah angka ini sepenuhnya.

## 5b · Kenapa BLE + Wi-Fi tidak masalah padahal sama-sama 2,4 GHz?

Frekuensi yang sama bukan masalahnya — yang menentukan adalah **pola penggunaan
radio (duty cycle)**, bukan pita frekuensinya.

**Thread (802.15.4) — radio "selalu menyala" (always RX).**
Peran Leader/Router di Thread wajib mendengarkan terus-menerus, karena harus
mem-forward paket untuk node lain di mesh. Radio 802.15.4 meminta antena hampir
tanpa jeda → arbiter koeksistensi nyaris tidak punya slot untuk Wi-Fi → TCP
keluar mati.

**BLE — radio "bangun sebentar, tidur lama" (duty-cycled).**
BLE berbasis *connection event* terjadwal: radio bangun hanya saat slot koneksi
(mis. tiap 30–50 ms selama beberapa ratus µs, cukup untuk satu paket kecil),
lalu tidur sampai slot berikutnya. Di sela-sela itu antena bebas dipakai Wi-Fi.

Analoginya, dua orang berbagi satu telepon:

| | BLE | Thread |
|---|---|---|
| Pola pakai | telpon sebentar, taruh (terjadwal) | pegang telepon terus, takut ketinggalan panggilan |
| Slot untuk Wi-Fi | banyak (sisa waktu luang) | hampir tidak ada |

Wi-Fi sendiri juga bursty (radio aktif hanya saat ada paket), sehingga pasangan
BLE + Wi-Fi saling bergantian dengan mudah — itulah kenapa Week 16 mencapai
100 % publish.

Catatan menarik: kalau node Thread memakai peran **Sleepy End Device (SED)**
yang juga duty-cycled, ia seharusnya bisa hidup berdampingan dengan Wi-Fi.
Masalahnya gateway/leader **tidak boleh** SED — ia harus selalu RX untuk
melayani mesh. Inilah alasan arsitektur yang benar untuk Thread + Wi-Fi adalah
**dua chip terpisah** (border router khusus), sehingga tidak perlu rebutan antena.

**Kesimpulan kunci.** Masalahnya bukan "Thread" secara umum, melainkan **peran
yang dipaksa topologi mesh**: gateway harus Leader/Router (tidak boleh SED),
sehingga radio 802.15.4 wajib always-RX dan antena hampir tak pernah bebas untuk
Wi-Fi. Rantai sebab-akibatnya:

```
topologi mesh (Thread/Zigbee)
  → gateway harus Leader/Router (bukan SED)
  → radio 802.15.4 wajib always-RX
  → antena hampir tak pernah bebas untuk Wi-Fi
  → TCP keluar gagal (HTTP -1 / MQTT rc=-2)
```

Bukti pendukungnya konsisten: BLE yang **bukan mesh** (connection-based,
duty-cycled) berbagi antena nyaris gratis (98 %), dan SED yang juga duty-cycled
seharusnya bisa — tetapi gateway tak boleh SED. Konsekuensinya, Zigbee
Coordinator maupun Thread Leader akan kena masalah koeksistensi yang sama karena
perannya selalu-RX.

## 6 · Yang bisa dicoba bila menjumpai kegagalan ini

1. **HTTP (Week 13)** — tambahkan retry `http.POST()` beberapa kali per telemetri;
   karena tiap request independen, retry langsung menaikkan peluang `200`.
2. **MQTT (Week 15)** — jangan publish sebelum `mqtt.connected()`, dan pastikan
   `mqtt.connect()` sungguh-sungguh sukses; bila `rc=-2` terus, cek broker
   terjangkau (port, subnet, firewall) dulu sebelum menyalahkan koeksistensi.
3. **Kedua-duanya** — pakai server lokal (`http_sink.py` / `mqtt_broker.py`) agar
   RTT pendek sehingga TCP connect lebih sering menang airtime.
4. **Hindari kesimpulan prematur** — selalu bedakan *hop mana* yang gagal lewat
   counter per tahap (TX Thread vs RX Thread vs HTTP/MQTT), jangan menebak.

## Referensi

- `week13_thread_wifi_gateway/logserial.md` — log HTTP `-1`/`200` nyata.
- `week13_thread_wifi_gateway/README.md:364-419` — koeksistensi + tabel perbaikan.
- `week15_e2e_iot/logserial.md` — log MQTT `rc=-2` nyata.
- `week15_e2e_iot/README.md:339-379` — uji 3 AP + pembanding BLE.
- `logview-summary.md:73-75` — ringkasan koeksistensi Week 13/15/16.
