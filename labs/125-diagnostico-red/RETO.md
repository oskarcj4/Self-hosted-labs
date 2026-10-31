# Diagnóstico de red: ¿dónde está el problema?

> Redes · ping · traceroute · mtr · tc netem

## Escenario

La aplicación `srv-app` (10.125.3.10) va lentísima y a ratos no carga
(`~/ticket/NET-125.txt`). El proveedor jura que su red está perfecta.
Entre tú y el servidor hay dos routers: el de la oficina y el del proveedor.
No vale "a mí me va mal": hay que señalar el salto exacto con datos.

```
oficina-125 ──► r1-oficina ──► isp-transito ──► srv-app
10.125.1.10     10.125.1.2     10.125.2.3       10.125.3.10
```

## Objetivos

1. Mide latencia y pérdida hacia cada salto con `ping`, mira el camino con
   `traceroute` y deja un informe de `mtr` en `~/mtr.txt`.
2. Decide dónde empieza el problema y anótalo en `~/diagnostico.txt`:
   `culpable=oficina|proveedor|servidor` y `salto=<IP>`.
   Truco: una pérdida que aparece en un salto y **no** continúa en los
   siguientes suele ser el router limitando ICMP, no un fallo real. La que
   empieza en un salto y se mantiene hasta el destino, sí lo es.
3. Aprende a reproducir un enlace malo: con `tc ... netem` añade 200 ms de
   retardo a tu `eth0`, guarda un `ping -c 4 10.125.1.2` en
   `~/simulacion.txt` y **quita** netem al terminar.

## Comandos que te pueden servir

```bash
ping -c 20 10.125.1.2 ; ping -c 20 10.125.3.10
traceroute -n 10.125.3.10
mtr -rwnc 50 10.125.3.10 > ~/mtr.txt
sudo tc qdisc add dev eth0 root netem delay 200ms
sudo tc qdisc show dev eth0
sudo tc qdisc del dev eth0 root
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
