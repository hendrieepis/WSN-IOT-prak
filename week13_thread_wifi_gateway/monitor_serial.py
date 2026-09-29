#!/usr/bin/env python3
"""Monitor gateway C6 dan node sensor H2 sekaligus untuk Modul 13.

Membaca Gateway (ESP32-C6: Thread Leader + Wi-Fi STA) dan node Sensor H2
(Thread Child) dari SATU komputer dalam satu jendela dengan timestamp
bersama, lalu mencetak ringkasan saat berhenti yang langsung mengisi tabel
loss per hop di bagian Pengukuran:

  - hop Thread  : `TX via Thread` di H2 -> `RX via Thread` di C6
  - hop Wi-Fi   : pesan yang diteruskan C6 -> `HTTP 200` (dipisah per sumber:
                  telemetri Thread asli dan `SIM sensor` di gateway)
  - end-to-end  : `TX via Thread` di H2 -> `HTTP 200`

beserta RSSI Wi-Fi, waktu attach Thread, sebaran kode HTTP (-1, 200, ...),
dan lama tiap POST. Dengan satu sumbu waktu terlihat hop mana yang
menghilangkan data.

    python week13_thread_wifi_gateway/monitor_serial.py                  # deteksi otomatis
    python week13_thread_wifi_gateway/monitor_serial.py --duration 120   # berhenti sendiri
    python week13_thread_wifi_gateway/monitor_serial.py --log sesi1.txt
    python week13_thread_wifi_gateway/monitor_serial.py --port COM9 --port COM5
    python3 week13_thread_wifi_gateway/monitor_serial.py --port /dev/ttyACM6 --port /dev/ttyACM0

Tanpa --port, skrip memakai semua port jembatan UART CH343 (1A86:55D3) yang
terpasang (ESP32-C6 dan ESP32-H2 lab ini sama-sama memakai CH343). Bila ada
board lain yang ikut tercolok, sebut port-nya dengan --port supaya board itu
tidak ikut di-reset. Peran dikenali dari isi log (`Konek Wi-Fi ...` /
`Gateway siap` = Gateway, `Sensor H2 ...` / `TX via Thread` = SensorH2), jadi
urutan port tidak perlu diingat. Gateway saja (tanpa H2) juga bisa dipantau:
ringkasan hop Wi-Fi tetap dihitung dari `SIM sensor`.

Butuh pyserial (`pip install pyserial`; sudah ikut terpasang bersama PlatformIO).
Hentikan dengan Ctrl-C, atau pakai --duration — ringkasan dicetak saat keluar.
Sisi server dicatat terpisah oleh `http_sink.py`; bandingkan jumlah POST di
sana dengan jumlah HTTP 200 di ringkasan ini.

SOAL RESET: tiap board di-reset sekali saat port dibuka (RTS -> EN, dengan DTR
ditahan tidak aktif agar pin boot tetap HIGH dan board boot normal), supaya
asosiasi Wi-Fi, RSSI, dan attach Thread terekam. Pakai --no-reset untuk
mengamati board yang sedang berjalan tanpa mengganggunya.

Loss hop Thread hanya menghitung telemetri yang dikirim SETELAH gateway siap
(`Gateway siap ...`), dan pesan terakhir tepat sebelum monitor berhenti bisa
tercatat hilang — abaikan selisih satu.
"""
import argparse
import os
import re
import signal
import sys
import threading
import time
from collections import Counter

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit("pyserial belum terpasang. Jalankan: pip install pyserial")

CH343_VID, CH343_PID = 0x1A86, 0x55D3
COLORS = ["\033[36m", "\033[33m", "\033[35m", "\033[32m", "\033[34m"]
RESET = "\033[0m"
DIM = "\033[2m"

