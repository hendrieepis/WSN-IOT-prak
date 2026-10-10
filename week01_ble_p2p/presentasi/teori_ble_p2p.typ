// Kuliah teori Modul 01 — BLE point-to-point
// Sumber: ../README.md, ../src/node1/main.cpp, ../src/node2/main.cpp,
// dan ../logserial.md. Diagram bersifat konseptual; tidak memuat data ukur rekaan.
// Kompilasi: typst compile teori_ble_p2p.typ

#set page(width: 960pt, height: 540pt, margin: 0pt, fill: rgb("#F6F8F7"))
#set text(font: "Segoe UI", lang: "id")

#let navy = rgb("#14283B")
#let teal = rgb("#007E7A")
#let amber = rgb("#D89326")
#let ink = rgb("#24384A")
#let muted = rgb("#617587")
#let linec = rgb("#CBD6D8")
#let pale = rgb("#E6F3F0")
#let warm = rgb("#FFF2D9")
#let white = rgb("#FFFFFF")
#let red = rgb("#B95148")

#let at(x, y, w, size, content, color: ink, weight: "regular") = {
  place(top + left, dx: x, dy: y)[
    #block(width: w)[#text(size: size, fill: color, weight: weight, content)]
  ]
}
#let bar(x, y, w, h, color) = {
  place(top + left, dx: x, dy: y)[#rect(width: w, height: h, fill: color, stroke: none)]
}
#let rule(x, y, w, color: linec, thickness: 1pt) = {
  place(top + left, dx: x, dy: y)[#line(length: w, stroke: thickness + color)]
}
#let vline(x, y, h, color: linec, thickness: 1pt) = {
  place(top + left, dx: x, dy: y)[#line(start: (0pt, 0pt), end: (0pt, h), stroke: thickness + color)]
}
#let panel(x, y, w, h, fill) = {
  place(top + left, dx: x, dy: y)[#rect(width: w, height: h, radius: 9pt, fill: fill, stroke: none)]
}
#let frame(n, title, body) = {
  pagebreak()
  block(width: 960pt, height: 540pt)[
    #bar(0pt, 0pt, 10pt, 540pt, teal)
    #at(47pt, 25pt, 510pt, 12pt, [MODUL 01  /  BLE POINT-TO-POINT], color: teal, weight: "bold")
    #at(47pt, 54pt, 860pt, 30pt, title, color: navy, weight: "bold")
    #rule(47pt, 105pt, 866pt)
    #body
    #at(47pt, 502pt, 530pt, 10pt, [Sumber: README dan firmware week01_ble_p2p], color: muted)
    #at(868pt, 502pt, 56pt, 11pt, str(n) + " / 13", color: muted)
  ]
}

// 1 — sampul
#block(width: 960pt, height: 540pt)[
  #bar(0pt, 0pt, 960pt, 540pt, navy)
  #bar(0pt, 0pt, 11pt, 540pt, teal)
  #at(64pt, 67pt, 570pt, 15pt, [IOT COMMUNICATION LAB  /  TEORI], color: rgb("#81D7CD"), weight: "bold")
  #at(64pt, 170pt, 770pt, 51pt, [Bagaimana dua perangkat membentuk tautan BLE?], color: white, weight: "bold")
  #at(67pt, 357pt, 740pt, 23pt, [Advertising, active scanning, koneksi, dan bukti dari kedua sisi], color: rgb("#D9E7EA"))
  #at(67pt, 461pt, 500pt, 16pt, [Week 01 · ESP32-H2 · Point-to-point], color: rgb("#81D7CD"))
]

// 2 — peta konsep
#frame(2, [Tiga tahap yang sering tercampur], [
  #at(52pt, 138pt, 845pt, 19pt, [Central harus menemukan peripheral sebelum meminta tautan.], color: muted)
  #panel(52pt, 212pt, 245pt, 154pt, pale)
  #panel(357pt, 212pt, 245pt, 154pt, warm)
  #panel(662pt, 212pt, 245pt, 154pt, rgb("#E9ECEF"))
  #at(72pt, 232pt, 205pt, 21pt, [1  Discovery], color: teal, weight: "bold")
  #at(72pt, 283pt, 210pt, 17pt, [Advertising membuat Node1 terlihat oleh pemindai.])
  #at(377pt, 232pt, 205pt, 21pt, [2  Connection], color: navy, weight: "bold")
  #at(377pt, 283pt, 210pt, 17pt, [Node2 memilih Node1 lalu membentuk tautan.])
  #at(682pt, 232pt, 205pt, 21pt, [3  Data aplikasi], color: muted, weight: "bold")
  #at(682pt, 283pt, 210pt, 17pt, [Baru mungkin setelah ada characteristic.])
  #at(307pt, 274pt, 40pt, 29pt, [→], color: teal, weight: "bold")
  #at(612pt, 274pt, 40pt, 29pt, [→], color: teal, weight: "bold")
  #at(54pt, 421pt, 830pt, 20pt, [Fokus week01: tahap 1 dan 2. Firmware belum membawa payload aplikasi.], color: navy, weight: "bold")
])

