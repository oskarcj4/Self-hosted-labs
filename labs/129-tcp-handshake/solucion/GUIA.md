# Resolución guiada · Lab 129

:::piensa Míralo en el cable
Toda conexión TCP empieza con tres paquetes (SYN, SYN-ACK, ACK), y cada
segmento que se pierde por el camino se reenvía. Una descarga "a trompicones"
suele ser eso: pérdidas y reenvíos que la aplicación ni ve. Capturar el
tráfico es la única forma de verlo, y `tcpdump` sólo captura lo que pasa
mientras escucha: arráncalo **antes** de generar tráfico.
:::

**El plan:** (1) capturar un handshake, (2) sacar el número de secuencia
real, (3) ver qué responde un puerto cerrado y (4) contar retransmisiones.

## Paso 1 · Captura el handshake

:::pista Cómo hacerlo
```bash
sudo tcpdump -i eth0 -nn -w ~/handshake.pcap 'host 10.129.0.80 and port 8080' &
sleep 1
curl -s -o /dev/null http://descargas:8080/
sleep 1; sudo kill %1
tcpdump -nn -r ~/handshake.pcap | head -5
```
- `-i eth0`: la interfaz a escuchar; `-nn`: sin resolver nombres ni puertos.
- `-w fichero`: guarda los paquetes en formato pcap en vez de imprimirlos.
- `'host … and port …'` es un **filtro BPF**: sólo ese tráfico.
- `&` deja `tcpdump` corriendo en segundo plano; `%1` es ese trabajo, y
  `kill %1` lo para.
- `-r fichero` lee una captura guardada.

**Qué deberías ver:** `Flags [S]`, `[S.]` y `[.]`: SYN, SYN-ACK y ACK.
:::

## Paso 2 · El número de secuencia inicial

**Pregúntate:** tcpdump y tshark empiezan a contar las secuencias en 0 para
que sean legibles. ¿Cuál es el número real?

:::pista Cómo hacerlo
```bash
tshark -r ~/handshake.pcap -o tcp.relative_sequence_numbers:FALSE \
  -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' -T fields -e tcp.seq
```
- `-o tcp.relative_sequence_numbers:FALSE` desactiva la numeración relativa.
- `-Y` filtra lo que se muestra: aquí, el SYN del cliente (SYN sin ACK).
- `-T fields -e tcp.seq` imprime sólo ese campo.

**Qué deberías ver:** un número grande y aleatorio (el *ISN*). Es aleatorio a
propósito: si fuera predecible, un atacante podría inyectar paquetes en
conexiones ajenas. (`tcpdump -S` también muestra los absolutos.)
:::

## Paso 3 · Un puerto cerrado

**Pregúntate:** ¿qué responde un equipo a un SYN dirigido a un puerto donde
nadie escucha?

:::pista Cómo hacerlo
```bash
sudo tcpdump -i eth0 -nn -c 2 'host 10.129.0.80 and port 8081' &
sleep 1; curl -s --max-time 3 http://descargas:8081/; wait
```
`-c 2` para tras 2 paquetes; `wait` espera a que termine.

**Qué deberías ver:** tu `[S]` y un `[R.]` de vuelta: un **RST**, "aquí no hay
nadie". Un puerto *filtrado* por un firewall no respondería nada (o un ICMP).
:::

## Paso 4 · Retransmisiones

:::pista Cómo hacerlo
```bash
sudo tcpdump -i eth0 -nn -s 128 -w ~/retrans.pcap 'host 10.129.0.80 and port 8080' &
sleep 1
curl -s -o /dev/null http://descargas:8080/grande.bin &
sleep 2; ss -ti dst 10.129.0.80
wait %2; sleep 1; sudo kill %1
tshark -r ~/retrans.pcap -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' | wc -l
```
- `-s 128` guarda sólo los primeros 128 bytes de cada paquete: bastan para las
  cabeceras y el fichero no crece con los datos.
- `ss -ti` enseña la información interna de cada conexión TCP: `rtt` (tiempo
  de ida y vuelta), `retrans` (reenvíos) y `cwnd` (ventana de congestión: cuántos
  datos envía sin esperar confirmación; baja cada vez que hay pérdidas).
- tshark marca como `tcp.analysis.retransmission` los segmentos reenviados.

Escribe los resultados:
```bash
cat > ~/tcp.txt <<'T'
isn_cliente=<el número del paso 2>
respuesta_8081=RST
retransmisiones=<el número de wc -l>
T
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- Retransmisiones altas = pérdidas en el camino. TCP las oculta, pero reduce
  su ventana y el rendimiento cae. Busca el enlace que pierde, no culpes a la
  aplicación.
- RST frente a silencio distingue un puerto cerrado de uno filtrado.
- Captura con filtro y con `-s` en producción: una captura sin límites llena
  el disco.

## Si te atascas

- **El pcap está vacío:** lanzaste `curl` antes que `tcpdump`, o la interfaz no
  es `eth0` (`ip -br a`).
- **0 retransmisiones:** captura la descarga de `grande.bin`, no la página
  pequeña.
- **`kill %1` no encuentra el trabajo:** lanzaste `tcpdump` en otra terminal;
  páralo con Ctrl+C allí.
