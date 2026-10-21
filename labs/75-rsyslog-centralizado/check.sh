#!/usr/bin/env bash
# Validador del Lab 75. Tira el colector durante 15 s y comprueba que, al
# volver, no falta ni un pedido de web-02.
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
F=/var/log/remote/web-02/pagos-web.log
last(){ grep -o 'pedido=[0-9]*' "$F" 2>/dev/null | tail -1 | cut -d= -f2; }
end(){ echo "---------------------------------------"; echo "Resultado: $pass superados, $fail pendientes."; }

echo "== Lab 75 · rsyslog centralizado — comprobación =="

systemctl is-active --quiet rsyslog && ok "rsyslog está en marcha en log-01." || no "rsyslog no está en marcha en log-01."
ss -Hltn 'sport = :514' | grep -q . && ok "log-01 escucha en TCP 514." || no "log-01 no escucha en TCP 514."

n0=$(last); sleep 4; n1=$(last)
if [ -n "$n1" ] && [ "${n1:-0}" -gt "${n0:-0}" ]; then
  ok "Llegan logs de web-02 a $F (pedido=$n1)."
else
  no "No llegan logs nuevos de web-02 a $F."
  end; exit 1
fi

if ss -Hntp state established '( sport = :514 )' | grep -q '10\.76\.75\.20'; then
  ok "web-02 está conectado por TCP."
else
  no "No hay conexión TCP de web-02 (10.76.75.20) al 514: ¿sigue enviando por UDP?"
fi

ls /var/log/remote/web-02/ 2>/dev/null | grep -qv '^pagos-web.log$' \
  && ok "Hay ficheros separados por programa ($(ls /var/log/remote/web-02 | tr '\n' ' '))." \
  || no "Sólo hay pagos-web.log: el resto de programas de web-02 (sshd, rsyslogd...) debe ir a su propio fichero."

sz=$(stat -c %s /var/log/syslog 2>/dev/null || echo 0); sleep 3
tail -c +$((sz + 1)) /var/log/syslog 2>/dev/null | grep -q 'pagos-web' \
  && no "Los logs de web-02 también acaban en /var/log/syslog de log-01: separa la entrada remota (ruleset)." \
  || ok "Los logs remotos no se mezclan con /var/log/syslog de log-01."

# Caída del colector.
start=$(last)
echo "  (parando el colector 15 s; último pedido recibido: $start)"
systemctl stop syslog.socket rsyslog.service 2>/dev/null
sleep 15
systemctl start rsyslog.service syslog.socket 2>/dev/null
down_end=$(( start + 15 ))
echo "  (colector de vuelta; esperando a que web-02 reenvíe lo pendiente, hasta 75 s...)"
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 75 ]; do
  [ "$(last)" -gt $(( down_end + 3 )) ] 2>/dev/null && break
  sleep 3
done
got=$(grep -o 'pedido=[0-9]*' "$F" | cut -d= -f2 | awk -v a="$start" '$1 >= a' | sort -n | uniq)
lo=$(echo "$got" | head -1); hi=$(echo "$got" | tail -1); cnt=$(echo "$got" | grep -c .)
if [ -n "$hi" ] && [ "$hi" -gt $(( down_end + 3 )) ] && [ $(( hi - lo + 1 )) -eq "$cnt" ]; then
  ok "Cero huecos: llegaron los pedidos $lo..$hi, también los de la caída."
else
  miss=$(( ${hi:-0} - ${lo:-0} + 1 - ${cnt:-0} ))
  no "Tras la caída faltan $miss pedidos entre $lo y $hi (o no volvieron a llegar): falta una cola con reintentos en web-02."
fi

end
[ "$fail" -eq 0 ] && { echo "🎉 Logs centralizados por TCP y sin pérdidas aunque caiga el colector."; exit 0; } || exit 1
