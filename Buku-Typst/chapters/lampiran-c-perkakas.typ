// ============================================================================
// Lampiran C — Perkakas Pendukung
// Sumber: tools/README.md pada akar repositori WSN-IOT-prak; listing kode
//         dibaca langsung dari assets/code/tools/.
// ============================================================================

#import "@preview/orange-book:0.7.1": chapter
#import "../lib/callouts.typ": penting, peringatan, tip, catatan
#import "../lib/helpers.typ": tbl, th, kode, kode-berkas, sumber-kode, gh, gh-folder, keluaran, diagram

#chapter("Perkakas Pendukung", l: "bab:lampiran-perkakas")

Lampiran ini memuat dua perkakas Python yang dipakai berulang pada modul
integrasi (M13 sampai M16). Keduanya berjalan di laptop praktikan, bukan di
board, dan tidak membutuhkan pemasangan paket eksternal maupun hak akses
administrator --- syarat yang sengaja dipertahankan agar dapat dijalankan di
komputer laboratorium mana pun.

#sumber-kode("tools", ("mqtt_broker.py", "http_sink.py"))

== Mengapa Perkakas Ini Diperlukan

Banyak jaringan kampus dan kantor memblokir port 1883 keluar, sehingga broker
publik `test.mosquitto.org` tidak terjangkau. Gejalanya di ESP32-C6 berupa
kegagalan resolusi DNS diikuti `Host is unreachable`.

#keluaran("[E][NetworkManager.cpp:138] hostByName(): DNS Failed for 'test.mosquitto.org'
[E][NetworkClient.cpp:252] connect(): connect on fd 48, errno: 118, \"Host is unreachable\"
Konek MQTT test.mosquitto.org:1883 ... Gagal (rc=-2)")

Hal serupa terjadi pada `httpbin.org` di Modul 13, yang tampak sebagai
`HTTP -1`. Kedua perkakas di lampiran ini menggantikan layanan publik tersebut
dengan layanan lokal di laptop, sehingga praktikum tetap dapat dijalankan dan
--- yang lebih penting --- keberhasilan tiap hop dapat dibuktikan dari sisi
penerima, bukan hanya dari sisi pengirim.

#catatan[
  Bila memakai perkakas lokal ini alih-alih layanan publik, tulis hal itu di
  bagian konfigurasi laporan. Hasil pengukuran latency akan jauh lebih kecil
  karena tidak melewati Internet, dan kondisi ukur itu harus dinyatakan secara
  eksplisit agar angkanya tidak salah dibandingkan.
]

== Broker MQTT Lokal --- `mqtt_broker.py`

Broker MQTT 3.1.1 minimal, ditulis dalam Python murni tanpa paket eksternal.
Fitur yang didukung adalah yang dipakai Modul 14 sampai 16: CONNECT, PUBLISH
(QoS 0 dan 1), SUBSCRIBE (termasuk wildcard `+` dan `#`), retained message,
PINGREQ, dan DISCONNECT.

=== Menjalankan

#keluaran("# 1. cari IP laptop di Wi-Fi yang sama dengan board
ip -4 addr show wlp99s0 | grep inet        # Linux
# ipconfig                                  # Windows

# 2. jalankan broker
python3 tools/mqtt_broker.py")

Keluaran broker sekaligus berfungsi sebagai pengganti `mosquitto_sub -v`:
setiap PUBLISH yang masuk dicetak lengkap dengan timestamp, topic, payload,
QoS, dan client pengirimnya.

#keluaran("[   0.000] broker siap di 0.0.0.0:1883
[   3.114] CONNECT   id=esp32c6-gateway from 192.168.110.91:52233
[   6.201] PUBLISH   praktikum/h2/telemetri suhu:25.2   (qos=0 retain=0 from=esp32c6-gateway)")

=== Menyesuaikan Firmware

Pada `src/.../main.cpp` Modul 14, 15, atau 16, arahkan broker ke *alamat IP
laptop* --- bukan `localhost`, karena board berada di perangkat lain.

#kode(```cpp
const char *MQTT_BROKER = "192.168.110.74";   // IP laptop, bukan localhost
const uint16_t MQTT_PORT = 1883;
```.text,
  [Mengarahkan firmware ke broker MQTT lokal],
  "lst:lampc-broker-url",
)

=== Publish dan Subscribe dari PC

Tanpa `mosquitto-clients` (yang membutuhkan pemasangan sistem), gunakan
`paho-mqtt` di dalam virtualenv.

#keluaran("python3 -m venv .venv && .venv/bin/pip install paho-mqtt")

#keluaran("# subscriber (pengganti mosquitto_sub)
.venv/bin/python - <<'EOF'
import paho.mqtt.client as m
c = m.Client(m.CallbackAPIVersion.VERSION2)
c.on_message = lambda cl, u, msg: print(msg.topic, msg.payload.decode())
c.connect(\"127.0.0.1\", 1883); c.subscribe(\"praktikum/#\"); c.loop_forever()
EOF

# publisher (pengganti mosquitto_pub)
.venv/bin/python -c \"
import paho.mqtt.client as m
c = m.Client(m.CallbackAPIVersion.VERSION2); c.connect('127.0.0.1',1883)
c.publish('praktikum/h2/perintah','LED_ON'); c.disconnect()\"")

=== Batasan yang Perlu Disebut di Laporan

- Tidak ada autentikasi, TLS, persistent session, maupun last-will.
- QoS 1 di-_ack_ tetapi tidak ada penyimpanan atau pengiriman ulang; QoS 2
  tidak didukung.
- Ditujukan untuk lab di satu LAN, *bukan* untuk produksi.

=== Listing

#kode-berkas("tools/mqtt_broker.py",
  [`tools/mqtt_broker.py` --- broker MQTT 3.1.1 minimal berbasis Python],
  "lst:lampc-mqtt-broker",
  pecah: true,
)

== Penerima HTTP Lokal --- `http_sink.py`

Server HTTP sederhana yang mendengarkan POST di `0.0.0.0:8080`, mencetak tiap
POST yang masuk beserta timestamp, lalu membalas HTTP 200 dan JSON. Perkakas
ini menggantikan `httpbin.org` pada Modul 13 sekaligus menjadi bukti bahwa hop
Wi-Fi/HTTP benar-benar sampai.

#keluaran("python3 tools/http_sink.py")

#keluaran("[   0.000] http_sink siap di 0.0.0.0:8080 (POST -> HTTP 200)
[ 480.308] #1    POST /post from 192.168.1.39  ->  {\"sensor\":\"h2\",\"data\":\"suhu:23.1\"}")

Arahkan `SERVER_URL` pada `src/c6_gateway/main.cpp` ke IP laptop beserta port
8080.

#kode(```cpp
const char *SERVER_URL = "http://192.168.1.5:8080/post";
```.text,
  [Mengarahkan gateway Modul 13 ke penerima HTTP lokal],
  "lst:lampc-http-url",
)

#catatan[
  Berkas `http_sink.py` pada folder `tools/` identik dengan salinan yang
  disertakan di `week13_thread_wifi_gateway/`, sehingga listing-nya tidak
  diulang di sini. Isi lengkapnya dimuat pada @lst:m13-http-sink.
]
