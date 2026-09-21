#!/usr/bin/env python3
"""Server HTTP penerima POST untuk Modul 13, pengganti httpbin.org.

Dipakai bila jaringan memblokir akses keluar (gejala: `HTTP -1` pada Serial
Monitor gateway). Jalankan di laptop, lalu arahkan SERVER_URL firmware ke
alamat IP laptop:

    python3 tools/http_sink.py                 # dengar di 0.0.0.0:8080
    // src/c6_gateway/main.cpp
    const char *SERVER_URL = "http://192.168.110.74:8080/post";

Setiap POST dicetak dengan timestamp dan isinya, lalu dibalas HTTP 200 + JSON,
sehingga `http.POST()` di firmware mengembalikan 200 seperti httpbin.
"""
import json, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST, PORT = "0.0.0.0", 8080
t0 = time.time()
count = 0


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        global count
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode("utf-8", "replace")
        count += 1
        print("[%8.3f] #%-4d POST %s from %s  ->  %s"
              % (time.time() - t0, count, self.path, self.client_address[0], body),
              flush=True)
        resp = json.dumps({"ok": True, "seq": count, "echo": body}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"http_sink aktif; kirim POST ke /post\n")

    def log_message(self, *args):
        pass          # senyapkan log bawaan, kita cetak sendiri


print("[   0.000] http_sink siap di %s:%d (POST -> HTTP 200)" % (HOST, PORT), flush=True)
ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
