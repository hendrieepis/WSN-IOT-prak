#!/usr/bin/env python3
"""Monitor ketiga node Thread mesh sekaligus untuk Modul 12.

Membaca Node1, Node2, dan Node3 dari SATU komputer dalam satu jendela dengan
timestamp bersama, lalu mencetak ringkasan saat berhenti: peran dan waktu
attach sejak boot, EID tiap node, dan matriks pengiriman multicast per link
(pengirim -> penerima): pesan terkirim, diterima, loss, selisih waktu
TX -> RX, serta jeda terpanjang tanpa pesan. Dengan satu sumbu waktu,
kejadian di EXP-03 — node dicabut, mesh menyusun ulang rute, pesan kembali
mengalir — langsung terbaca dari jeda dan loss per link.

    python week12_thread_mesh/monitor_serial.py                  # deteksi otomatis
    python week12_thread_mesh/monitor_serial.py --duration 120   # berhenti sendiri
    python week12_thread_mesh/monitor_serial.py --log sesi1.txt
    python week12_thread_mesh/monitor_serial.py --port COM5 --port COM11 --port COM13
    python3 week12_thread_mesh/monitor_serial.py --port /dev/ttyACM0 --port /dev/ttyACM2 --port /dev/ttyACM4

Tanpa --port, skrip memakai semua port jembatan UART CH343 (1A86:55D3) yang
terpasang. Nama node dikenali dari banner saat boot (`Node1 (Thread)
starting...`), atau dari baris `TX multicast: NODE1:..` bila board tidak
di-reset, jadi urutan port tidak perlu diingat. EID tiap node dipelajari dari
baris RX (isi pesan `NODEn:c` menyebut pengirimnya). Port USB native
(303A:1001) sengaja tidak dipakai: Serial firmware ini keluar lewat UART.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C, atau pakai --duration — ringkasan dicetak saat keluar.

SOAL RESET: tiap board di-reset sekali saat port dibuka (RTS -> EN, dengan DTR
ditahan tidak aktif agar IO9 tetap HIGH dan board boot normal), supaya banner
dan peran terekam dan waktu attach terukur dari boot. Pakai --no-reset untuk
mengamati mesh yang sedang berjalan tanpa mengganggunya — misalnya saat
mencabut satu node di EXP-03, jalankan monitor dulu, baru cabut.

Pesan dicocokkan lewat nomor urutnya: RX `NODE2:7` di Node1 dipasangkan
dengan TX `NODE2:7` di Node2 (dalam MATCH_WINDOW). Loss hanya menghitung pesan
yang dikirim SETELAH penerimanya siap (`Bergabung ke mesh ...`), dan pesan
terakhir tepat sebelum monitor berhenti bisa tercatat hilang — abaikan
selisih satu.
"""
import argparse
import os
import re
import signal
import sys
import threading
import time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit("pyserial belum terpasang. Jalankan: pip install pyserial")

CH343_VID, CH343_PID = 0x1A86, 0x55D3
COLORS = ["\033[36m", "\033[33m", "\033[35m", "\033[32m", "\033[34m"]
RESET = "\033[0m"
DIM = "\033[2m"

# Format log firmware week12 (lihat src/nodeX/main.cpp)
RE_BOOT = re.compile(r"^ESP-ROM:")
RE_BANNER = re.compile(r"^(Node\d+) \(Thread\) starting")
RE_ATTACHED = re.compile(r"^Attached as: (\w+)")
RE_READY = re.compile(r"^Bergabung ke mesh")
RE_TX = re.compile(r"^TX multicast: NODE(\d+):(\d+)")
RE_RX = re.compile(r"^RX \[([0-9a-fA-F:]+)\]: NODE(\d+):(\d+)")
RE_OT_ERR = re.compile(r"^E \(\d+\) OT_")
# Blok "Info network Thread:" yang dicetak printNetworkInfo() setelah attach
RE_NET = re.compile(r"^\s+(Network name|Channel|PAN ID|Extended PAN ID|RLOC16|Extended addr|EUI-64"
                    r"|Mesh-Local EID)\s*: (\S+)")

# RX dianggap salinan TX bernomor sama bila tiba dalam jendela ini (detik).
MATCH_WINDOW = (-0.5, 5.0)

print_lock = threading.Lock()
stop = threading.Event()
t0 = time.time()


class Node:
    def __init__(self, port, color):
        self.port = port
        self.color = color
        self.name = port          # diganti "NodeN" begitu banner/TX terbaca
        self.lines = 0
        self.boot = None          # waktu boot terakhir (baris ESP-ROM, atau saat port dibuka)
        self.boots = 0
        self.role = ""            # Leader / Router / Child
        self.attach = None        # detik sejak boot sampai "Attached as"
        self.ready = None         # waktu "Bergabung ke mesh" (mulai menerima multicast)
        self.ot_errors = 0
        self.net = {}             # info network: Channel, PAN ID, RLOC16, EUI-64, ...
        self.tx = []              # (t, seq)
        self.rx = []              # (t, eid, nama pengirim, seq)


def show(node, text, use_color, logfile, stamp=None):
    """Cetak satu baris dengan timestamp bersama, aman dari tumpang tindih."""
    stamp = f"{(time.time() if stamp is None else stamp) - t0:8.3f}"
    plain = f"[{stamp}] {node.name:<6} | {text}"
    with print_lock:
        if use_color:
            print(f"{DIM}[{stamp}]{RESET} {node.color}{node.name:<6}{RESET} | {text}", flush=True)
        else:
            print(plain, flush=True)
        if logfile:
            logfile.write(plain + "\n")
            logfile.flush()


