# Logview Summary — WSN-IoT Praktikum

Ringkasan hasil pengujian serial (board nyata) untuk Week 01–16.
Semua log memakai port **UART CH343 (1A86:55D3)**, bukan native USB (303A:1001).

## Pemetaan Board

| Node | Port UART |
|---|---|
| node1 | `/dev/ttyACM0` |
| node2 | `/dev/ttyACM2` |
| node3 | `/dev/ttyACM4` |
| gateway / C6 | `/dev/ttyACM6` |

## Ringkasan Tiap Minggu

| Week | Folder | Protokol | Jumlah Node | Peran (→ port) | Key Output (penanda sukses) |
|---|---|---|---|---|---|
| 01 | `week01_ble_p2p` | BLE P2P | 2 | Node1 Peripheral (`ttyACM0`) · Node2 Central (`ttyACM2`) | `Node2 terhubung (link P2P aktif)` + heartbeat `Status: H2 <-> H2 terhubung` |
| 02 | `week02_ble_p2p_data` | BLE P2P data | 2 | Node1 Server · Node2 Client | `TX ke Node2: Hello…` / `RX dari Node1: Hello…` (notify + write + echo) |
| 03 | `week03_ble_client_server` | BLE GATT read/write | 2 | Server · Client | `READ counter = …` / `WRITE perintah: ON` / `Perintah dari client: ON` |
| 04 | `week04_ble_telemetry` | BLE telemetry | 2 | Sensor · Monitor | `Notify: suhu = … C` / `Telemetry diterima: suhu = … C` |
| 05 | `week05_ble_multinode` | BLE multi-node | 3 | Central (`ttyACM0`) · NodeA (`ttyACM2`) · NodeB (`ttyACM4`) | `[NodeA] RX: A:n` / `[NodeB] RX: B:n` |
| 06 | `week06_ble_mesh` | BLE mesh relay | 3 | NodeA · NodeB (relay) · NodeC | `Terima dari A: … (diteruskan)` → `Pesan tiba (via A -> B -> C): …` |
| 07 | `week07_802154_p2p` | IEEE 802.15.4 raw | 2 | Node1 sender (0x0001) · Node2 receiver (0x0002) | `TX ke 0x0002: PING n` / `RX dari 0x0001: PING n` + `PONG` |
| 08 | `week08_zigbee_p2p` | Zigbee P2P | 2 | Coordinator (ZCZR) · End Device | `End device ter-binding!` + `Perintah: Lampu ON/OFF` |
| 09 | `week09_zigbee_multinode` | Zigbee multi-node | 3 | Coordinator · Light1 (ep10) · Light2 (ep11) | `Total 2 device.` + `-> Light 0x… ON/OFF` |
| 10 | `week10_zigbee_mesh` | Zigbee mesh | 3 | Coordinator · Router · End Device | `Total device ter-bind: 2` + `RouterLight/EndLight ON/OFF` |
| 11 | `week11_thread_p2p` | Thread P2P/IP | 2 | Node1 (Leader) · Node2 (Child) | `Attached as: Leader/Child` + `TX PING (multicast)` / `TX PONG` |
| 12 | `week12_thread_mesh` | Thread mesh | 3 | Node1 (Leader) · Node2 (Child) · Node3 (Child) | `TX multicast: NODE<n>:<count>` + `RX [mesh-local]: NODE<n>:…` |
| 13 | `week13_thread_wifi_gateway` | Thread → Wi-Fi/HTTP | 1 C6 (+1 H2 disimulasi) | C6 gateway Thread Leader + Wi-Fi (`ttyACM6`) | `Thread attached as: Leader` + `Forward via Wi-Fi → … HTTP …` |
| 14 | `week14_mqtt` | Wi-Fi / MQTT | 1 C6 | C6 client MQTT (`ttyACM6`) | `MQTT terhubung` + `TX MQTT` + `RX MQTT` |
| 15 | `week15_e2e_iot` | Thread → MQTT (E2E) | 1 C6 (+1 H2 disimulasi) | C6 Thread Leader + Wi-Fi + MQTT (`ttyACM6`) | `Thread attached as: Leader` + `Publish MQTT`/`rc=-2` |
| 16 | `week16_comparative` | BLE → MQTT | 1 C6 (+1 H2 disimulasi) | C6 BLE client + Wi-Fi + MQTT (`ttyACM6`) | `MQTT terhubung` + `Publish MQTT […]` 100 % |

