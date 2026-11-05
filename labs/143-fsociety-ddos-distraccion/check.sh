#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 143.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
DAT=/opt/allsafe/.fsociety/fsociety00.dat

echo "== Lab 143 · El DDoS como distracción — comprobación =="

# 1) Hallazgos
grep -qE '^ip_ddos=10\.143\.0\.66\s*$' $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: IP del DDoS identificada (10.143.0.66)." || no "hallazgos.txt: ip_ddos= no es la IP que más pide /."
grep -qE '^ruta_persistencia=/etc/cron\.d/fsociety\s*$' $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: cron de persistencia localizado." || no "hallazgos.txt: ruta_persistencia= no es /etc/cron.d/fsociety."
grep -qE '^binario_beacon=/usr/local/bin/fsociety-beacon\s*$' $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: binario beacon localizado." || no "hallazgos.txt: binario_beacon= no es /usr/local/bin/fsociety-beacon."
grep -qE "^fsociety_dat=/opt/allsafe/\.fsociety/fsociety00\.dat\s*$" $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: fichero dejado caer localizado." || no "hallazgos.txt: fsociety_dat= no es la ruta de fsociety00.dat."
if [ -f "$DAT" ]; then
  WANT=$($SUDO sha256sum "$DAT" | cut -d' ' -f1)
  grep -qE "^sha256_dat=$WANT\s*$" $H/hallazgos.txt 2>/dev/null \
    && ok "hallazgos: sha256 de fsociety00.dat correcto." || no "hallazgos.txt: sha256_dat= no coincide con el fichero."
  ok "fsociety00.dat conservado como evidencia."
else
  no "fsociety00.dat no existe: debía conservarse como evidencia."
fi

# 2) nginx válido y con límites
$SUDO nginx -t >/dev/null 2>&1 && ok "nginx -t: configuración válida." || no "nginx -t falla."
$SUDO nginx -T 2>/dev/null | grep -qE '^\s*limit_req_zone' && ok "limit_req_zone definido." || no "Falta limit_req_zone."

# 3) La raíz se limita (429); los estáticos no
burst(){ seq 1 "$2" | xargs -P 25 -I{} curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 "http://127.0.0.1$1" | sort | uniq -c; }
B=$(burst / 60)
n200=$(echo "$B" | awk '$2==200{print $1}'); n429=$(echo "$B" | awk '$2==429{print $1}')
[ "${n429:-0}" -ge 10 ] && [ "${n200:-0}" -ge 1 ] && ok "Ráfaga de 60 a /: ${n200:-0} pasan y ${n429:-0} reciben 429." \
  || no "Ráfaga de 60 a /: esperaba algunos 200 y muchos 429 (obtuve: $(echo $B))."
S=$(burst /static/app.js 60)
[ "$(echo "$S" | awk '$2==200{print $1}')" = 60 ] && ok "/static/ sin límite (60/60 → 200)." || no "Los estáticos también se limitan: $(echo $S)."
$SUDO tail -n 500 /var/log/nginx/access.log | grep '^10\.143\.0\.66 ' | grep -q '" 429 ' && ok "El bot ya recibe 429 (access.log)." || no "En el access.log el bot aún no recibe 429."

# 4) Persistencia eliminada
[ -e /etc/cron.d/fsociety ] && no "El cron de persistencia sigue en /etc/cron.d/fsociety." || ok "Cron de persistencia eliminado."
[ -e /usr/local/bin/fsociety-beacon ] && no "El binario beacon sigue en /usr/local/bin." || ok "Binario beacon eliminado."
pgrep -fa fsociety-beacon >/dev/null 2>&1 && no "El beacon sigue ejecutándose." || ok "No queda beacon en ejecución."

# 5) Línea de tiempo
if grep -q '02:11' $H/timeline.txt 2>/dev/null && grep -q '02:14' $H/timeline.txt 2>/dev/null; then
  ok "timeline: DDoS (02:11) y persistencia (02:14) reflejados."
else
  no "timeline.txt debe recoger el inicio del DDoS (02:11) y el plantado de la persistencia (02:14)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Distracción frenada, persistencia erradicada y maniobra documentada."; exit 0; } || exit 1
