# Solución — TCP: handshake y retransmisiones

## Qué pasaba

El servidor `descargas` (`10.129.0.80`) sirve HTTP en `8080` sobre un enlace
con 6 % de pérdida. `8081` está cerrado y responde RST.

## Arreglo

```bash
H=~
sudo tcpdump -i eth0 -nn -w $H/handshake.pcap 'host 10.129.0.80 and port 8080' & P=$!
sleep 1; curl -s -o /dev/null http://descargas:8080/; sleep 2; sudo kill $P
ISN=$(tshark -r $H/handshake.pcap -o tcp.relative_sequence_numbers:FALSE \
  -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' -T fields -e tcp.seq | head -1)

sudo tcpdump -i eth0 -nn -c 2 'host 10.129.0.80 and port 8081' &
sleep 1; curl -s --max-time 3 http://descargas:8081/

sudo tcpdump -i eth0 -nn -s 128 -w $H/retrans.pcap 'host 10.129.0.80 and port 8080' & P=$!
sleep 1; curl -s -o /dev/null http://descargas:8080/grande.bin; sleep 1; sudo kill $P
N=$(tshark -r $H/retrans.pcap -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' \
  -T fields -e frame.number | wc -l)
printf 'isn_cliente=%s\nrespuesta_8081=RST\nretransmisiones=%s\n' "$ISN" "$N" > $H/tcp.txt
sudo chown analista:analista $H/*.pcap
bash /opt/lab/check.sh
```

## Más allá del lab

- Abre los pcap en Wireshark: Statistics → TCP Stream Graphs muestra la ventana y las pérdidas.
- Un ISN aleatorio impide adivinar la secuencia e inyectar paquetes en conexiones ajenas.
