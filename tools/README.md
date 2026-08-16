# Tools

## `mqtt_broker.py` — broker MQTT lokal untuk lab

Broker MQTT 3.1.1 minimal, **Python murni, tanpa install apa pun** (tidak butuh
`sudo`, tidak butuh paket eksternal). Mendukung yang dipakai Modul 14–16:
CONNECT, PUBLISH (QoS 0/1), SUBSCRIBE (wildcard `+` dan `#`), retained message,
PINGREQ, dan DISCONNECT.

**Kapan ini dipakai.** Banyak jaringan kampus/kantor memblokir port 1883 keluar,
sehingga `test.mosquitto.org` tidak terjangkau. Gejalanya di ESP32-C6:

```
[E][NetworkManager.cpp:138] hostByName(): DNS Failed for 'test.mosquitto.org'
[E][NetworkClient.cpp:252] connect(): connect on fd 48, errno: 118, "Host is unreachable"
Konek MQTT test.mosquitto.org:1883 ... Gagal (rc=-2)
```

Kalau itu yang terjadi, jalankan broker ini di laptop dan arahkan `MQTT_BROKER`
pada firmware ke **alamat IP laptop** (bukan `localhost` — board ada di
perangkat lain).

### Menjalankan

```bash
# 1. cari IP laptop di Wi-Fi yang sama dengan board
ip -4 addr show wlp99s0 | grep inet        # Linux
# ipconfig                                  # Windows

# 2. jalankan broker
python3 tools/mqtt_broker.py
```

Output broker sekaligus berfungsi sebagai pengganti `mosquitto_sub -v`: setiap
PUBLISH yang masuk dicetak lengkap dengan timestamp, topic, payload, QoS, dan
client pengirimnya.

```
[   0.000] broker siap di 0.0.0.0:1883
[   3.114] CONNECT   id=esp32c6-gateway from 192.168.110.91:52233
[   6.201] PUBLISH   praktikum/h2/telemetri suhu:25.2   (qos=0 retain=0 from=esp32c6-gateway)
```

### Menyesuaikan firmware

Pada `src/.../main.cpp` Modul 14/15/16:

```cpp
const char *MQTT_BROKER = "192.168.110.74";   // IP laptop, bukan localhost
const uint16_t MQTT_PORT = 1883;
```

### Publish/subscribe dari PC

Tanpa `mosquitto-clients` (yang butuh `sudo apt install`), pakai `paho-mqtt`
di virtualenv:

```bash
python3 -m venv .venv && .venv/bin/pip install paho-mqtt

# subscriber (pengganti mosquitto_sub)
.venv/bin/python - <<'EOF'
import paho.mqtt.client as m
c = m.Client(m.CallbackAPIVersion.VERSION2)
c.on_message = lambda cl, u, msg: print(msg.topic, msg.payload.decode())
c.connect("127.0.0.1", 1883); c.subscribe("praktikum/#"); c.loop_forever()
EOF

# publisher (pengganti mosquitto_pub)
.venv/bin/python -c "
import paho.mqtt.client as m
c = m.Client(m.CallbackAPIVersion.VERSION2); c.connect('127.0.0.1',1883)
c.publish('praktikum/h2/perintah','LED_ON'); c.disconnect()"
```

### Batasan yang perlu disebut di laporan

- Tidak ada autentikasi, TLS, persistent session, atau last-will.
- QoS 1 di-*ack* tetapi tidak ada penyimpanan/pengiriman ulang; QoS 2 tidak didukung.
- Ditujukan untuk lab di satu LAN, **bukan** untuk produksi.

Bila memakai broker ini alih-alih `test.mosquitto.org`, tulis itu di bagian
konfigurasi laporan — hasil pengukuran latency akan jauh lebih kecil karena
tidak melewati Internet, dan itu harus dinyatakan sebagai kondisi ukur.
