```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
               IoT COMMUNICATION LAB
      MODUL 00 — Blinky ESP32-H2 (Warm-up)

     Waveshare ESP32-H2-DEV-KIT-N4 · Basic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 1 · Informasi Modul

| Field | Nilai |
|---|---|
| Minggu / Modul | 00 |
| Misi | Memastikan toolchain PlatformIO, board, dan jalur flash bekerja sebelum modul komunikasi dimulai |
| Platform | Waveshare ESP32-H2-DEV-KIT-N4 (ESP32-H2-MINI-1, Arduino core 3.x) + PlatformIO |
| Durasi | 1 × 50 menit |
| Mode | Single node — LED RGB onboard berkedip |
| Level | Basic |
| Instrumen | Serial Monitor 115200 baud |

## 2 · Struktur Proyek

```
week0_blinky/
├── platformio.ini
└── src/
    └── main.cpp
```

## 3 · Capaian Pembelajaran

1. Menjelaskan posisi ESP32-H2 dalam ekosistem ESP32 (RISC-V, BLE + IEEE 802.15.4) dan kemiripan pinout Waveshare ESP32-H2-DEV-KIT-N4 dengan ESP32-H2-DevKitM-1.
2. Membuat proyek PlatformIO dengan pioarduino (platform resmi belum menyediakan board ESP32-H2).
3. Mem-flash firmware dan memverifikasi LED RGB onboard (WS2812) pada GPIO8 berkedip.
4. Membaca output Serial Monitor sebagai verifikasi program berjalan.

## 4 · Perangkat

- 1× Waveshare ESP32-H2-DEV-KIT-N4 (LED RGB WS2812 onboard pada GPIO8)
- 1× kabel USB-C

## 5 · Build & Flash

```bash
pio run -t upload -e node
pio device monitor -e node
```

## 6 · Hasil yang Diharapkan

LED RGB onboard (WS2812 pada GPIO8) menyala-merah-mati dengan periode 1 detik,
dan Serial Monitor menampilkan pesan startup sekali. (Bisa ubah warna bebas via
`strip.Color(r, g, b)` — WS2812 bukan LED digital biasa.)
