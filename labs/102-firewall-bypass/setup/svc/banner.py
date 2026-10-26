#!/usr/bin/env python3
"""Servicio TCP mínimo: a quien conecta le manda una etiqueta y la bandera.
Uso: banner.py <puerto> <fichero_bandera> <etiqueta>
El punto del lab no es este servicio, sino el firewall que debería taparlo.
"""
import socket
import sys

port = int(sys.argv[1])
flag = open(sys.argv[2]).read().strip()
label = sys.argv[3]
msg = ("== %s ==\n%s\n" % (label, flag)).encode()

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", port))
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
