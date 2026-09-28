#!/usr/bin/env python3
"""Monitor coordinator dan end device Zigbee sekaligus untuk Modul 08.

Membaca Coordinator (switch) dan End Device (light) dari SATU komputer dalam
satu jendela dengan timestamp bersama, lalu mencetak ringkasan saat berhenti:
waktu join dan binding sejak boot, jumlah perintah ON/OFF yang dikirim
coordinator, jumlah aksi yang benar-benar terjadi di end device, loss, siklus
per menit, dan selisih waktu perintah -> aksi. Dengan satu sumbu waktu, urutan
join (ED) -> binding (ZC) dan perintah yang tertinggal (EXP-03) langsung
terlihat.

    python week08_zigbee_p2p/monitor_serial.py                  # deteksi otomatis
    python week08_zigbee_p2p/monitor_serial.py --duration 70    # berhenti sendiri
    python week08_zigbee_p2p/monitor_serial.py --log sesi1.txt
    python week08_zigbee_p2p/monitor_serial.py --port COM5 --port COM11
    python3 week08_zigbee_p2p/monitor_serial.py --port /dev/ttyACM0 --port /dev/ttyACM2

Tanpa --port, skrip memakai semua port jembatan UART CH343 (1A86:55D3) yang
terpasang. Firmware modul ini tidak mencetak nama node, jadi peran dikenali
dari isi log (`Menunggu end device ...` = Coordinator, `Menunggu bergabung ...`
= End Device) — urutan port tidak perlu diingat. Port USB native (303A:1001)
sengaja tidak dipakai: Serial firmware ini keluar lewat UART.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C, atau pakai --duration — ringkasan dicetak saat keluar.

SOAL RESET: tiap board di-reset sekali saat port dibuka (RTS -> EN, dengan DTR
ditahan tidak aktif agar IO9 tetap HIGH dan board boot normal), supaya pesan
awal terekam dan waktu join/binding terukur dari boot. Reset coordinator juga
membuka network lagi selama 180 s (`setRebootOpenNetwork`). Keanggotaan
tersimpan di NVS, jadi reset TIDAK sama dengan erase: untuk mengukur join dari
nol, erase dulu kedua board. Pakai --no-reset untuk mengamati board yang
sedang berjalan tanpa mengganggunya.

Perintah terakhir yang dikirim tepat sebelum monitor berhenti bisa tercatat
hilang — abaikan selisih satu.
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

# Format log firmware week08 (lihat src/coordinator dan src/enddevice)
RE_BOOT = re.compile(r"^ESP-ROM:")
RE_ZC_WAIT = re.compile(r"^(Menunggu end device ter-binding|Network Zigbee terbentuk)")
RE_ZC_BOUND = re.compile(r"End device ter-binding!")
RE_ZC_CMD = re.compile(r"^Perintah: Lampu (ON|OFF)")
RE_ZC_REPORT = re.compile(r"^Lampu sekarang: (ON|OFF)")
RE_ED_WAIT = re.compile(r"^Menunggu bergabung ke network")
RE_ED_JOINED = re.compile(r"^Berhasil bergabung ke network!")
RE_ED_ACTION = re.compile(r"^Lampu (ON|OFF)$")
RE_FAIL = re.compile(r"Zigbee gagal start!")
# Blok info network yang dicetak printNetworkInfo() setelah network terbentuk/join
RE_NET = re.compile(r"^\s+(Channel|PAN ID|Extended PAN ID|Short address|IEEE address)\s*: (\S+)")

# Aksi ED dianggap jawaban suatu perintah bila jatuh dalam jendela ini (detik).
# Batas bawah negatif karena ZC mencetak "Perintah" SETELAH lightOn()/lightOff()
# kembali, sehingga baris ED bisa tiba sedikit lebih dulu.
MATCH_WINDOW = (-0.5, 2.0)

print_lock = threading.Lock()
stop = threading.Event()
t0 = time.time()


class Node:
    def __init__(self, port, color):
        self.port = port
        self.color = color
        self.name = port          # diganti "Coordinator"/"ED <port>" begitu peran dikenali
        self.role = None          # "ZC" atau "ED"
        self.lines = 0
        self.boot = None          # waktu boot terakhir (baris ESP-ROM, atau saat port dibuka)
        self.boots = 0
        self.fails = 0            # "Zigbee gagal start!"
        self.ready = None         # ZC: waktu ter-binding; ED: waktu bergabung (relatif boot)
        self.events = []          # ZC: (t, "ON"/"OFF") perintah; ED: (t, state) aksi
        self.reports = []         # ZC: laporan balik "Lampu sekarang" (CH-2)
        self.net = {}             # info network: Channel, PAN ID, Short address, ...


def show(node, text, use_color, logfile, stamp=None):
    """Cetak satu baris dengan timestamp bersama, aman dari tumpang tindih."""
    stamp = f"{(time.time() if stamp is None else stamp) - t0:8.3f}"
    plain = f"[{stamp}] {node.name:<11} | {text}"
    with print_lock:
        if use_color:
            print(f"{DIM}[{stamp}]{RESET} {node.color}{node.name:<11}{RESET} | {text}", flush=True)
        else:
            print(plain, flush=True)
        if logfile:
            logfile.write(plain + "\n")
            logfile.flush()


def set_role(node, role):
    node.role = role
    # Port ikut di nama ED supaya beberapa end device bisa dibedakan di log
    node.name = "Coordinator" if role == "ZC" else f"ED {node.port}"


def parse(node, text, now):
    """Kenali peran node dari isi log, lalu catat join/binding/perintah/aksi."""
    if RE_BOOT.match(text):
        node.boot = now
        node.boots += 1
        node.ready = None
        return
    if RE_FAIL.search(text):
        node.fails += 1
        return
    m = RE_NET.match(text)
    if m:
        node.net[m.group(1)] = m.group(2)
        return
    if RE_ZC_WAIT.match(text) or RE_ZC_CMD.match(text):
        if node.role is None:
            set_role(node, "ZC")
    elif RE_ED_WAIT.match(text) or RE_ED_JOINED.match(text):
        if node.role is None:
            set_role(node, "ED")

    boot = node.boot if node.boot is not None else t0
    if RE_ZC_BOUND.search(text):
        if node.role is None:
            set_role(node, "ZC")
        node.ready = now - boot
        return
    if RE_ED_JOINED.match(text):
        node.ready = now - boot
        return
    m = RE_ZC_CMD.match(text)
    if m:
        node.events.append((now, m.group(1)))
        return
    m = RE_ZC_REPORT.match(text)
    if m:
        node.reports.append((now, m.group(1)))
        return
    m = RE_ED_ACTION.match(text)
    if m:
        if node.role is None:
            set_role(node, "ED")
        node.events.append((now, m.group(1)))


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


def match(commands, actions):
    """Pasangkan tiap perintah ZC dengan aksi ED berstatus sama dalam MATCH_WINDOW."""
    used = set()
    pairs = []
    for tc, state in commands:
        hit = None
        for i, (ta, st) in enumerate(actions):
            if i in used or st != state:
                continue
            if MATCH_WINDOW[0] <= ta - tc <= MATCH_WINDOW[1]:
                hit = i
                break
        if hit is not None:
            used.add(hit)
            pairs.append((tc, state, actions[hit][0] - tc))
        else:
            pairs.append((tc, state, None))
    return pairs, len(actions) - len(used)


def summary(nodes, out):
    out(f"\nDurasi: {time.time() - t0:.1f} s")
    for n in nodes:
        role = {"ZC": "switch, ep 5", "ED": "light, ep 10"}.get(n.role, "peran ?")
        ready = f"{n.ready:5.2f} s" if n.ready is not None else "    -  "
        what = "ter-binding" if n.role == "ZC" else "bergabung"
        extra = f", {n.fails}x gagal start" if n.fails else ""
        out(f"  {n.name:<11} {role:<13} {n.port:<14} {n.lines:>4} baris,"
            f" boot {n.boots}x{extra}, {what} {ready} sejak boot")
        if n.net:
            out(f"  {'':<11} channel {n.net.get('Channel', '?')}, PAN {n.net.get('PAN ID', '?')},"
                f" ext PAN {n.net.get('Extended PAN ID', '?')}, short {n.net.get('Short address', '?')}")

    nets = [n for n in nodes if n.role in ("ZC", "ED") and n.net]
    if len(nets) >= 2:
        keys = ("Channel", "PAN ID", "Extended PAN ID")
        same = all(len({n.net.get(k) for n in nets}) == 1 for k in keys)
        out("  Channel/PAN ID/Extended PAN ID semua node: "
            + ("sama (satu network)" if same else "BERBEDA — end device bergabung ke network lain?"))

    zcs = [n for n in nodes if n.role == "ZC"]
    eds = [n for n in nodes if n.role == "ED"]
    if not zcs or not eds:
        out("\nCoordinator dan/atau End Device belum dikenali — ringkasan perintah dilewati."
            " (Tanpa reset, peran baru dikenali setelah baris 'Perintah'/'Lampu' pertama.)")
        return

    zc = zcs[0]
    cmds = zc.events
    for ed in eds:
        pairs, extra = match(cmds, ed.events)
        got = sum(1 for p in pairs if p[2] is not None)
        sent = len(cmds)
        loss = f"{100.0 * (sent - got) / sent:.1f}%" if sent else "n/a"
        lats = [p[2] * 1000 for p in pairs if p[2] is not None]

        out(f"\nPerintah {zc.name} -> {ed.name} ({ed.port})")
        out("-" * 60)
        out(f"  Perintah dikirim (ZC)      : {sent}"
            f"  (ON {sum(1 for c in cmds if c[1] == 'ON')}, OFF {sum(1 for c in cmds if c[1] == 'OFF')})")
        out(f"  Aksi terlaksana (ED)       : {got}")
        out(f"  Loss                       : {loss}")
        if extra:
            out(f"  Aksi ED tanpa perintah     : {extra}  (mis. perintah sebelum monitor mulai)")
        if lats:
            out(f"  Selisih perintah -> aksi   : rata2 {sum(lats) / len(lats):.0f} ms"
                f" ({min(lats):.0f}..{max(lats):.0f})  — timestamp PC, kasar")
        if len(cmds) >= 2:
            span = cmds[-1][0] - cmds[0][0]
            if span > 0:
                out(f"  Siklus ON/OFF per menit    : {(len(cmds) - 1) * 60.0 / span:.1f}"
                    "  (harapan 12: satu perintah tiap 5 s)")
        missed = [p for p in pairs if p[2] is None]
        if missed:
            out("  Perintah tanpa aksi di ED  : "
                + ", ".join(f"{p[1]} @ {p[0] - t0:.1f} s" for p in missed[:10])
                + (" ..." if len(missed) > 10 else ""))
        if ed.events and cmds:
            last_ed = ed.events[-1][1]
            last_zc = cmds[-1][1]
            sync = "ya" if last_ed == last_zc else "TIDAK"
            out(f"  Status akhir ZC vs ED      : {last_zc} vs {last_ed} -> sinkron: {sync}")

    out(f"\n  Laporan balik ke switch ('Lampu sekarang', CH-2): {len(zc.reports)}")
    out(f"\nAksi dipasangkan bila status sama dan jatuh {MATCH_WINDOW[0]:+.1f}..{MATCH_WINDOW[1]:+.1f} s"
        " dari perintah.")


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

    print(f"Monitor {len(nodes)} node Zigbee — {', '.join(ports)} · Ctrl-C untuk berhenti"
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
