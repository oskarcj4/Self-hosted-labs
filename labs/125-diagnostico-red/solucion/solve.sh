#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
ping -c 5 10.125.1.2 || true
ping -c 10 10.125.3.10 || true
traceroute -n 10.125.3.10 || true
mtr -rwnc 40 10.125.3.10 | tee $H/mtr.txt
printf 'culpable=proveedor\nsalto=10.125.2.3\n' > $H/diagnostico.txt
tc qdisc add dev eth0 root netem delay 200ms
ping -c 4 10.125.1.2 | tee $H/simulacion.txt
tc qdisc del dev eth0 root
chown analista:analista $H/*.txt
