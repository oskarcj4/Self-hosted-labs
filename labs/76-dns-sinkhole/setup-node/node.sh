#!/bin/bash
# upstream: el DNS de "Internet" (todo resuelve a 203.0.113.10).
# client:   un puesto que navega; con INFECTED=1, además, el malware hace beacon.
if [ "$ROLE" = upstream ]; then
  exec dnsmasq --keep-in-foreground --no-resolv --no-hosts --address=/#/203.0.113.10
fi

echo "nameserver 10.76.76.53" > /etc/resolv.conf
SITIOS=(www.periodico.example mail.empresa.example api.pagos-proveedor.example
        cdn.proveedor.example analytics.proveedor.example www.buscador.example)
n=0
while :; do
  n=$((n + 1))
  getent ahostsv4 "${SITIOS[RANDOM % ${#SITIOS[@]}]}" >/dev/null
  if [ "${INFECTED:-0}" = 1 ]; then
    # Beacon al C2: subdominio aleatorio (evita cachés) y, a veces, el panel.
    getent ahostsv4 "$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n').cdn-telemetria.xyz" >/dev/null
    [ $((n % 4)) -eq 0 ] && getent ahostsv4 panel.malsrv.top >/dev/null
  fi
  sleep 2
done
