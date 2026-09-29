#!/usr/bin/env python3
"""Monitor kedua node Thread sekaligus untuk Modul 11.

Membaca Node1 (Leader, menjawab PING) dan Node2 (Child, mengirim PING) dari
SATU komputer dalam satu jendela dengan timestamp bersama, lalu mencetak
ringkasan saat berhenti: peran dan waktu attach sejak boot, Mesh-Local EID
tiap node, jumlah PING/PONG terkirim dan diterima per arah (loss), serta
round-trip PING -> PONG yang diukur di Node2. Dengan satu sumbu waktu,
kapan Node2 attach sebagai Child dan kapan PING pertama benar-benar sampai
di Leader langsung terlihat.

    python week11_thread_p2p/monitor_serial.py                  # deteksi otomatis
    python week11_thread_p2p/monitor_serial.py --duration 60    # berhenti sendiri
    python week11_thread_p2p/monitor_serial.py --log sesi1.txt
    python week11_thread_p2p/monitor_serial.py --port COM5 --port COM11
    python3 week11_thread_p2p/monitor_serial.py --port /dev/ttyACM0 --port /dev/ttyACM2

Tanpa --port, skrip memakai semua port jembatan UART CH343 (1A86:55D3) yang
terpasang. Nama node dikenali dari banner saat boot (`Node1 (Thread Leader)
starting...`), atau dari baris `TX PING` / `TX PONG` bila board tidak di-reset,
jadi urutan port tidak perlu diingat. Port USB native (303A:1001) sengaja tidak
dipakai: Serial firmware ini keluar lewat UART.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C, atau pakai --duration — ringkasan dicetak saat keluar.

SOAL RESET: tiap board di-reset sekali saat port dibuka (RTS -> EN, dengan DTR
ditahan tidak aktif agar IO9 tetap HIGH dan board boot normal), supaya banner,
peran, dan EID terekam dan waktu attach terukur dari boot. Pakai --no-reset
untuk mengamati board yang sedang berjalan tanpa mengganggunya (peran dan EID
lalu tidak diketahui; loss dihitung per jenis pesan saja).

Loss hanya menghitung pesan yang dikirim SETELAH penerimanya siap (Node1
selesai `Mendengarkan ...`, Node2 selesai mencetak EID), dan PING terakhir
tepat sebelum monitor berhenti bisa tercatat hilang — abaikan selisih satu.
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

# Format log firmware week11 (lihat src/node1 dan src/node2)
RE_BOOT = re.compile(r"^ESP-ROM:")
RE_BANNER = re.compile(r"^(Node\d+) \(Thread")
RE_ATTACHED = re.compile(r"^Attached as: (\w+)")
RE_EID = re.compile(r"^\s*Mesh-Local EID\s*: (\S+)")
RE_LISTEN = re.compile(r"^Mendengarkan \[")
RE_TX_PING = re.compile(r"^TX PING")
RE_TX_PONG = re.compile(r"^TX PONG")
RE_RX = re.compile(r"^RX \[([0-9a-fA-F:]+)\]:\d+ -> '(\w+)'")
RE_OT_ERR = re.compile(r"^E \(\d+\) OT_")
# Blok "Info network Thread:" yang dicetak printNetworkInfo() setelah attach
RE_NET = re.compile(r"^\s+(Network name|Channel|PAN ID|Extended PAN ID|RLOC16|Extended addr|EUI-64"
                    r"|Mesh-Local EID)\s*: (\S+)")

RTT_MAX = 3.0             # PONG dihitung jawaban PING bila tiba dalam sekian detik

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
        self.eid = None
        self.ready = None         # waktu mulai siap menerima (lihat docstring)
        self.ot_errors = 0
        self.net = {}             # info network: Channel, PAN ID, RLOC16, EUI-64, ...
        self.tx = []              # (t, jenis, tujuan): tujuan = EID atau "multicast"
        self.rx = []              # (t, eid pengirim, jenis)


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
    """Ambil nama/peran/EID node, lalu catat PING/PONG untuk ringkasan."""
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
        if m.group(1) != "Mesh-Local EID":
            return
    m = RE_ATTACHED.match(text)
    if m:
        node.role = m.group(1)
        node.attach = now - (node.boot if node.boot is not None else t0)
        return
    m = RE_EID.match(text)
    if m:
        node.eid = m.group(1).lower()
        if node.name != "Node1":
            node.ready = now          # Node2: OtUdp.begin() tepat setelah baris ini
        return
    if RE_LISTEN.match(text):
        node.ready = now
        return
    if RE_TX_PING.match(text):
        if node.name == node.port:
            node.name = "Node2"
        node.tx.append((now, "PING", "multicast"))
        return
    if RE_TX_PONG.match(text):
        if node.name == node.port:
            node.name = "Node1"
        # PONG dikirim unicast ke pengirim RX terakhir
        dst = node.rx[-1][1] if node.rx else None
        node.tx.append((now, "PONG", dst))
        return
    m = RE_RX.match(text)
    if m:
        node.rx.append((now, m.group(1).lower(), m.group(2)))


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
        # Dipecah per baris agar output kedua board tidak saling menyisip.
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


def link_stats(src, rcv, kind):
    """(terkirim, diterima) untuk pesan `kind` dari src ke rcv setelah rcv siap."""
    since = rcv.ready if rcv.ready is not None else t0
    sent = [t for t, k, dst in src.tx
            if k == kind and t >= since
            and (dst == "multicast" or dst is None or rcv.eid is None or dst == rcv.eid)]
    got = [t for t, eid, k in rcv.rx
           if k == kind and t >= since and (src.eid is None or eid == src.eid)]
    return len(sent), len(got)


def summary(nodes, out):
    out(f"\nDurasi: {time.time() - t0:.1f} s")
    for n in nodes:
        attach = f"{n.attach:5.2f} s" if n.attach is not None else "   -   "
        warn = f", {n.ot_errors} peringatan OT" if n.ot_errors else ""
        out(f"  {n.name:<6} {n.role or '?':<7} {n.port:<14} {n.lines:>4} baris, boot {n.boots}x,"
            f" attach {attach} sejak boot{warn}")
        if n.eid:
            out(f"         EID {n.eid}")
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

    out("\nLink (pengirim -> penerima)   jenis   kirim  terima    loss")
    out("-" * 60)
    for src in nodes:
        for kind in ("PING", "PONG"):
            if not any(k == kind for _, k, _ in src.tx):
                continue
            for rcv in nodes:
                if rcv is src:
                    continue
                sent, got = link_stats(src, rcv, kind)
                loss = f"{100.0 * (sent - got) / sent:5.1f}%" if sent and got <= sent else "  n/a"
                link = f"{src.name} -> {rcv.name}"
                out(f"{link:<29} {kind:<6} {sent:>6} {got:>7}  {loss:>7}")

    for n in nodes:
        pings = [t for t, k, _ in n.tx if k == "PING"]
        if not pings:
            continue
        pongs = [t for t, _, k in n.rx if k == "PONG"]
        rtts = []
        for i, t in enumerate(pings):
            limit = min(t + RTT_MAX, pings[i + 1] if i + 1 < len(pings) else t + RTT_MAX)
            hit = next((p for p in pongs if t < p <= limit), None)
            if hit is not None:
                rtts.append((hit - t) * 1000)
        ok = f"{100.0 * len(rtts) / len(pings):.1f}%"
        out(f"\nRound-trip di {n.name}: {len(rtts)}/{len(pings)} PING dijawab PONG ({ok})")
        if rtts:
            out(f"  RTT PING -> PONG: rata2 {sum(rtts) / len(rtts):.0f} ms"
                f" ({min(rtts):.0f}..{max(rtts):.0f}) — timestamp PC, kasar")

    eids = {n.eid: n.name for n in nodes if n.eid}
    unknown = sorted({eid for n in nodes for _, eid, _ in n.rx if eid not in eids})
    if unknown and eids:
        out("\nPesan dari EID yang bukan milik node yang dipantau: " + ", ".join(unknown))
    out("\nLoss hanya menghitung pesan setelah penerima siap; 'n/a' = tidak bisa dihitung.")


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
