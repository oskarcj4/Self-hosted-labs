#!/usr/bin/env bash
# Lab 129: capturar el three-way handshake, un RST y retransmisiones reales.
set -e
echo '10.129.0.80 descargas' >> /etc/hosts
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/NET-129.txt <<'TXT'
NET-129 · cliente-129
"Las descargas desde http://descargas:8080/grande.bin van a trompicones."
Demuestra a nivel TCP qué pasa. Entregables:
  ~/handshake.pcap   captura de UNA conexión a descargas:8080 con su handshake
  ~/retrans.pcap     captura de la descarga de grande.bin
  ~/tcp.txt          isn_cliente=<número de secuencia ABSOLUTO del SYN de handshake.pcap>
                     respuesta_8081=<qué responde descargas al conectar a :8081>
                     retransmisiones=<nº de retransmisiones en retrans.pcap según tshark>
TXT
chown -R analista:analista /home/analista/ticket
for _ in $(seq 1 30); do curl -s -o /dev/null --max-time 2 http://descargas:8080/ && break; sleep 1; done
echo "Lab 129 plantado."
