#!/usr/bin/env python3
"""Monitor ketiga node 802.15.4 sekaligus untuk Modul 07.

Membaca Node1, Node2, dan Node3 dari SATU komputer dalam satu jendela dengan
timestamp bersama, lalu mencetak ringkasan per link (pengirim -> penerima):
jumlah frame terkirim dan diterima, loss, serta RSSI dan LQI. Dengan satu
sumbu waktu, gejala seperti PONG yang bertabrakan pada broadcast (04-e) atau
node promiscuous yang ikut menerima unicast (05-d) langsung terlihat.

    python week07_802154_p2p/monitor_serial.py                  # deteksi otomatis
    python week07_802154_p2p/monitor_serial.py --duration 30    # berhenti sendiri
    python week07_802154_p2p/monitor_serial.py --log sesi1.txt
    python week07_802154_p2p/monitor_serial.py --port COM5 --port COM11 --port COM13
    python3 week07_802154_p2p/monitor_serial.py --port /dev/ttyACM0 --port /dev/ttyACM2

Tanpa --port, skrip memakai semua port jembatan UART CH343 (1A86:55D3) yang
terpasang. Nama node (Node1/Node2/Node3) dikenali dari banner saat boot, jadi
urutan port tidak perlu diingat. Port USB native (303A:1001) sengaja tidak
dipakai: Serial firmware ini keluar lewat UART.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C, atau pakai --duration — ringkasan dicetak saat keluar.

SOAL RESET: tiap board di-reset sekali saat port dibuka (RTS -> EN, dengan DTR
ditahan tidak aktif agar IO9 tetap HIGH dan board boot normal), supaya banner
terekam dan hitungan PING dimulai dari 1 di semua node. Pakai --no-reset untuk
mengamati board yang sedang berjalan tanpa mengganggunya.

Hitungan loss dihitung dari log itu sendiri, jadi frame terakhir yang dikirim
tepat sebelum monitor berhenti bisa tercatat hilang — abaikan selisih satu.
"""
import argparse
import os
import re
import signal
import sys
import threading
import time
from collections import defaultdict

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit("pyserial belum terpasang. Jalankan: pip install pyserial")

CH343_VID, CH343_PID = 0x1A86, 0x55D3
COLORS = ["\033[36m", "\033[33m", "\033[35m", "\033[32m", "\033[34m"]
RESET = "\033[0m"
DIM = "\033[2m"

# Format log firmware week07 (lihat src/nodeX/main.cpp)
RE_BANNER = re.compile(r"^(Node\d+) \(")
RE_ADDR = re.compile(r"short addr 0x([0-9A-Fa-f]{4})")
RE_TX = re.compile(r"^TX (?:balasan )?ke 0x([0-9A-Fa-f]{4}): (\w+)")
RE_RX = re.compile(r"^RX dari 0x([0-9A-Fa-f]{4})(?: \(ke 0x([0-9A-Fa-f]{4}), PAN 0x[0-9A-Fa-f]{4}\))?"
                   r": (\w+).*?(?:\[RSSI (-?\d+) dBm, LQI (\d+)\])?$")

print_lock = threading.Lock()
stop = threading.Event()
t0 = time.time()


class Node:
    def __init__(self, port, color):
        self.port = port
        self.color = color
        self.name = port          # diganti "NodeN" begitu banner terbaca
        self.addr = None          # short address dari banner
        self.lines = 0


# tx[(src, dst, jenis)] = jumlah; rx[(src, penerima, jenis)] = [rssi...], [lqi...]
tx = defaultdict(int)
rx = defaultdict(lambda: ([], []))
rx_overheard = defaultdict(int)   # frame yang bukan untuk penerimanya (promiscuous)


def show(node, text, use_color, logfile):
    """Cetak satu baris dengan timestamp bersama, aman dari tumpang tindih."""
    stamp = f"{time.time() - t0:8.3f}"
    plain = f"[{stamp}] {node.name:<6} | {text}"
    with print_lock:
        if use_color:
            print(f"{DIM}[{stamp}]{RESET} {node.color}{node.name:<6}{RESET} | {text}", flush=True)
        else:
            print(plain, flush=True)
        if logfile:
            logfile.write(plain + "\n")
            logfile.flush()


def parse(node, text):
    """Ambil nama/alamat node dari banner, lalu catat TX/RX untuk ringkasan."""
    m = RE_BANNER.match(text)
    if m:
        node.name = m.group(1)
        return
    m = RE_ADDR.search(text)
    if m:
        node.addr = int(m.group(1), 16)
        return
    if node.addr is None:
        return
    m = RE_TX.match(text)
    if m:
        tx[(node.addr, int(m.group(1), 16), m.group(2))] += 1
        return
    m = RE_RX.match(text)
    if m:
        src = int(m.group(1), 16)
        kind = m.group(3)
        dst = int(m.group(2), 16) if m.group(2) else node.addr
        if dst not in (node.addr, 0xFFFF):
            rx_overheard[(src, node.addr, dst, kind)] += 1
        rssi, lqi = rx[(src, node.addr, kind)]
        if m.group(4) is not None:
            rssi.append(int(m.group(4)))
            lqi.append(int(m.group(5)))
        else:
            rssi.append(None)
            lqi.append(None)


def open_port(port, baud, do_reset):
    """Buka port dengan DTR/RTS tidak aktif; opsional reset board lewat RTS -> EN."""
    s = serial.Serial()
    s.port = port
    s.baudrate = baud
    s.timeout = 0.2
    s.dtr = False
    s.rts = False
    s.open()
    if do_reset:
        s.rts = True          # EN LOW (DTR tidak aktif -> IO9 HIGH -> boot normal)
        time.sleep(0.1)
        s.rts = False
    return s