# Format log firmware week13 (lihat src/c6_gateway dan src/h2_node)
RE_BOOT = re.compile(r"^ESP-ROM:")
RE_PANIC = re.compile(r"Guru Meditation|assert failed|abort\(\) was called")
# Gateway
RE_GW_WIFI = re.compile(r"^Konek Wi-Fi ")
RE_GW_WIFI_OK = re.compile(r"Wi-Fi OK, IP: (\S+) \| RSSI: (-?\d+) dBm")
RE_GW_WIFI_FAIL = re.compile(r"Wi-Fi GAGAL setelah")
RE_GW_WIFI_RETRY = re.compile(r"^Wi-Fi belum tersambung")
RE_GW_ATTACHED = re.compile(r"^Thread attached as: (\w+)")
RE_GW_READY = re.compile(r"^Gateway siap")
RE_GW_SIM = re.compile(r"^SIM sensor \(Thread\): (.+)$")
RE_GW_RX = re.compile(r"^RX via Thread \[([0-9a-fA-F:]+)\]: (.+)$")
RE_GW_FWD = re.compile(r"^Forward via Wi-Fi -> \S+ \| HTTP (-?\d+)")
RE_GW_SKIP = re.compile(r"^Wi-Fi terputus, skip forward")
# Node sensor H2
RE_H2_BANNER = re.compile(r"^Sensor H2 \(Thread node\)")
RE_H2_ATTACHED = re.compile(r"^Attached as: (\w+)")
RE_H2_TX = re.compile(r"^TX via Thread: (.+)$")
# Blok "Info network Thread:" / "Info network Wi-Fi:" dari printThreadInfo()/printWifiInfo()
RE_NET = re.compile(r"^\s+(Channel Wi-Fi|Network name|Channel|PAN ID|Extended PAN ID|RLOC16"
                    r"|Extended addr|EUI-64|Mesh-Local EID|SSID|BSSID \(AP\)|MAC)\s*: (\S+)")

# RX di gateway dianggap salinan TX H2 berisi sama bila tiba dalam jendela ini (detik).
# Batas atas longgar karena loop() gateway tertahan selama http.POST() (timeout
# 8 s bila server tidak terjangkau), sehingga RX via Thread bisa tercetak
# belasan detik setelah H2 mengirim.
MATCH_WINDOW = (-0.5, 15.0)

print_lock = threading.Lock()
stop = threading.Event()
t0 = time.time()


class Node:
    def __init__(self, port, color):
        self.port = port
        self.color = color
        self.name = port          # diganti "Gateway"/"SensorH2" begitu peran dikenali
        self.lines = 0
        self.boot = None          # waktu boot terakhir (baris ESP-ROM, atau saat port dibuka)
        self.boots = 0
        self.panics = 0
        self.role = ""            # peran Thread (Leader / Child / ...)
        self.attach = None        # detik sejak boot sampai attach Thread
        self.ready = None         # gateway: waktu "Gateway siap"
        # gateway
        self.wifi = ""            # ringkasan asosiasi Wi-Fi terakhir
        self.wifi_rssi = []
        self.wifi_retries = 0
        self.pending = None       # (sumber, t, payload) menunggu baris Forward
        self.forwards = []        # (sumber, t, payload, kode HTTP atau "skip", durasi s)
        self.rx = []              # (t, eid, payload) telemetri Thread asli
        # node sensor
        self.tx = []              # (t, payload)
        self.net = {}             # info network Thread (+ Wi-Fi di gateway)


def show(node, text, use_color, logfile, stamp=None):
    """Cetak satu baris dengan timestamp bersama, aman dari tumpang tindih."""
    stamp = f"{(time.time() if stamp is None else stamp) - t0:8.3f}"
    plain = f"[{stamp}] {node.name:<8} | {text}"
    with print_lock:
        if use_color:
            print(f"{DIM}[{stamp}]{RESET} {node.color}{node.name:<8}{RESET} | {text}", flush=True)
        else:
            print(plain, flush=True)
        if logfile:
            logfile.write(plain + "\n")
            logfile.flush()


