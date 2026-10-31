# Resolución guiada · Lab 129

:::piensa Antes de tocar nada
Cada conexión TCP empieza con tres paquetes y cada byte perdido se reenvía.
Capturar el tráfico es la única forma de ver eso, y `tcpdump` sólo captura lo
que pasa mientras está escuchando: arráncalo antes de generar tráfico.
:::

## Paso 1 · Captura el handshake

:::pista Cómo hacerlo
```bash
sudo tcpdump -i eth0 -nn -w ~/handshake.pcap 'host 10.129.0.80 and port 8080' &
curl -s -o /dev/null http://descargas:8080/
sudo kill %1
tcpdump -nn -r ~/handshake.pcap | head -5
```
Busca `[S]`, `[S.]` y `[.]`: SYN, SYN-ACK, ACK.
:::

## Paso 2 · El número de secuencia inicial

**Pregúntate:** tcpdump y tshark muestran números relativos (empiezan en 0). ¿Cuál es el real?

:::pista Cómo comprobarlo
```bash
tshark -r ~/handshake.pcap -o tcp.relative_sequence_numbers:FALSE \
  -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' -T fields -e tcp.seq
```
:::

## Paso 3 · Un puerto cerrado

**Pregúntate:** ¿qué responde un host a un SYN dirigido a un puerto donde nadie escucha?

:::pista Cómo comprobarlo
```bash
sudo tcpdump -i eth0 -nn -c 2 'port 8081' &
curl -s --max-time 3 http://descargas:8081/
```
`[R.]` es un RST: "aquí no hay nadie". Un firewall que descarta no responde nada.
:::

## Paso 4 · Retransmisiones

:::pista Cómo hacerlo
```bash
sudo tcpdump -i eth0 -nn -s 128 -w ~/retrans.pcap 'host 10.129.0.80 and port 8080' &
curl -s -o /dev/null http://descargas:8080/grande.bin
sudo kill %1
tshark -r ~/retrans.pcap -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' | wc -l
ss -ti dst 10.129.0.80        # durante la descarga: retrans, rtt, cwnd
```
Escribe `isn_cliente=`, `respuesta_8081=RST` y `retransmisiones=` en `~/tcp.txt`.
:::

## Cómo actuar en una situación así

- **Retransmisiones altas = pérdida en el camino**: TCP la tapa, pero baja el rendimiento.
- **RST vs silencio** distingue un puerto cerrado de uno filtrado.
- `-s 128` recorta cada paquete: basta para cabeceras y ahorra disco.

## Si te atascas

- El pcap está vacío: lanzaste `curl` antes que `tcpdump` o capturaste en otra interfaz (`ip -br a`).
- 0 retransmisiones: descarga el fichero grande; el pequeño puede no perder nada.