// 3 — peran
#frame(3, [Peran menentukan siapa memulai], [
  #panel(58pt, 173pt, 340pt, 219pt, pale)
  #panel(562pt, 173pt, 340pt, 219pt, warm)
  #at(85pt, 199pt, 290pt, 26pt, [Node1 · Peripheral], color: teal, weight: "bold")
  #at(85pt, 263pt, 290pt, 19pt, [Menyiarkan identitas dan menunggu permintaan koneksi.])
  #at(589pt, 199pt, 290pt, 26pt, [Node2 · Central], color: navy, weight: "bold")
  #at(589pt, 263pt, 290pt, 19pt, [Memindai, memilih target, lalu meminta koneksi.])
  #at(408pt, 241pt, 145pt, 16pt, [Advertising →], color: teal, weight: "bold")
  #at(405pt, 313pt, 155pt, 15pt, [← Connect request], color: amber, weight: "bold")
  #at(52pt, 429pt, 850pt, 18pt, [Pada modul ini peripheral juga GATT server, sedangkan central menjadi client.], color: muted)
])

// 4 — paket dan scan response
#frame(4, [Identitas tersebar di dua pesan radio], [
  #at(53pt, 139pt, 845pt, 19pt, [Node1 memakai Service UUID 128-bit. Namanya ditempatkan di scan response agar muat.], color: muted)
  #panel(60pt, 211pt, 370pt, 163pt, pale)
  #panel(530pt, 211pt, 370pt, 163pt, warm)
  #at(82pt, 230pt, 330pt, 22pt, [Advertising], color: teal, weight: "bold")
  #at(82pt, 279pt, 330pt, 19pt, [Service UUID: layanan yang ditawarkan])
  #at(552pt, 230pt, 330pt, 22pt, [Scan response], color: navy, weight: "bold")
  #at(552pt, 279pt, 330pt, 19pt, [Nama perangkat: NODE1_H2])
  #at(54pt, 419pt, 840pt, 20pt, [Advertising menunjukkan kandidat. Scan response melengkapi informasi untuk memilihnya.], color: navy, weight: "bold")
])

// 5 — active scan
#frame(5, [Mengapa Node2 memakai active scan?], [
  #at(58pt, 139pt, 835pt, 19pt, [Filter kode Node2 membaca nama lewat getName(). Nama itu ada di scan response.], color: muted)
  #at(82pt, 207pt, 235pt, 20pt, [Node1 · advertiser], color: teal, weight: "bold")
  #at(641pt, 207pt, 240pt, 20pt, [Node2 · active scanner], color: navy, weight: "bold")
  #vline(181pt, 245pt, 179pt)
  #vline(751pt, 245pt, 179pt)
  #rule(184pt, 270pt, 563pt, color: teal, thickness: 2pt)
  #at(697pt, 252pt, 28pt, 22pt, [→], color: teal, weight: "bold")
  #at(347pt, 245pt, 260pt, 16pt, [Advertising: Service UUID])
  #rule(184pt, 321pt, 563pt, color: amber, thickness: 2pt)
  #at(230pt, 302pt, 26pt, 22pt, [←], color: amber, weight: "bold")
  #at(388pt, 297pt, 180pt, 16pt, [Scan request])
  #rule(184pt, 373pt, 563pt, color: teal, thickness: 2pt)
  #at(697pt, 354pt, 28pt, 22pt, [→], color: teal, weight: "bold")
  #at(343pt, 347pt, 290pt, 16pt, [Scan response: NODE1_H2])
  #at(58pt, 444pt, 850pt, 18pt, [Dengan passive scan, nama yang dibutuhkan filter ini dapat tidak terlihat.], color: red, weight: "bold")
])

// 6 — pemilihan target
#frame(6, [Dari hasil scan ke alamat tujuan], [
  #at(53pt, 141pt, 850pt, 19pt, [Node2 tidak menyambung ke semua perangkat BLE yang terdengar.], color: muted)
  #panel(53pt, 210pt, 236pt, 160pt, pale)
  #panel(362pt, 210pt, 236pt, 160pt, pale)
  #panel(671pt, 210pt, 236pt, 160pt, pale)
  #at(76pt, 228pt, 190pt, 21pt, [Hasil scan], color: teal, weight: "bold")
  #at(76pt, 275pt, 190pt, 17pt, [Baca nama dari respons pemindaian.])
  #at(385pt, 228pt, 190pt, 21pt, [Cocokkan nama], color: teal, weight: "bold")
  #at(385pt, 275pt, 190pt, 17pt, [Hanya NODE1_H2 lolos filter.])
  #at(694pt, 228pt, 190pt, 21pt, [Simpan alamat], color: teal, weight: "bold")
  #at(694pt, 275pt, 190pt, 17pt, [Salin alamat, hentikan scan, lalu connect.])
  #at(303pt, 275pt, 38pt, 27pt, [→], color: teal, weight: "bold")
  #at(612pt, 275pt, 38pt, 27pt, [→], color: teal, weight: "bold")
  #at(55pt, 424pt, 840pt, 18pt, [Nama memandu pemilihan; alamat hasil scan menentukan perangkat yang diminta terkoneksi.], color: navy, weight: "bold")
])

