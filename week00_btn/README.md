```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 00B — Tombol BOOT → LED (Warm-up)

     Waveshare ESP32-H2-DEV-KIT-N4 · Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 00B (lanjutan dari `week00_blinky`) |
| Misi | Menambahkan **input** pada board: LED tidak lagi berkedip sendiri, tetapi mengikuti penekanan tombol |
| Platform | Waveshare ESP32-H2-DEV-KIT-N4 (ESP32-H2-MINI-1, Arduino core 3.x) + PlatformIO |
| Durasi | 1 × 50 menit |
| Mode | Single node — tombol BOOT menyalakan LED RGB onboard |
| Level | Basic |
| Instrumen | Serial Monitor 115200 baud |

## 2 · Struktur Proyek

```
week00_btn/
├── platformio.ini
└── src/
    └── main.cpp
```

## 3 · Capaian Pembelajaran

1. Membaca digital input pada ESP32-H2 dengan `pinMode(..., INPUT_PULLUP)` dan `digitalRead()`.
2. Menjelaskan logika **active low**: tombol tidak ditekan = `HIGH`, ditekan = `LOW`.
3. Menghubungkan input (tombol) ke output (LED RGB WS2812) di dalam satu `loop()`.
4. Membaca perubahan status pada Serial Monitor tanpa membanjiri log.

## 4 · Perangkat & Pin

- 1× Waveshare ESP32-H2-DEV-KIT-N4
- 1× kabel USB-C

| Fungsi | GPIO | Keterangan (dari skematik board) |
|---|---|---|
| LED RGB WS2812 | GPIO8 | `RGB_CTRL`, satu pixel, order byte RGB |
| Tombol BOOT | GPIO9 | `Key2`, ke GND saat ditekan, pull-up 10K di board → **active low** |

Tidak ada wiring tambahan — tombol dan LED sudah terpasang di board.

## 5 · Build & Flash

```bash
pio run -d week00_btn -e node -t upload
pio device monitor -e node
```

> **Catatan** — GPIO9 juga merupakan strapping pin mode download. Menekan
> tombol **saat board reset/boot** akan membuat board masuk mode flash, bukan
> menjalankan program. Tekan tombol hanya setelah program berjalan.

## 6 · Hasil yang Diharapkan

LED RGB onboard mati saat tombol dilepas dan menyala hijau selama tombol BOOT
ditahan. Serial Monitor mencetak satu baris tiap kali status berubah:

```
Tombol BOOT (GPIO9) -> LED RGB WS2812 (GPIO8) dimulai
Tombol DITEKAN  -> LED nyala
Tombol DILEPAS  -> LED mati
```

## 7 · Challenge

- **CH-1 — Toggle.** Ubah agar LED berganti nyala/mati tiap kali tombol
  *ditekan* (deteksi tepi turun), bukan mengikuti selama ditahan.
- **CH-2 — Ganti warna.** Setiap penekanan menggeser warna: merah → hijau →
  biru → merah lagi.
- **CH-3 — Debounce.** Hapus `delay(20)`, amati apakah muncul cetakan ganda
  pada satu penekanan, lalu ganti dengan debounce berbasis `millis()`.
