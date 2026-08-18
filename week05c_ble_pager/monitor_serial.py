#!/usr/bin/env python3
"""Monitor ketiga pager sekaligus untuk Modul 05C.

Menampilkan aktivitas pager 101, 102, dan 103 dalam SATU jendela terminal
dengan timestamp bersama, sehingga terlihat langsung bahwa hanya pager yang
dipanggil yang bereaksi — bukti bahwa perintah kasir bersifat unicast, bukan
broadcast. Hal itu sulit dinilai bila tiap pager dibuka di terminal terpisah.

    python3 week05c_ble_pager/monitor_serial.py
    python3 week05c_ble_pager/monitor_serial.py --log sesi1.txt
    python3 week05c_ble_pager/monitor_serial.py --port P103=/dev/ttyACM8

TERMINAL KASIR TIDAK DIBUKA DI SINI. Controller ada di /dev/ttyACM0 dan
dipegang cutecom (baud 115200, akhir baris LF), karena kasir perlu mengetik
perintah sedangkan skrip ini hanya membaca. Membuka port yang sama dari dua
program sekaligus membuat keduanya berebut data.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C — ringkasan jumlah baris per board dicetak saat keluar.

DUA HAL SOAL DTR/RTS pada board Waveshare ESP32-H2 (rangkaian auto program:
RTS → EN, DTR → IO9, pin yang sama dengan tombol ACK pager):

1. Membuka port **me-reset board**, sama seperti `pio device monitor`. Kernel
   mengaktifkan DTR/RTS saat `open()`, sebelum program sempat mencegahnya, dan
   itu tidak bisa dihindari dari sisi Python. Karena itu jalankan monitor ini
   **lebih dulu**, baru amati — banner startup ketiga board justru ikut
   terekam. Jangan membukanya di tengah panggilan yang sedang berjalan —
   pager yang ter-reset memutus koneksinya ke kasir.
2. Setelah terbuka, kedua jalur ditahan **tidak aktif** (`dtr=False`,
   `rts=False`). Ini wajib: DTR yang dibiarkan aktif menahan IO9 tetap LOW,
   dan pager akan membaca tombol ACK seolah-olah ditekan terus.
"""
import argparse
import signal
import sys
import threading
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial belum terpasang. Jalankan: pip install pyserial")

DEFAULT_PORTS = [
    ("P101", "/dev/ttyACM2", "\033[36m"),  # cyan
    ("P102", "/dev/ttyACM4", "\033[33m"),  # kuning
    ("P103", "/dev/ttyACM6", "\033[35m"),  # magenta
]
RESET = "\033[0m"
DIM = "\033[2m"

print_lock = threading.Lock()
counts = {}
stop = threading.Event()
t0 = time.time()


def show(name, color, text, use_color, logfile):
    """Cetak satu baris dengan timestamp bersama, aman dari tumpang tindih."""
    stamp = f"{time.time() - t0:8.3f}"
    plain = f"[{stamp}] {name:<7} | {text}"
    with print_lock:
        if use_color:
            print(f"{DIM}[{stamp}]{RESET} {color}{name:<7}{RESET} | {text}", flush=True)
        else:
            print(plain, flush=True)
        if logfile:
            logfile.write(plain + "\n")
            logfile.flush()


def open_port(port, baud):
    """Buka port dengan DTR/RTS ditahan tidak aktif.

    Board tetap ter-reset saat open() (lihat catatan di docstring modul), tetapi
    setelah itu IO9 dibiarkan tinggi sehingga tombol tidak terbaca tertekan.
    """
    s = serial.Serial()
    s.port = port
    s.baudrate = baud
    s.timeout = 0.2
    s.dtr = False
    s.rts = False
    s.open()
    return s


def reader(name, port, color, baud, use_color, logfile):
    counts[name] = 0
    try:
        ser = open_port(port, baud)
    except Exception as e:
        show(name, color, f"!! tidak bisa dibuka: {e}", use_color, logfile)
        return

    show(name, color, f"-- tersambung ke {port} @ {baud} --", use_color, logfile)
    buf = b""
    while not stop.is_set():
        try:
            data = ser.read(256)
        except Exception as e:
            show(name, color, f"!! port terputus: {e}", use_color, logfile)
            break
        if not data:
            continue
        buf += data
        # Pesan dipecah per baris agar output tiga board tidak saling menyisip
        # di tengah kalimat.
        *lines, buf = buf.split(b"\n")
        for line in lines:
            text = line.decode("utf-8", "replace").rstrip("\r")
            if text.strip():
                counts[name] += 1
                show(name, color, text, use_color, logfile)
    ser.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", action="append", metavar="NAMA=/dev/ttyACMx",
                    help="ganti/tambah pager; boleh diulang (mis. P104=/dev/ttyACM8)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--log", metavar="FILE", help="simpan juga ke file teks")
    ap.add_argument("--no-color", action="store_true")
    args = ap.parse_args()

    ports = {name: (port, color) for name, port, color in DEFAULT_PORTS}
    for item in args.port or []:
        if "=" not in item:
            sys.exit(f"format --port salah: {item!r} (harus NAMA=/dev/ttyACMx)")
        name, port = item.split("=", 1)
        _, color = ports.get(name.upper(), (None, "\033[35m"))
        ports[name.upper()] = (port, color)

    use_color = not args.no_color and sys.stdout.isatty()
    logfile = open(args.log, "w") if args.log else None

    # SIGTERM (mis. dijalankan lewat `timeout 30 ...`) diperlakukan sama dengan
    # Ctrl-C supaya ringkasan tetap tercetak.
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt))

    print(f"Monitor 3 pager — kasir dipantau terpisah lewat cutecom · Ctrl-C untuk berhenti"
          f"{' · log: ' + args.log if args.log else ''}")
    print("-" * 60)

    threads = [threading.Thread(target=reader,
                                args=(name, port, color, args.baud, use_color, logfile),
                                daemon=True)
               for name, (port, color) in ports.items()]
    for t in threads:
        t.start()

    try:
        while any(t.is_alive() for t in threads):
            time.sleep(0.2)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        for t in threads:
            t.join(timeout=1.0)
        print("\n" + "-" * 60)
        print(f"Durasi: {time.time() - t0:.1f} s")
        for name in ports:
            print(f"  {name:<7} : {counts.get(name, 0)} baris")
        if logfile:
            logfile.close()
            print(f"Log tersimpan di {args.log}")


if __name__ == "__main__":
    main()