// 7 — sequence diagram end-to-end
#frame(7, [Urutan pembentukan tautan], [
  #at(96pt, 139pt, 235pt, 20pt, [Node1 · peripheral], color: teal, weight: "bold")
  #at(638pt, 139pt, 240pt, 20pt, [Node2 · central], color: navy, weight: "bold")
  #vline(194pt, 181pt, 258pt)
  #vline(756pt, 181pt, 258pt)
  #rule(197pt, 205pt, 554pt, color: teal, thickness: 2pt)
  #at(704pt, 185pt, 27pt, 23pt, [→], color: teal, weight: "bold")
  #at(340pt, 182pt, 260pt, 15pt, [Advertising + UUID])
  #rule(197pt, 255pt, 554pt, color: amber, thickness: 2pt)
  #at(237pt, 235pt, 27pt, 23pt, [←], color: amber, weight: "bold")
  #at(408pt, 231pt, 170pt, 15pt, [Scan request])
  #rule(197pt, 305pt, 554pt, color: teal, thickness: 2pt)
  #at(704pt, 285pt, 27pt, 23pt, [→], color: teal, weight: "bold")
  #at(346pt, 281pt, 250pt, 15pt, [Scan response + nama])
  #rule(197pt, 355pt, 554pt, color: amber, thickness: 2pt)
  #at(237pt, 335pt, 27pt, 23pt, [←], color: amber, weight: "bold")
  #at(419pt, 331pt, 165pt, 15pt, [Connect])
  #rule(197pt, 407pt, 554pt, color: teal, thickness: 3pt)
  #at(368pt, 380pt, 238pt, 17pt, [Tautan aktif; cek service], color: navy, weight: "bold")
  #at(53pt, 453pt, 850pt, 17pt, [Service check terjadi setelah koneksi. Kode baru mencetak “Koneksi berhasil” sesudah UUID cocok.], color: muted)
])

// 8 — GATT boundary
#frame(8, [Tautan aktif belum berarti data terkirim], [
  #panel(55pt, 163pt, 850pt, 76pt, pale)
  #panel(55pt, 256pt, 850pt, 76pt, warm)
  #panel(55pt, 349pt, 850pt, 76pt, rgb("#E9ECEF"))
  #at(76pt, 180pt, 185pt, 20pt, [Koneksi radio], color: teal, weight: "bold")
  #at(291pt, 180pt, 580pt, 18pt, [Dua perangkat menyepakati tautan BLE.])
  #at(76pt, 273pt, 185pt, 20pt, [GATT service], color: navy, weight: "bold")
  #at(291pt, 273pt, 580pt, 18pt, [Node2 menemukan Service UUID yang diharapkan.])
  #at(76pt, 366pt, 185pt, 20pt, [Characteristic], color: muted, weight: "bold")
  #at(291pt, 366pt, 580pt, 18pt, [Belum dibuat pada week01, sehingga tidak ada payload aplikasi.])
  #at(55pt, 451pt, 850pt, 18pt, [Ini sengaja: kualitas tautan diperiksa sebelum mekanisme data ditambahkan pada week02.], color: navy, weight: "bold")
])

// 9 — heartbeat
#frame(9, [Apa yang dibuktikan heartbeat?], [
  #at(54pt, 143pt, 850pt, 19pt, [Setiap board membaca status koneksi lokalnya lalu mencetak log tiap 5 detik.], color: muted)
  #panel(58pt, 208pt, 395pt, 126pt, pale)
  #panel(507pt, 208pt, 395pt, 126pt, pale)
  #at(77pt, 225pt, 330pt, 17pt, [Serial Node1], color: teal, weight: "bold")
  #at(77pt, 269pt, 350pt, 16pt, [Status: H2 ↔ H2 terhubung])
  #at(526pt, 225pt, 330pt, 17pt, [Serial Node2], color: teal, weight: "bold")
  #at(526pt, 269pt, 350pt, 16pt, [Status: H2 ↔ H2 terhubung])
  #at(57pt, 379pt, 842pt, 21pt, [Dua log yang tampak serupa belum menunjukkan respons baru dari lawan bicara.], color: red, weight: "bold")
  #at(57pt, 427pt, 842pt, 18pt, [Reset salah satu board, lalu lihat perubahan status pada board yang tetap menyala.], color: ink)
])

