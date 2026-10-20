#!/usr/bin/env bash
# serverB (peer) ya configurado: genera sus claves, publica su clave pública en
# /shared/peer.pub, levanta wg0 en 10.8.0.2 y espera la clave pública de serverA.
set -e
umask 077
mkdir -p /shared /etc/wireguard

wg genkey | tee /etc/wireguard/peer.key | wg pubkey > /etc/wireguard/peer.pub
cp /etc/wireguard/peer.pub /shared/peer.pub

ip link add wg0 type wireguard 2>/dev/null || true
ip addr add 10.8.0.2/24 dev wg0 2>/dev/null || true
wg set wg0 listen-port 51820 private-key /etc/wireguard/peer.key
ip link set wg0 up

echo "[serverB] wg0 arriba en 10.8.0.2, esperando a serverA..."
while [ ! -s /shared/lab.pub ]; do sleep 2; done
wg set wg0 peer "$(cat /shared/lab.pub)" allowed-ips 10.8.0.1/32
echo "[serverB] peer serverA añadido."

# mantiene vivo el contenedor y reaplica si cambia la clave de serverA
LAST=""
while true; do
  if [ -s /shared/lab.pub ]; then
    CUR="$(cat /shared/lab.pub)"
    if [ "$CUR" != "$LAST" ]; then
      wg set wg0 peer "$CUR" allowed-ips 10.8.0.1/32 2>/dev/null || true
      LAST="$CUR"
    fi
  fi
  sleep 10
done
