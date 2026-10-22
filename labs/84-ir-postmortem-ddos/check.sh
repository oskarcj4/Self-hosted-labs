#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 84.
PM=/home/analista/postmortem.md
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 84 — comprobación =="
R="$(sudo iptables -S INPUT 2>/dev/null)"

# 1) Mitigación en firewall: bloqueo de rango O rate limit al 80
blocked=0
echo "$R" | grep -qE '203\.0\.113\.0/24 .*-j (DROP|REJECT)' && blocked=1
echo "$R" | grep -qE '198\.51\.100\.0/24 .*-j (DROP|REJECT)' && blocked=1
ratelimited=0
echo "$R" | grep -qiE 'dport 80 .*(hashlimit|connlimit|limit)' && ratelimited=1
if [ "$blocked" = 1 ] || [ "$ratelimited" = 1 ]; then
  ok "Hay mitigación en iptables (bloqueo de rango o rate limit al 80)."
else
  no "Aplica mitigación en iptables: bloquea los rangos de la blocklist o limita la tasa al 80."
fi

# 2) Postmortem con las secciones clave
if [ -f "$PM" ]; then
  hits=0
  grep -qiE 'impacto|impact' "$PM" && hits=$((hits+1))
  grep -qiE 'cronolog|timeline|línea de tiempo|linea de tiempo' "$PM" && hits=$((hits+1))
  grep -qiE 'mitig' "$PM" && hits=$((hits+1))
  grep -qiE 'prevenc|prevent|seguimiento|follow' "$PM" && hits=$((hits+1))
  if [ "$hits" -ge 4 ]; then
    ok "El postmortem cubre impacto, cronología, mitigación y prevención."
  else
    no "El postmortem debe cubrir impacto, cronología, mitigación y prevención ($hits/4)."
  fi
else
  no "Falta el postmortem en $PM."
fi

# 3) Servicio en pie
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ 2>/dev/null)
if [ "$code" = "200" ]; then
  ok "El servicio responde 200."
else
  no "El servicio no responde 200 (compruébalo: curl http://127.0.0.1/)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Incidente cerrado: mitigado y documentado. ¡Lab 84 resuelto!"; exit 0; } || exit 1
