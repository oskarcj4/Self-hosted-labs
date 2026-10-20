#!/usr/bin/env bash
# Lab 19: no hay nada malicioso. serverB se autoconfigura; este lado lo configura
# el analista. Sólo preparamos el directorio de WireGuard.
set -e
mkdir -p /etc/wireguard /shared
echo "Lab 19 listo. serverB (peer) está en 10.8.0.2. Lee /RETO.md"
