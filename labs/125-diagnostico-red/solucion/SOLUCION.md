# Solución — Diagnóstico de red: ¿dónde se pierde?

## Qué pasaba

Ruta: `lab 10.125.1.10 → r1 → isp 10.125.2.3 → srv 10.125.3.10`. El router del
proveedor (`10.125.2.3`) añade 70 ms de retardo y 25 % de pérdida. La pérdida
aparece en ese salto y continúa hasta el destino.

## Arreglo

```bash
ping -c 5 10.125.1.2
ping -c 10 10.125.3.10
traceroute -n 10.125.3.10
mtr -rwnc 40 10.125.3.10 | tee ~/mtr.txt
printf 'culpable=proveedor\nsalto=10.125.2.3\n' > ~/diagnostico.txt

sudo tc qdisc add dev eth0 root netem delay 200ms
ping -c 4 10.125.1.2 | tee ~/simulacion.txt
sudo tc qdisc del dev eth0 root
bash /opt/lab/check.sh
```

## Más allá del lab

- Abre el ticket al proveedor con la salida de `mtr` adjunta.
- `iperf3` mide ancho de banda; `mtr -T -P 443` prueba con TCP si filtran ICMP.
- netem acepta `loss`, `duplicate`, `reorder` y `rate` para pruebas de resiliencia.
