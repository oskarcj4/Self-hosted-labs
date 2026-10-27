#!/usr/bin/env python3
"""Servicio TCP mínimo: a quien conecta le manda una etiqueta y la bandera.
Uso: banner.py <puerto> <fichero_bandera> <etiqueta> [bind]
La consola admin interna (8080) es un servicio de la zona protegida; el
firewall la tapa desde fuera. El punto del lab es cruzar el firewall por el
panel de gestión sin parchear, no este servicio.
"""
import socket
import sys

port = int(sys.argv[1])
flag = open(sys.argv[2]).read().strip()
label = sys.argv[3]
bind = sys.argv[4] if len(sys.argv) > 4 else "0.0.0.0"
msg = ("== %s ==\n%s\n" % (label, flag)).encode()

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((bind, port))
s.listen(16)
while True:
    try:
        conn, _ = s.accept()
    except OSError:
        continue
    try:
        conn.sendall(msg)
    except OSError:
        pass
    finally:
        conn.close()