def parse(node, text, now):
    """Kenali peran node dari isi log, lalu catat attach, telemetri, dan hasil forward."""
    if RE_BOOT.match(text):
        node.boot = now
        node.boots += 1
        node.attach = node.ready = node.pending = None
        return
    if RE_PANIC.search(text):
        node.panics += 1
        return
    m = RE_NET.match(text)
    if m:
        node.net[m.group(1)] = m.group(2)
        return
    boot = node.boot if node.boot is not None else t0

    if (RE_GW_WIFI.match(text) or RE_GW_READY.match(text) or RE_GW_SIM.match(text)
            or RE_GW_FWD.match(text) or RE_GW_RX.match(text)):
        node.name = "Gateway"
    elif RE_H2_BANNER.match(text) or RE_H2_TX.match(text):
        node.name = "SensorH2"

    m = RE_GW_WIFI_OK.search(text)
    if m:
        node.wifi = f"IP {m.group(1)}, {now - boot:.1f} s sejak boot"
        node.wifi_rssi.append(int(m.group(2)))
        return
    if RE_GW_WIFI_FAIL.search(text):
        node.wifi = "GAGAL asosiasi saat boot"
        return
    if RE_GW_WIFI_RETRY.match(text):
        node.wifi_retries += 1
        return
    m = RE_GW_ATTACHED.match(text) or RE_H2_ATTACHED.match(text)
    if m:
        node.role = m.group(1)
        node.attach = now - boot
        return
    if RE_GW_READY.match(text):
        node.ready = now
        return
    m = RE_GW_SIM.match(text)
    if m:
        node.pending = ("SIM", now, m.group(1).strip())
        return
    m = RE_GW_RX.match(text)
    if m:
        payload = m.group(2).strip()
        node.rx.append((now, m.group(1).lower(), payload))
        node.pending = ("Thread", now, payload)
        return
    m = RE_GW_FWD.match(text)
    if m or RE_GW_SKIP.match(text):
        code = int(m.group(1)) if m else "skip"
        if node.pending:
            src, t, payload = node.pending
            node.forwards.append((src, t, payload, code, now - t))
            node.pending = None
        else:
            node.forwards.append(("?", now, "", code, 0.0))
        return
    m = RE_H2_TX.match(text)
    if m:
        node.tx.append((now, m.group(1).strip()))


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
        s.rts = True          # EN LOW (DTR tidak aktif -> pin boot HIGH -> boot normal)
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


def pct(part, whole):
    return f"{100.0 * (whole - part) / whole:5.1f}%" if whole else "  n/a"


def match_thread(h2, gw):
    """Pasangkan TX H2 dengan RX gateway lewat isi payload; kembalikan [(tx, rx atau None)]."""
    since = gw.ready if gw.ready is not None else t0
    used = set()
    pairs = []
    for t, payload in h2.tx:
        if t < since:
            continue
        hit = None
        for i, (tr, _, p) in enumerate(gw.rx):
            if i not in used and p == payload and MATCH_WINDOW[0] <= tr - t <= MATCH_WINDOW[1]:
                hit = i
                break
        if hit is not None:
            used.add(hit)
        pairs.append(((t, payload), None if hit is None else gw.rx[hit]))
    return pairs