def reader(node, baud, do_reset, use_color, logfile):
    try:
        ser = open_port(node.port, baud, do_reset)
    except Exception as e:
        show(node, f"!! tidak bisa dibuka: {e}", use_color, logfile)
        return
    show(node, f"-- tersambung ke {node.port} @ {baud} --", use_color, logfile)
    buf = b""
    while not stop.is_set():
        try:
            data = ser.read(256)
        except Exception as e:
            show(node, f"!! port terputus: {e}", use_color, logfile)
            break
        if not data:
            continue
        buf += data
        # Dipecah per baris agar output tiga board tidak saling menyisip.
        *lines, buf = buf.split(b"\n")
        for line in lines:
            text = line.decode("utf-8", "replace").rstrip("\r")
            if not text.strip():
                continue
            node.lines += 1
            parse(node, text)
            show(node, text, use_color, logfile)
    ser.close()


def detect_ports():
    return sorted(p.device for p in list_ports.comports()
                  if p.vid == CH343_VID and p.pid == CH343_PID)


def fmt_stats(values):
    vals = [v for v in values if v is not None]
    if not vals:
        return "-"
    return f"{sum(vals) / len(vals):6.1f} ({min(vals)}..{max(vals)})"


def summary(nodes, out):
    names = {n.addr: n.name for n in nodes if n.addr is not None}
    label = lambda a: f"{names.get(a, '?')}(0x{a:04X})" if a != 0xFFFF else "broadcast"

    out(f"\nDurasi: {time.time() - t0:.1f} s")
    for n in nodes:
        addr = f"0x{n.addr:04X}" if n.addr is not None else "?"
        out(f"  {n.name:<6} {addr:<7} {n.port:<14} {n.lines} baris")

    out("\nLink (pengirim -> penerima)      jenis  kirim  terima   loss   RSSI dBm rata2 (min..max)   LQI rata2 (min..max)")
    out("-" * 112)
    receivers = [n.addr for n in nodes if n.addr is not None]
    keys = set(k for k in rx) | set((s, r, kind) for (s, d, kind) in tx
                                    for r in receivers if r != s and (d == r or d == 0xFFFF))
    for src, rcv, kind in sorted(keys):
        sent = tx.get((src, rcv, kind), 0) + tx.get((src, 0xFFFF, kind), 0)
        rssi, lqi = rx.get((src, rcv, kind), ([], []))
        got = len(rssi)
        if sent:
            loss = f"{100.0 * (sent - got) / sent:5.1f}%" if got <= sent else "  n/a"
            sent_s = str(sent)
        else:
            loss, sent_s = "  n/a", "-"
        link = f"{label(src)} -> {label(rcv)}"
        out(f"{link:<32} {kind:<5} {sent_s:>6} {got:>6}  {loss:>6}   {fmt_stats(rssi):<27} {fmt_stats(lqi)}")

    if rx_overheard:
        out("\nFrame yang bukan untuk penerimanya (hanya lolos bila promiscuous aktif):")
        for (src, rcv, dst, kind), cnt in sorted(rx_overheard.items()):
            out(f"  {label(rcv)} menangkap {kind} dari {label(src)} ke {label(dst)}: {cnt}x")
    out("\nkirim = TX pengirim yang dialamatkan ke penerima (unicast atau broadcast);"
        " '-' = tidak dialamatkan.")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", action="append", metavar="PORT",
                    help="port serial yang dipantau; boleh diulang (default: semua port CH343)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--duration", type=float, metavar="DETIK",
                    help="berhenti otomatis setelah sekian detik")
    ap.add_argument("--log", metavar="FILE", help="simpan juga ke file teks")
    ap.add_argument("--no-reset", action="store_true", help="jangan reset board saat port dibuka")
    ap.add_argument("--no-color", action="store_true")
    args = ap.parse_args()

    # Konsol Windows lama tidak bisa mencetak semua karakter; jangan sampai crash.
    reconfigure = getattr(sys.stdout, "reconfigure", None)
    if reconfigure:
        reconfigure(errors="replace")
    if os.name == "nt":
        os.system("")         # aktifkan escape warna ANSI di konsol Windows

    ports = args.port or detect_ports()
    if not ports:
        sys.exit("Tidak ada port CH343 (1A86:55D3) terdeteksi. Cek kabel, atau sebut "
                 "port-nya dengan --port (lihat `pio device list`).")

    use_color = not args.no_color and sys.stdout.isatty()
    logfile = open(args.log, "w", encoding="utf-8") if args.log else None
    nodes = [Node(p, COLORS[i % len(COLORS)]) for i, p in enumerate(ports)]

    # SIGTERM (mis. dihentikan dari luar) diperlakukan sama dengan Ctrl-C
    # supaya ringkasan tetap tercetak.
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt))

    print(f"Monitor {len(nodes)} node 802.15.4 — {', '.join(ports)} · Ctrl-C untuk berhenti"
          f"{' · log: ' + args.log if args.log else ''}")
    print("-" * 60)

    threads = [threading.Thread(target=reader,
                                args=(n, args.baud, not args.no_reset, use_color, logfile),
                                daemon=True)
               for n in nodes]
    for t in threads:
        t.start()

    try:
        while any(t.is_alive() for t in threads):
            if args.duration and time.time() - t0 >= args.duration:
                break
            time.sleep(0.2)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        for t in threads:
            t.join(timeout=1.0)

        def out(line):
            print(line)
            if logfile:
                logfile.write(line + "\n")

        print("\n" + "-" * 60)
        summary(nodes, out)
        if logfile:
            logfile.close()
            print(f"\nLog tersimpan di {args.log}")


if __name__ == "__main__":
    main()