## Detail Tiap Folder (logserial.md)

| Week | File log | Topologi/arah data |
|---|---|---|
| 01 | `week01_ble_p2p/logserial.md` | Advertising → scan → connect (1 hop) |
| 02 | `week02_ble_p2p_data/logserial.md` | Notify TX + WRITE RX dua arah (echo) |
| 03 | `week03_ble_client_server/logserial.md` | Client read counter 2s, write "ON" 5s |
| 04 | `week04_ble_telemetry/logserial.md` | Sensor push suhu 1s ke monitor |
| 05 | `week05_ble_multinode/logserial.md` | 2 peripheral → 1 central (hub) |
| 06 | `week06_ble_mesh/logserial.md` | A → B → C (transparent forwarding) |
| 07 | `week07_802154_p2p/logserial.md` | Raw frame PING/PONG dua arah |
| 08 | `week08_zigbee_p2p/logserial.md` | Coordinator switch → 1 light |
| 09 | `week09_zigbee_multinode/logserial.md` | Coordinator switch → 2 light |
| 10 | `week10_zigbee_mesh/logserial.md` | Coordinator → router + end device (mesh) |
| 11 | `week11_thread_p2p/logserial.md` | Child multicast PING → Leader unicast PONG |
| 12 | `week12_thread_mesh/logserial.md` | 3 node multicast penuh (mesh) |
| 13 | `week13_thread_wifi_gateway/logserial.md` | Sensor (simulasi) → Thread → Wi-Fi → HTTP POST |
| 14 | `week14_mqtt/logserial.md` | C6 publish + subscribe dua arah ke broker |
| 15 | `week15_e2e_iot/logserial.md` | Sensor (simulasi) → Thread → Wi-Fi → MQTT |
| 16 | `week16_comparative/logserial.md` | Sensor (simulasi) → BLE → Wi-Fi → MQTT |

## Catatan Teknis

- **BLE (Week 02–06)**: setiap server memanggil `pService->start()` sebelum
  advertising (perbaikan bug; tanpa ini characteristic tidak ter-register dan
  client mencetak `Characteristic tidak ditemukan`).
- **Zigbee (Week 08–10)**: flash di-`erase` penuh sebelum upload agar state
  network/NVS bersih. Short address beberapa device tercetak `0xFFFF` saat binding
  table belum mencatat short address (perintah tetap terkirim).
- **Thread (Week 11–12)**: dataset + mesh-local prefix dipaksa identik di semua
  node agar multicast mesh-local (`ff03::/16`) sampai lintas node. Peringatan
  `E (…) OT_STATE: Failed to get the active dataset` bersifat non-fatal.
- **Week 07**: FCS dihitung hardware; pada sisi RX dua byte FCS diganti RSSI+LQI.
- **Week 13–16 (C6)**: memakai board **ESP32-C6** (radio 802.15.4 + BLE + Wi-Fi).
  Sensor H2 **disimulasikan** di firmware gateway (tidak ada board H2 fisik).
  Broker MQTT lokal Mosquitto di `192.168.1.5:1884`, HTTP sink di `:8080`.
  Wi-Fi `SprH-3`.
- **Koeksistensi (Week 13 & 15)**: Thread + Wi-Fi di satu antena membuat TCP
  keluar sangat rapuh (Week 13 `HTTP -1` mayoritas; Week 15 MQTT `rc=-2`, 0 %).
  Sebaliknya **Week 16 (BLE + Wi-Fi)** nyaris tanpa ongkos koeksistensi (100 %).
- Baris `ESP-ROM:esp32h2-…` / `ESP-ROM:esp32c6-…` s/d `entry …` di tiap log
  adalah log ROM boot (reset), bukan bagian program aplikasi.
