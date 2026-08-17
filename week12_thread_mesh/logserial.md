# Log Serial — Week 12 (Thread Mesh)

Hasil aktual dari board nyata. Baud 115200, tiga board ESP32-H2.

## Board & Port

| Node | Peran | Port serial (UART) |
|---|---|---|
| Node1 | Thread (Leader) | `/dev/ttyACM0` |
| Node2 | Thread (Child) | `/dev/ttyACM2` |
| Node3 | Thread (Child) | `/dev/ttyACM4` |

Group multicast `ff03::abcd`, port UDP 5050, nama network `ESP_OT_MESH`.

## Node1 — `/dev/ttyACM0`

```
ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node1 (Thread) starting...
Attached as: Leader
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE1:1
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:1
TX multicast: NODE1:2
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:1
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:2
TX multicast: NODE1:3
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:2
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:3
TX multicast: NODE1:4
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:3
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:4
TX multicast: NODE1:5
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:4
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:5
TX multicast: NODE1:6
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:5
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:6
```

## Node2 — `/dev/ttyACM2`

```
ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node2 (Thread) starting...
Attached as: Child
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE2:1
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:2
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:1
TX multicast: NODE2:2
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:3
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:2
TX multicast: NODE2:3
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:3
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:4
TX multicast: NODE2:4
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:4
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:5
TX multicast: NODE2:5
RX [fdde:ad00:beef:0:15ad:f4e3:d0d9:7cd6]: NODE3:5
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:6
TX multicast: NODE2:6
```

## Node3 — `/dev/ttyACM4`

```
ESP-ROM:esp32h2-20221101
Build:Nov  1 2022
rst:0x1 (POWERON),boot:0xc (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x408460f0,len:0x1214
load:0x4083c2d0,len:0xd6c
load:0x4083efd0,len:0x2f7c
entry 0x4083c2d0
Node3 (Thread) starting...
E (20365) OT_STATE: handle_ot_role_change(105): Failed to get the active dataset
Attached as: Child
Bergabung ke mesh, siap kirim/terima.
TX multicast: NODE3:1
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:2
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:2
TX multicast: NODE3:2
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:3
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:3
TX multicast: NODE3:3
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:4
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:4
TX multicast: NODE3:4
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:5
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:5
TX multicast: NODE3:5
RX [fdde:ad00:beef:0:6f99:51e5:8c04:5813]: NODE1:6
RX [fdde:ad00:beef:0:2375:2134:ab58:2cec]: NODE2:6
```

## Catatan

- Tiga node memakai dataset Thread identik (`ESP_OT_MESH`, channel 15, PAN 0xABCD)
  dan mesh-local prefix yang dipaksa sama agar multicast mesh-local sampai lintas node.
- Peran: Node1 **Leader**, Node2 **Child**, Node3 **Child**.
- Tiap node mengirim `NODE<n>:<count>` via UDP multicast (`ff03::abcd:5050`) tiap
  5 detik, dan menerima pesan dari dua node lainnya.
- Alamat IPv6 pada `RX […]` adalah Mesh-Local EID node pengirim:
  Node1 `…6f99:51e5:8c04:5813`, Node2 `…2375:2134:ab58:2cec`, Node3 `…15ad:f4e3:d0d9:7cd6`.
- `NODE1:1` tidak tampak di log Node2/Node3 karena dikirim tepat saat node lain
  masih menyelesaikan join group multicast; pesan berikutnya saling terkirim penuh.
- Pesan `E (…) OT_STATE: … Failed to get the active dataset` adalah peringatan
  non-fatal saat transisi role, tidak mengganggu komunikasi.
- Baris `ESP-ROM:…` s/d `entry …` adalah log ROM boot, keluar sekali saat reset.