// 10 — disconnect
#frame(10, [Reset memperlihatkan dua sudut pandang], [
  #at(56pt, 139pt, 846pt, 19pt, [Perangkat yang di-reset dan perangkat yang tetap hidup menghasilkan log berbeda.], color: muted)
  #rule(55pt, 213pt, 850pt)
  #at(57pt, 178pt, 235pt, 18pt, [UJI], color: teal, weight: "bold")
  #at(324pt, 178pt, 260pt, 18pt, [YANG DIAMATI], color: teal, weight: "bold")
  #at(57pt, 239pt, 220pt, 20pt, [Reset Node1], color: navy, weight: "bold")
  #at(324pt, 239pt, 555pt, 18pt, [Node2 mendeteksi tautan putus setelah timeout. Node1 mulai boot ulang.])
  #rule(55pt, 315pt, 850pt)
  #at(57pt, 342pt, 220pt, 20pt, [Reset Node2], color: navy, weight: "bold")
  #at(324pt, 342pt, 555pt, 18pt, [Node1 menerima onDisconnect dan memulai advertising lagi.])
  #at(57pt, 441pt, 840pt, 17pt, [Kode Node2 hanya scan sekali saat setup; setelah disconnect ia belum otomatis scan ulang.], color: red, weight: "bold")
])

// 11 — RSSI
#frame(11, [RSSI adalah petunjuk, bukan vonis], [
  #at(55pt, 140pt, 840pt, 19pt, [RSSI mengukur kekuatan sinyal yang diterima, dalam dBm. Nilai mendekati nol lebih kuat.], color: muted)
  #at(63pt, 210pt, 210pt, 40pt, [−50 dBm], color: teal, weight: "bold")
  #at(352pt, 222pt, 235pt, 25pt, [lebih kuat daripada], color: ink)
  #at(691pt, 210pt, 212pt, 40pt, [−90 dBm], color: red, weight: "bold")
  #rule(60pt, 282pt, 840pt, color: linec, thickness: 2pt)
  #at(58pt, 327pt, 840pt, 20pt, [Jarak dan penghalang sering melemahkan sinyal; lingkungan radio juga dapat berubah.], color: ink)
  #at(58pt, 389pt, 840pt, 20pt, [Karena itu ukur RSSI bersama keberhasilan koneksi dan waktu scan-ke-connected.], color: navy, weight: "bold")
  #at(58pt, 447pt, 840pt, 15pt, [RSSI baru muncul di heartbeat Node2 setelah kode pengukuran ditambahkan.], color: muted)
])

// 12 — conceptual check
#frame(12, [Uji pemahaman], [
  #metadata("pertanyaan") <pertanyaan>
  #at(55pt, 145pt, 840pt, 26pt, [Mengapa passive scan dapat gagal menemukan NODE1_H2 pada firmware ini?], color: navy, weight: "bold")
  #at(57pt, 250pt, 840pt, 21pt, [Apa perbedaan bukti “Node1 ditemukan”, “Terhubung ke Node1”, dan “Koneksi berhasil”?], color: ink)
  #at(57pt, 346pt, 840pt, 21pt, [Jika Node1 di-reset, log mana yang membuktikan Node2 menyadari tautan putus?], color: ink)
  #at(57pt, 448pt, 840pt, 17pt, [#link(<pembahasan>)[Lihat pembahasan →]], color: teal, weight: "bold")
])

// 13 — jawaban untuk pengajar
#frame(13, [Pembahasan ringkas], [
  #metadata("pembahasan") <pembahasan>
  #at(56pt, 143pt, 845pt, 19pt, [1], color: teal, weight: "bold")
  #at(91pt, 143pt, 805pt, 18pt, [Nama NODE1_H2 ada pada scan response. Active scan meminta respons itu; passive scan tidak.])
  #rule(57pt, 232pt, 839pt)
  #at(56pt, 255pt, 845pt, 19pt, [2], color: teal, weight: "bold")
  #at(91pt, 255pt, 805pt, 18pt, [“Ditemukan” berarti filter nama cocok. “Terhubung” berarti link terbentuk. “Koneksi berhasil” berarti service yang diharapkan juga ditemukan.])
  #rule(57pt, 361pt, 839pt)
  #at(56pt, 385pt, 845pt, 19pt, [3], color: teal, weight: "bold")
  #at(91pt, 385pt, 805pt, 18pt, [Node2 mencetak “Terputus dari Node1” setelah tautan hilang. Node1 sedang boot ulang, jadi tidak melaporkan disconnect dari sesi lama.])
  #at(57pt, 468pt, 840pt, 13pt, [#link(<pertanyaan>)[← Kembali ke pertanyaan]], color: teal)
])
