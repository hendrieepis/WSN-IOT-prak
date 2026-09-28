#!/usr/bin/env python3
"""Monitor coordinator, router, dan end device Zigbee sekaligus untuk Modul 10.

Membaca Coordinator (switch), Router (RouterLight), dan End Device (EndLight)
dari SATU komputer dalam satu jendela dengan timestamp bersama, lalu mencetak
ringkasan saat berhenti: waktu join sejak boot, peran yang dilaporkan tiap
node (role=ROUTER / role=END_DEVICE), daftar device ter-bind, dan per lampu
jumlah perintah ON/OFF yang dikirim coordinator, aksi yang benar-benar
terjadi, loss, serta selisih waktu perintah -> aksi. Dengan satu sumbu waktu,
pengaruh jarak dan hop lewat router langsung terlihat pada loss dan selisih
waktu tiap lampu.

    python week10_zigbee_mesh/monitor_serial.py                  # deteksi otomatis
    python week10_zigbee_mesh/monitor_serial.py --duration 70    # berhenti sendiri
    python week10_zigbee_mesh/monitor_serial.py --log sesi1.txt
    python week10_zigbee_mesh/monitor_serial.py --port COM5 --port COM11 --port COM13
    python3 week10_zigbee_mesh/monitor_serial.py --port /dev/ttyACM0 --port /dev/ttyACM2 --port /dev/ttyACM4

Tanpa --port, skrip memakai semua port jembatan UART CH343 (1A86:55D3) yang
terpasang. Peran tiap board dikenali dari isi log (`Menunggu router ...` =
Coordinator, `Router ...` / `RouterLight ...` = Router, `End device ...` /
`EndLight ...` = EndDevice), jadi urutan port tidak perlu diingat. Port USB native (303A:1001) sengaja tidak dipakai: Serial firmware ini
keluar lewat UART.

Perintah coordinator hanya mencetak short address (`-> 0xE04F ON`), dan
short address satu lampu bisa tercetak 0xFFFF. Karena itu perintah dipetakan
ke lampu lewat urutan daftar `getBoundDevices()` yang dicetak saat boot
(endpoint 10 = Router, endpoint 11 = EndDevice): tiap putaran, coordinator
mengirim ke device dengan urutan yang sama seperti daftar itu.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C, atau pakai --duration — ringkasan dicetak saat keluar.

SOAL RESET: tiap board di-reset sekali saat port dibuka (RTS -> EN, dengan DTR
ditahan tidak aktif agar IO9 tetap HIGH dan board boot normal), supaya daftar
device ter-bind terekam dan waktu join terukur dari boot. Reset coordinator
juga membuka network lagi selama 180 s. Keanggotaan tersimpan di NVS, jadi
reset TIDAK sama dengan erase. Pakai --no-reset untuk mengamati board yang
sedang berjalan; tanpa daftar bound, perintah hanya bisa dipetakan lewat
short address yang unik.

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

# Endpoint tiap lampu sesuai src/router dan src/enddevice
LIGHT_EP = {"Router": 10, "EndDevice": 11}
EP_LIGHT = {ep: name for name, ep in LIGHT_EP.items()}

# Format log firmware week10 (lihat src/coordinator, src/router, src/enddevice)
RE_BOOT = re.compile(r"^ESP-ROM:")
RE_FAIL = re.compile(r"Zigbee gagal start!")
RE_ZC_WAIT = re.compile(r"^Menunggu router & end device ter-binding")
RE_ZC_LIST = re.compile(r"^Total device ter-bind: (\d+)")   # dicetak SEBELUM daftar
RE_ZC_BOUND = re.compile(r"^\s*- endpoint (\d+), short addr 0x([0-9A-Fa-f]{4})")
RE_ZC_CMD = re.compile(r"^-> 0x([0-9A-Fa-f]{4}) (ON|OFF)")
RE_L_WAIT = re.compile(r"^(Router|End device) menunggu join")
RE_L_JOINED = re.compile(r"^(Router|End device) tergabung \(role=(\w+)\)")
RE_L_ACTION = re.compile(r"^(RouterLight|EndLight) (ON|OFF)$")
# Nama di log -> nama node
LIGHT_NAME = {"Router": "Router", "RouterLight": "Router",
              "End device": "EndDevice", "EndLight": "EndDevice"}

# Aksi lampu dianggap jawaban suatu perintah bila jatuh dalam jendela ini
# (detik). Batas bawah negatif karena ZC mencetak baris perintah SETELAH
# lightOn()/lightOff() kembali, sehingga baris lampu bisa tiba lebih dulu.
MATCH_WINDOW = (-0.5, 2.0)

print_lock = threading.Lock()
stop = threading.Event()
t0 = time.time()


class Node:
    def __init__(self, port, color):
        self.port = port
        self.color = color
        self.name = port          # diganti "Coordinator"/"Router"/"EndDevice" begitu dikenali
        self.role = None          # "ZC" atau "LIGHT"
        self.lines = 0
        self.boot = None          # waktu boot terakhir (baris ESP-ROM, atau saat port dibuka)
        self.boots = 0
        self.fails = 0            # "Zigbee gagal start!"
        self.ready = None         # ZC: daftar bound tercetak; lampu: tergabung (relatif boot)
        self.zb_role = ""        # role yang dilaporkan node (ROUTER / END_DEVICE)
        self.events = []          # lampu: (t, "ON"/"OFF") aksi


class Coordinator:
    """Status yang hanya dimiliki coordinator: daftar bound dan perintah."""
    def __init__(self):
        self.bound = []           # [(endpoint, short_addr)] sesuai urutan cetak
        self.total = 0            # dari baris "Total ..."
        self.slot = 0             # posisi perintah berikutnya dalam satu putaran
        self.commands = []        # (t, endpoint atau None, short_addr, state)


zc = Coordinator()


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


def endpoint_for(addr):
    """Tentukan endpoint tujuan perintah: urutan daftar bound, atau short address unik."""
    if zc.bound:
        ep, bound_addr = zc.bound[zc.slot % len(zc.bound)]
        if bound_addr == addr:
            zc.slot += 1
            return ep
        zc.slot = 0               # urutan tidak cocok: sinkron ulang lewat alamat
    hits = [ep for ep, a in zc.bound if a == addr]
    if len(hits) == 1:
        zc.slot = [e for e, _ in zc.bound].index(hits[0]) + 1
        return hits[0]
    return None


def parse(node, text, now):
    """Kenali peran node dari isi log, lalu catat join/binding/perintah/aksi."""
    if RE_BOOT.match(text):
        node.boot = now
        node.boots += 1
        node.ready = None
        if node.role == "ZC":
            zc.bound.clear()
            zc.slot = 0
        return
    if RE_FAIL.search(text):
        node.fails += 1
        return
    boot = node.boot if node.boot is not None else t0

    if RE_ZC_WAIT.match(text) or RE_ZC_LIST.match(text) or RE_ZC_CMD.match(text):
        node.role, node.name = "ZC", "Coordinator"
    m = RE_L_WAIT.match(text) or RE_L_JOINED.match(text) or RE_L_ACTION.match(text)
    if m:
        node.role, node.name = "LIGHT", LIGHT_NAME[m.group(1)]

    if node.role == "ZC":
        m = RE_ZC_LIST.match(text)
        if m:
            zc.bound.clear()
            zc.slot = 0
            zc.total = int(m.group(1))
            node.ready = now - boot
            return
        m = RE_ZC_BOUND.match(text)
        if m:
            zc.bound.append((int(m.group(1)), int(m.group(2), 16)))
            return
        m = RE_ZC_CMD.match(text)
        if m:
            addr = int(m.group(1), 16)
            zc.commands.append((now, endpoint_for(addr), addr, m.group(2)))
        return

    m = RE_L_JOINED.match(text)
    if m:
        node.ready = now - boot
        node.zb_role = m.group(2)
        return
    m = RE_L_ACTION.match(text)
    if m:
        node.events.append((now, m.group(2)))


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
            with print_lock:          # parse() menyentuh status coordinator bersama
                parse(node, text, now)
            show(node, text, use_color, logfile, now)
    ser.close()


def detect_ports():
    return sorted(p.device for p in list_ports.comports()
                  if p.vid == CH343_VID and p.pid == CH343_PID)


def match(commands, actions):
    """Pasangkan tiap perintah dengan aksi berstatus sama dalam MATCH_WINDOW."""
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
        pairs.append((tc, state, None if hit is None else actions[hit][0] - tc))
    return pairs, len(actions) - len(used)


def summary(nodes, out):
    out(f"\nDurasi: {time.time() - t0:.1f} s")
    for n in nodes:
        ready = f"{n.ready:5.2f} s" if n.ready is not None else "    -  "
        what = "daftar bound" if n.role == "ZC" else "tergabung"
        extra = f", {n.fails}x gagal start" if n.fails else ""
        role = f", role={n.zb_role}" if n.zb_role else ""
        out(f"  {n.name:<11} {n.port:<14} {n.lines:>4} baris, boot {n.boots}x{extra},"
            f" {what} {ready} sejak boot{role}")

    if zc.bound:
        out(f"\nDevice ter-bind di coordinator ({zc.total or len(zc.bound)}):")
        for ep, addr in zc.bound:
            out(f"  endpoint {ep:<3} short addr 0x{addr:04X}  -> {EP_LIGHT.get(ep, '?')}")

    lights = {n.name: n for n in nodes if n.role == "LIGHT"}
    if not zc.commands:
        out("\nBelum ada perintah dari coordinator — ringkasan perintah dilewati.")
        return

    unknown = sum(1 for c in zc.commands if c[1] is None)
    out("\nLampu     perintah  aksi   loss   perintah->aksi ms rata2 (min..max)  status akhir ZC/lampu")
    out("-" * 92)
    for name, ep in LIGHT_EP.items():
        cmds = [(t, st) for t, e, _, st in zc.commands if e == ep]
        node = lights.get(name)
        if node is None:
            out(f"{name:<9} {len(cmds):>8}  (port lampu ini tidak dipantau)")
            continue
        pairs, extra = match(cmds, node.events)
        got = sum(1 for p in pairs if p[2] is not None)
        loss = f"{100.0 * (len(cmds) - got) / len(cmds):5.1f}%" if cmds else "  n/a"
        lats = [p[2] * 1000 for p in pairs if p[2] is not None]
        lat = f"{sum(lats) / len(lats):6.0f} ({min(lats):.0f}..{max(lats):.0f})" if lats else "-"
        last = (f"{cmds[-1][1]}/{node.events[-1][1]}" if cmds and node.events else "-")
        out(f"{name:<9} {len(cmds):>8} {got:>5}  {loss:>6}   {lat:<35} {last}")
        missed = [p for p in pairs if p[2] is None]
        if missed:
            out("          tanpa aksi: " + ", ".join(f"{p[1]} @ {p[0] - t0:.1f} s" for p in missed[:8])
                + (" ..." if len(missed) > 8 else ""))
        if extra:
            out(f"          aksi tanpa perintah: {extra}")

    if unknown:
        out(f"\n{unknown} perintah tidak bisa dipetakan ke lampu (daftar bound tidak terekam"
            " dan short address tidak unik) — jalankan tanpa --no-reset.")
    rounds = [c[0] for c in zc.commands if c[1] == zc.bound[0][0]] if zc.bound else []
    if len(rounds) >= 2:
        out(f"\nPutaran perintah per menit: {(len(rounds) - 1) * 60.0 / (rounds[-1] - rounds[0]):.1f}"
            " (harapan 12: satu putaran tiap 5 s)")
    out(f"Aksi dipasangkan bila status sama dan jatuh {MATCH_WINDOW[0]:+.1f}..{MATCH_WINDOW[1]:+.1f} s"
        " dari perintah; selisih memakai timestamp PC (kasar).")


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
