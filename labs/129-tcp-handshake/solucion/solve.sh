#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
tcpdump -i eth0 -nn -w $H/handshake.pcap 'host 10.129.0.80 and port 8080' & P=$!
sleep 1; curl -s -o /dev/null --retry 3 http://descargas:8080/; sleep 2; kill $P; wait $P 2>/dev/null || true
tcpdump -nn -r $H/handshake.pcap | head -5
ISN=$(tshark -r $H/handshake.pcap -o tcp.relative_sequence_numbers:FALSE -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' -T fields -e tcp.seq | head -1)
tcpdump -i eth0 -nn -c 2 'host 10.129.0.80 and port 8081' & P=$!
sleep 1; curl -s --max-time 3 http://descargas:8081/ || true; wait $P 2>/dev/null || true
tcpdump -i eth0 -nn -s 128 -w $H/retrans.pcap 'host 10.129.0.80 and port 8080' & P=$!
sleep 1; curl -s -o /dev/null http://descargas:8080/grande.bin & C=$!
sleep 2; ss -ti dst 10.129.0.80 || true; wait $C; sleep 1; kill $P; wait $P 2>/dev/null || true
N=$(tshark -r $H/retrans.pcap -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' -T fields -e frame.number | wc -l)
printf 'isn_cliente=%s\nrespuesta_8081=RST\nretransmisiones=%s\n' "$ISN" "$N" > $H/tcp.txt
chown analista:analista $H/*.pcap $H/tcp.txt
