#!/usr/bin/env python3
"""Minimal MQTT 3.1.1 broker (QoS 0/1 publish, retain, wildcards).

Cukup untuk lab: CONNECT/PUBLISH/SUBSCRIBE/PINGREQ/DISCONNECT.
Setiap PUBLISH yang masuk dicetak ke stdout dengan timestamp, sehingga
berfungsi sekaligus sebagai pengganti `mosquitto_sub -v`.
"""
import socket, struct, threading, time, sys

HOST, PORT = "0.0.0.0", 1883
clients = {}          # conn -> {"subs": [filters], "id": str}
retained = {}         # topic -> payload
lock = threading.Lock()
t0 = time.time()


def log(msg):
    print("[%8.3f] %s" % (time.time() - t0, msg), flush=True)


def read_varint(sock):
    mult, val = 1, 0
    while True:
        b = sock.recv(1)
        if not b:
            return None
        b = b[0]
        val += (b & 0x7F) * mult
        if not (b & 0x80):
            return val
        mult *= 128
        if mult > 128 ** 3:
            return None


def encode_varint(n):
    out = b""
    while True:
        b = n % 128
        n //= 128
        out += bytes([b | (0x80 if n else 0)])
        if not n:
            return out


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def topic_matches(filt, topic):
    f, t = filt.split("/"), topic.split("/")
    i = 0
    while i < len(f):
        if f[i] == "#":
            return True
        if i >= len(t):
            return False
        if f[i] != "+" and f[i] != t[i]:
            return False
        i += 1
    return i == len(t)


def send_publish(conn, topic, payload):
    tb = topic.encode()
    body = struct.pack("!H", len(tb)) + tb + payload
    try:
        conn.sendall(bytes([0x30]) + encode_varint(len(body)) + body)
    except OSError:
        pass


def deliver(topic, payload):
    with lock:
        targets = [c for c, st in clients.items()
                   if any(topic_matches(f, topic) for f in st["subs"])]
    for c in targets:
        send_publish(c, topic, payload)


def handle(conn, addr):
    cid = "?"
    with lock:
        clients[conn] = {"subs": [], "id": cid}
    try:
        while True:
            hdr = conn.recv(1)
            if not hdr:
                break
            ptype, flags = hdr[0] >> 4, hdr[0] & 0x0F
            rem = read_varint(conn)
            if rem is None:
                break
            body = recv_exact(conn, rem) if rem else b""
            if body is None:
                break

            if ptype == 1:                                  # CONNECT
                p = 0
                plen = struct.unpack("!H", body[0:2])[0]
                p = 2 + plen + 1 + 1                        # proto name, level, flags
                cflags = body[p - 1]
                p += 2                                       # keepalive
                idlen = struct.unpack("!H", body[p:p + 2])[0]
                cid = body[p + 2:p + 2 + idlen].decode("utf-8", "replace")
                with lock:
                    clients[conn]["id"] = cid
                conn.sendall(bytes([0x20, 0x02, 0x00, 0x00]))
                log("CONNECT   id=%s from %s:%d" % (cid, addr[0], addr[1]))

            elif ptype == 3:                                # PUBLISH
                qos = (flags >> 1) & 3
                retain = flags & 1
                tlen = struct.unpack("!H", body[0:2])[0]
                topic = body[2:2 + tlen].decode("utf-8", "replace")
                p = 2 + tlen
                if qos > 0:
                    pid = struct.unpack("!H", body[p:p + 2])[0]
                    p += 2
                    conn.sendall(struct.pack("!BBH", 0x40, 0x02, pid))
                payload = body[p:]
                log("PUBLISH   %s %s   (qos=%d retain=%d from=%s)"
                    % (topic, payload.decode("utf-8", "replace"), qos, retain, cid))
                if retain:
                    retained[topic] = payload
                deliver(topic, payload)

            elif ptype == 8:                                # SUBSCRIBE
                pid = struct.unpack("!H", body[0:2])[0]
                p, granted, filters = 2, [], []
                while p < len(body):
                    flen = struct.unpack("!H", body[p:p + 2])[0]
                    f = body[p + 2:p + 2 + flen].decode()
                    rq = body[p + 2 + flen]
                    p += 3 + flen
                    filters.append(f)
                    granted.append(min(rq, 1))
                with lock:
                    clients[conn]["subs"].extend(filters)
                conn.sendall(bytes([0x90]) + encode_varint(2 + len(granted))
                             + struct.pack("!H", pid) + bytes(granted))
                log("SUBSCRIBE id=%s -> %s" % (cid, ", ".join(filters)))
                for t, pl in list(retained.items()):
                    if any(topic_matches(f, t) for f in filters):
                        send_publish(conn, t, pl)

            elif ptype == 12:                               # PINGREQ
                conn.sendall(bytes([0xD0, 0x00]))

            elif ptype == 14:                               # DISCONNECT
                log("DISCONNECT id=%s" % cid)
                break
    except OSError:
        pass
    finally:
        with lock:
            clients.pop(conn, None)
        conn.close()
        log("CLOSED    id=%s" % cid)


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(16)
    log("broker siap di %s:%d" % (HOST, PORT))
    while True:
        conn, addr = srv.accept()
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        threading.Thread(target=handle, args=(conn, addr), daemon=True).start()


main()