def parse(node, text, now):
    """Ambil nama/peran node, lalu catat TX/RX multicast untuk ringkasan."""
    if RE_BOOT.match(text):
        node.boot = now
        node.boots += 1
        node.attach = node.ready = None
        return
    m = RE_BANNER.match(text)
    if m:
        node.name = m.group(1)
        return
    if RE_OT_ERR.match(text):
        node.ot_errors += 1
        return
    m = RE_NET.match(text)
    if m:
        node.net[m.group(1)] = m.group(2)
        return
    m = RE_ATTACHED.match(text)
    if m:
        node.role = m.group(1)
        node.attach = now - (node.boot if node.boot is not None else t0)
        return
    if RE_READY.match(text):
        node.ready = now
        return
    m = RE_TX.match(text)
    if m:
        node.name = f"Node{m.group(1)}"
        node.tx.append((now, int(m.group(2))))
        return
    m = RE_RX.match(text)
    if m:
        node.rx.append((now, m.group(1).lower(), f"Node{m.group(2)}", int(m.group(3))))


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
    node.boot = time.time()
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
        # Dipecah per baris agar output ketiga board tidak saling menyisip.
        *lines, buf = buf.split(b"\n")
        for line in lines:
            now = time.time()
            text = line.decode("utf-8", "replace").rstrip("\r")
            if not text.strip():
                continue
            node.lines += 1
            parse(node, text, now)
            show(node, text, use_color, logfile, now)
    ser.close()


def detect_ports():
    return sorted(p.device for p in list_ports.comports()
                  if p.vid == CH343_VID and p.pid == CH343_PID)


def link(src, rcv):
    """Pasangkan TX src dengan RX di rcv lewat nomor urut; kembalikan statistik link."""
    since = rcv.ready if rcv.ready is not None else t0
    sent = [(t, seq) for t, seq in src.tx if t >= since]
    rx = [(t, seq) for t, _, name, seq in rcv.rx if name == src.name]
    used = set()
    lats = []
    for t, seq in sent:
        for i, (tr, sr) in enumerate(rx):
            if i not in used and sr == seq and MATCH_WINDOW[0] <= tr - t <= MATCH_WINDOW[1]:
                used.add(i)
                lats.append((tr - t) * 1000)
                break
    times = [t for t, _ in rx]
    gap = max((b - a for a, b in zip(times, times[1:])), default=None)
    return len(sent), len(lats), lats, gap, len(rx) - len(used)


def summary(nodes, out):
    out(f"\nDurasi: {time.time() - t0:.1f} s")
    eids = {n.name: n.net["Mesh-Local EID"].lower() for n in nodes if "Mesh-Local EID" in n.net}
    for n in nodes:
        for _, eid, name, _ in n.rx:
            eids.setdefault(name, eid)
    for n in nodes:
        attach = f"{n.attach:5.2f} s" if n.attach is not None else "   -   "
        warn = f", {n.ot_errors} peringatan OT" if n.ot_errors else ""
        out(f"  {n.name:<6} {n.role or '?':<7} {n.port:<14} {n.lines:>4} baris, boot {n.boots}x,"
            f" attach {attach} sejak boot{warn}")
        if n.name in eids:
            out(f"         EID {eids[n.name]}")
        if n.net:
            out(f"         network {n.net.get('Network name', '?')}, channel {n.net.get('Channel', '?')},"
                f" PAN {n.net.get('PAN ID', '?')}, RLOC16 {n.net.get('RLOC16', '?')},"
                f" EUI-64 {n.net.get('EUI-64', '?')}")

    nets = [n for n in nodes if n.net]
    if len(nets) >= 2:
        keys = ("Network name", "Channel", "PAN ID", "Extended PAN ID")
        same = all(len({n.net.get(k) for n in nets}) == 1 for k in keys)
        out("  Network name/Channel/PAN ID/Extended PAN ID semua node: "
            + ("sama (satu network)" if same else "BERBEDA — dataset tidak identik?"))

    out("\nLink (pengirim -> penerima)  kirim  terima    loss   TX->RX ms rata2 (min..max)   jeda terpanjang")
    out("-" * 98)
    for src in nodes:
        if not src.tx:
            continue
        for rcv in nodes:
            if rcv is src:
                continue
            sent, got, lats, gap, extra = link(src, rcv)
            loss = f"{100.0 * (sent - got) / sent:5.1f}%" if sent else "  n/a"
            lat = f"{sum(lats) / len(lats):6.0f} ({min(lats):.0f}..{max(lats):.0f})" if lats else "-"
            gap_s = f"{gap:6.1f} s" if gap is not None else "-"
            out(f"{src.name + ' -> ' + rcv.name:<28} {sent:>5} {got:>7}  {loss:>7}   {lat:<28} {gap_s}")
            if extra:
                out(f"{'':<28} + {extra} RX tanpa TX yang cocok (dikirim sebelum monitor/penerima siap)")

    watched = {n.name for n in nodes}
    others = sorted({name for n in nodes for _, _, name, _ in n.rx if name not in watched})
    if others:
        out("\nPesan juga diterima dari node yang tidak dipantau: " + ", ".join(others))
    out("\nJeda terpanjang = selang terlama antara dua pesan yang diterima dari pengirim itu"
        " (normal ~5 s);\nselisih TX->RX memakai timestamp PC (kasar).")


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

    print(f"Monitor {len(nodes)} node Thread — {', '.join(ports)} · Ctrl-C untuk berhenti"
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
