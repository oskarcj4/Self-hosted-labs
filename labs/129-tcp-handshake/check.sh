#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 129.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
val(){ grep -E "^$1=" $H/tcp.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r'; }
ts(){ $SUDO tshark -r "$1" -Y "$2" -T fields -e frame.number 2>/dev/null | wc -l; }

echo "== Lab 129 · TCP: handshake y retransmisiones — comprobación =="
P=$H/handshake.pcap
if [ -s $P ]; then
  syn=$(ts $P 'tcp.flags.syn==1 && tcp.flags.ack==0 && tcp.dstport==8080')
  sa=$(ts $P 'tcp.flags.syn==1 && tcp.flags.ack==1 && tcp.srcport==8080')
  ack=$(ts $P 'tcp.flags.syn==0 && tcp.flags.ack==1 && tcp.dstport==8080 && tcp.seq==1 && tcp.ack==1')
  [ "$syn" -ge 1 ] && [ "$sa" -ge 1 ] && [ "$ack" -ge 1 ] && ok "handshake.pcap contiene SYN, SYN-ACK y ACK hacia :8080." \
    || no "handshake.pcap no tiene el handshake completo (SYN=$syn SYN-ACK=$sa ACK=$ack)."
  isn=$($SUDO tshark -r $P -o tcp.relative_sequence_numbers:FALSE -Y 'tcp.flags.syn==1 && tcp.flags.ack==0 && tcp.dstport==8080' -T fields -e tcp.seq 2>/dev/null)
  echo "$isn" | grep -qx "$(val isn_cliente)" && [ -n "$(val isn_cliente)" ] && ok "isn_cliente coincide con el SYN capturado." \
    || no "tcp.txt: isn_cliente no es el número de secuencia absoluto del SYN."
else
  no "Falta ~/handshake.pcap."; no "Sin captura no se puede comprobar isn_cliente."
fi

case "$(val respuesta_8081 | tr a-z A-Z)" in
  RST|RST-ACK|RST,ACK|RST/ACK) ok "Puerto cerrado: el servidor responde con RST." ;;
  *) no "tcp.txt: respuesta_8081 no es lo que se ve en la red al conectar a un puerto cerrado." ;;
esac

R=$H/retrans.pcap
if [ -s $R ]; then
  n=$(ts $R 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission')
  big=$(ts $R 'tcp.srcport==8080 && tcp.len>0')
  [ "$big" -ge 500 ] && ok "retrans.pcap contiene la descarga ($big segmentos con datos)." || no "retrans.pcap no parece la descarga de grande.bin."
  [ "$n" -ge 1 ] && ok "Hay $n retransmisiones en la captura (pérdida real en el camino)." || no "retrans.pcap no tiene retransmisiones."
  [ "$(val retransmisiones)" = "$n" ] && ok "retransmisiones=$n coincide con tshark." || no "tcp.txt: retransmisiones= no coincide con lo que cuenta tshark en tu captura ($n)."
else
  no "Falta ~/retrans.pcap."; no "Sin captura de la descarga."; no "Sin captura no se pueden contar retransmisiones."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 TCP leído paquete a paquete."; exit 0; } || exit 1