def summary(nodes, out):
    out(f"\nDurasi: {time.time() - t0:.1f} s")
    for n in nodes:
        attach = f"{n.attach:5.2f} s" if n.attach is not None else "   -   "
        panic = f", {n.panics}x PANIC" if n.panics else ""
        out(f"  {n.name:<8} {n.role or '?':<7} {n.port:<14} {n.lines:>4} baris, boot {n.boots}x{panic},"
            f" attach Thread {attach} sejak boot")
        if n.name == "Gateway":
            rssi = (f", RSSI {sum(n.wifi_rssi) / len(n.wifi_rssi):.0f} dBm" if n.wifi_rssi else "")
            retry = f", {n.wifi_retries}x coba sambung ulang" if n.wifi_retries else ""
            out(f"           Wi-Fi: {n.wifi or '?'}{rssi}{retry}")
            if "Channel Wi-Fi" in n.net:
                out(f"           Wi-Fi channel {n.net['Channel Wi-Fi']}, SSID {n.net.get('SSID', '?')},"
                    f" MAC {n.net.get('MAC', '?')}")
        if "Network name" in n.net:
            out(f"           Thread {n.net.get('Network name')}, channel {n.net.get('Channel', '?')},"
                f" PAN {n.net.get('PAN ID', '?')}, RLOC16 {n.net.get('RLOC16', '?')},"
                f" EUI-64 {n.net.get('EUI-64', '?')}")

    nets = [n for n in nodes if "Network name" in n.net]
    if len(nets) >= 2:
        keys = ("Network name", "Channel", "PAN ID", "Extended PAN ID")
        same = all(len({n.net.get(k) for n in nets}) == 1 for k in keys)
        out("  Network name/Channel/PAN ID/Extended PAN ID Thread: "
            + ("sama (satu network)" if same else "BERBEDA — dataset tidak identik?"))

    gw = next((n for n in nodes if n.name == "Gateway"), None)
    h2 = next((n for n in nodes if n.name == "SensorH2"), None)
    if gw is None:
        out("\nGateway belum dikenali — ringkasan hop dilewati.")
        return

    out("\nHop                                   dikirim  diterima    loss")
    out("-" * 64)
    pairs = []
    if h2 is not None:
        pairs = match_thread(h2, gw)
        got = sum(1 for _, rx in pairs if rx is not None)
        out(f"{'Thread  (H2 TX -> C6 RX)':<37} {len(pairs):>7} {got:>9}  {pct(got, len(pairs)):>7}")
    for src in ("Thread", "SIM"):
        fw = [f for f in gw.forwards if f[0] == src]
        if not fw:
            continue
        ok = sum(1 for f in fw if isinstance(f[3], int) and 200 <= f[3] < 300)
        label = "Wi-Fi   (C6 -> server, telemetri)" if src == "Thread" else "Wi-Fi   (C6 -> server, SIM sensor)"
        out(f"{label:<37} {len(fw):>7} {ok:>9}  {pct(ok, len(fw)):>7}")
    if h2 is not None and pairs:
        ok_payload = [(f[1], f[2]) for f in gw.forwards
                      if f[0] == "Thread" and isinstance(f[3], int) and 200 <= f[3] < 300]
        e2e = sum(1 for _, rx in pairs if rx is not None and (rx[0], rx[2]) in ok_payload)
        out(f"{'End-to-end (H2 TX -> HTTP 2xx)':<37} {len(pairs):>7} {e2e:>9}  {pct(e2e, len(pairs)):>7}")
    if h2 is None:
        out("(node SensorH2 tidak dipantau: hop Thread tidak dihitung)")

    if gw.forwards:
        codes = Counter(f[3] for f in gw.forwards)
        out("\nKode HTTP: " + ", ".join(f"{c}: {k}x" for c, k in
                                        sorted(codes.items(), key=lambda x: str(x[0]))))
        durs = [f[4] for f in gw.forwards if f[3] != "skip"]
        if durs:
            out(f"Lama POST: rata2 {sum(durs) / len(durs):.2f} s ({min(durs):.2f}..{max(durs):.2f})"
                " — dari baris sumber sampai baris Forward, timestamp PC")
    lost = [tx for tx, rx in pairs if rx is None]
    if lost:
        out("Telemetri H2 yang tidak sampai ke gateway: "
            + ", ".join(f"{p} @ {t - t0:.1f} s" for t, p in lost[:8]) + (" ..." if len(lost) > 8 else ""))
    out("\nBandingkan jumlah HTTP 2xx dengan jumlah POST yang tercatat di http_sink.py.")


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

    print(f"Monitor gateway Thread -> Wi-Fi — {', '.join(ports)} · Ctrl-C untuk berhenti"
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
