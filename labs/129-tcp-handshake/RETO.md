# TCP: handshake, RST y retransmisiones

> Redes · tcpdump · tshark · ss -ti

## Escenario

"Las descargas desde `http://descargas:8080/grande.bin` van a
trompicones" (`~/ticket/NET-129.txt`). Antes de culpar a la aplicación,
mira qué pasa a nivel TCP.

```
cliente                         servidor
   │ ── SYN  seq=x ───────────────► │   "quiero hablar"
   │ ◄─ SYN-ACK seq=y ack=x+1 ───── │   "vale, yo también"
   │ ── ACK  ack=y+1 ─────────────► │   conexión establecida
```

Un puerto cerrado contesta al SYN con **RST**. Uno filtrado por firewall
no contesta nada (o contesta ICMP). Y cuando un segmento se pierde por el
camino, TCP lo reenvía: **retransmisión**. Pocas son normales; muchas
hunden la velocidad, porque TCP reduce su ventana cada vez que pierde.

## Objetivos

1. Captura en `~/handshake.pcap` una conexión a `descargas:8080` con su
   handshake completo. Anota en `~/tcp.txt` el número de secuencia
   **absoluto** del SYN (`isn_cliente=`). tcpdump y tshark muestran números
   relativos por defecto.
2. Comprueba qué responde el servidor al conectar a `:8081`
   (`respuesta_8081=`).
3. Captura en `~/retrans.pcap` la descarga de `grande.bin`, mira `ss -ti`
   mientras descarga y cuenta las retransmisiones con tshark
   (`retransmisiones=`).

## Comandos que te pueden servir

```bash
sudo tcpdump -i eth0 -nn 'host descargas and port 8080'
sudo tcpdump -i eth0 -nn -w ~/handshake.pcap 'port 8080'      # Ctrl+C para parar
tcpdump -nn -S -r ~/handshake.pcap                           # -S: secuencias absolutas
tshark -r ~/handshake.pcap -o tcp.relative_sequence_numbers:FALSE -Y 'tcp.flags.syn==1'
ss -ti dst 10.129.0.80                                       # rtt, retrans, cwnd
tshark -r ~/retrans.pcap -Y tcp.analysis.retransmission | wc -l
```

> Captura con `-s 128` si el fichero crece mucho: guardas cabeceras, no datos.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
