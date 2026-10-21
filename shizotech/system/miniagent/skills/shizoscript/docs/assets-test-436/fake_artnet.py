# Two fake Art-Net nodes (127.0.0.2, 127.0.0.3) that announce themselves to VibeVJ (127.0.0.1:6454) and log the
# ArtDmx they get, plus a fake console (127.0.0.4) that sends ArtDmx on universe 3, channel 10 when "console" is given.
#   py fake_artnet.py <seconds> [console] [nodes]
import socket, struct, sys, time, select

APP = ("127.0.0.1", 6454)
NODES = [("127.0.0.2", "NodeA 436", bytes([0x02, 0x36, 0, 0, 0, 0xA1])), ("127.0.0.3", "NodeB 436", bytes([0x02, 0x36, 0, 0, 0, 0xB2]))]
dur = float(sys.argv[1])
want_console = "console" in sys.argv
want_nodes = "nodes" in sys.argv


def poll_reply(ip, name, mac):
    p = bytearray(239)
    p[0:8] = b"Art-Net\0"
    p[8:10] = struct.pack("<H", 0x2100)
    p[10:14] = socket.inet_aton(ip)
    p[14:16] = struct.pack("<H", 6454)
    p[16:18] = struct.pack(">H", 1)       # firmware
    p[18] = 0; p[19] = 0                   # net, sub
    p[20:22] = struct.pack(">H", 0xFFFF)  # oem
    p[23] = 0xD0                           # status1
    p[24:26] = b"ZZ"
    nb = name.encode()[:17]; p[26:26 + len(nb)] = nb
    lb = (name + " (fake node for the #436 test)").encode()[:63]; p[44:44 + len(lb)] = lb
    p[172:174] = struct.pack(">H", 1)     # NumPorts
    p[174] = 0x80                          # PortTypes[0]: output, DMX
    p[182] = 0x80                          # GoodOutput[0]
    p[190] = 0                             # SwOut[0] universe 0
    p[201:207] = mac
    p[207:211] = socket.inet_aton(ip)
    p[211] = 1
    p[212] = 0x08
    return bytes(p)


socks = []
if want_nodes:
    for ip, name, mac in NODES:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((ip, 6454))
        socks.append((s, ip, name, mac))
console = None
if want_console:
    console = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    console.bind(("127.0.0.4", 0))

counts = {}
t0 = time.time()
last_reply = 0
seq = 0
while time.time() - t0 < dur:
    now = time.time()
    if socks and now - last_reply > 1.0:
        for s, ip, name, mac in socks:
            s.sendto(poll_reply(ip, name, mac), APP)
        last_reply = now
    if console:
        seq = (seq + 1) % 256
        dmx = bytearray(512)
        dmx[9] = int(127 + 127 * ((now * 0.5) % 1.0 > 0.5))  # channel 10
        pkt = b"Art-Net\0" + struct.pack("<H", 0x5000) + struct.pack(">H", 14) + bytes([seq, 0]) + struct.pack("<H", 3) + struct.pack(">H", 512) + bytes(dmx)
        console.sendto(pkt, APP)
    r, _, _ = select.select([s for s, *_ in socks] or [], [], [], 0.05) if socks else ([], None, None)
    if not socks:
        time.sleep(0.05)
    for s in r:
        data, addr = s.recvfrom(2048)
        ip = s.getsockname()[0]
        if data[:8] != b"Art-Net\0":
            continue
        op = struct.unpack("<H", data[8:10])[0]
        if op == 0x2000:  # ArtPoll: answer
            for s2, ip2, name, mac in socks:
                if s2 is s:
                    s2.sendto(poll_reply(ip2, name, mac), APP)
        key = (ip, hex(op))
        c = counts.setdefault(key, [0, None])
        c[0] += 1
        if op == 0x5000:
            uni = struct.unpack("<H", data[14:16])[0]
            c[1] = "universe %d, ch1..4 = %s" % (uni, list(data[18:22]))
for k, v in sorted(counts.items()):
    print(k, v)
print("done")
