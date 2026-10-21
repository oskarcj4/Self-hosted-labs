#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 64. Cuelga catalog de verdad y espera a que tu watchdog lo
# detecte y lo recupere solo (hasta 100 s).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
W=/usr/local/bin/catalog-watchdog.sh
ALOG=/var/log/alerts/alerts.log
pid(){ systemctl show -p MainPID --value catalog; }
alerts(){ $SUDO cat "$ALOG" 2>/dev/null | wc -l; }
healthy(){ curl -fs --max-time 3 http://127.0.0.1:8300/health >/dev/null; }

echo "== Lab 64 · Healthcheck y autorrecuperación — comprobación =="

# Deja catalog sano antes de empezar (por si una prueba anterior lo dejó colgado).
$SUDO rm -f /run/catalog/hang

if [ ! -x "$W" ]; then
  no "$W no existe o no es ejecutable."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi
ok "$W existe y es ejecutable."

# ¿Quién lo lanza? Un timer de systemd o cron.
sched=""
for t in $(systemctl list-timers --all --no-legend --plain 2>/dev/null | grep -o '[^ ]*\.timer'); do
  u=$(systemctl show -p Unit --value "$t")
  if systemctl cat "$u" 2>/dev/null | grep -q 'catalog-watchdog\.sh' && systemctl is-active --quiet "$t"; then
    sched="timer $t"; [ "$(systemctl is-enabled "$t" 2>/dev/null)" = enabled ] || sched="$sched (NO habilitado)"
  fi
done
if [ -z "$sched" ] && systemctl is-active --quiet cron \
   && $SUDO grep -hsE '^[^#]*catalog-watchdog\.sh' /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* >/dev/null; then
  sched="cron"
fi
case "$sched" in
  "") no "Nada ejecuta el watchdog periódicamente (ni un timer de systemd activo ni cron)." ;;
  *"NO habilitado"*) no "El watchdog lo lanza el $sched: no sobreviviría a un reinicio." ;;
  *) ok "El watchdog se ejecuta periódicamente ($sched)." ;;
esac

# 1) Con catalog sano, el watchdog no hace nada.
p0=$(pid); a0=$(alerts)
$SUDO env -i PATH=/usr/bin:/bin timeout 20 "$W" >/dev/null 2>&1; rc=$?
if [ $rc -eq 0 ] && [ "$(pid)" = "$p0" ] && [ "$(alerts)" -eq "$a0" ]; then
  ok "Con catalog sano, el watchdog termina bien sin reiniciar ni alertar."
else
  no "Con catalog sano, el watchdog salió con $rc, reinició catalog o mandó una alerta."
fi

# 2) Colgamos catalog.
p0=$(pid); a0=$(alerts)
$SUDO touch /run/catalog/hang
if healthy; then
  no "No se consiguió colgar catalog para la prueba (¿cambiaste catalog.py?)."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi
echo "  (catalog colgado a las $(date +%T); esperando a tu watchdog, hasta 100 s...)"
t0=$(date +%s); rec=""
while [ $(( $(date +%s) - t0 )) -lt 100 ]; do
  if [ "$(pid)" != "$p0" ] && healthy; then rec=$(( $(date +%s) - t0 )); break; fi
  sleep 2
done
if [ -n "$rec" ]; then
  ok "catalog se recuperó solo en ~${rec}s (nuevo PID $(pid))."
else
  no "En 100 s nadie reinició catalog. ¿Tu curl tiene --max-time? Sin él, el watchdog se cuelga también."
  $SUDO rm -f /run/catalog/hang; $SUDO systemctl restart catalog
fi

sleep 2
a1=$(alerts)
if [ "$a1" -gt "$a0" ] && $SUDO tail -n $((a1 - a0)) "$ALOG" | grep -qi catalog; then
  ok "El equipo recibió la alerta: $($SUDO tail -n1 "$ALOG" | cut -c1-80)"
else
  no "No llegó ninguna alerta nueva que mencione 'catalog' a http://127.0.0.1:9000/alert."
fi

[ "$(systemctl is-enabled catalog)" = enabled ] && systemctl is-active --quiet catalog \
  && ok "catalog activo y habilitado." || no "catalog no está activo y habilitado."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Watchdog probado con un cuelgue real."; exit 0; } || exit 1
