#!/usr/bin/env bash
# Lab 21: no hay nada malicioso. La tarea es generar el certificado TLS y
# arrancar el servidor HTTPS. Sólo preparamos el directorio.
set -e
mkdir -p /etc/tls
echo "Lab 21 listo. Genera el cert en /etc/tls y arranca /opt/lab/tlsserver.py. Lee /RETO.md"
