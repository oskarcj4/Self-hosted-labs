#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/caps
c=$(docker ps -q --filter label=com.docker.compose.project=caps --filter label=com.docker.compose.service=api | head -1)

echo "== Lab 89 · Capabilities y no-new-privileges — comprobación =="

[ -n "$c" ] || { no "La api no está corriendo."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }

if [ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$c")" = "false" ]; then
  ok "No es privileged."
else
  no "Sigue privileged."
fi

caps=$(docker inspect -f '{{join .HostConfig.CapAdd " "}}' "$c")
if echo " $caps " | grep -qiE ' (CAP_)?(ALL|SYS_ADMIN) '; then
  no "CapAdd peligrosas: ${caps:-}"
else
  ok "Sin ALL/SYS_ADMIN en CapAdd (${caps:-ninguna})."
fi

drop=$(docker inspect -f '{{join .HostConfig.CapDrop " "}}' "$c")
if echo " $drop " | grep -qiE ' (CAP_)?ALL '; then
  ok "cap_drop incluye ALL."
else
  no "El runtime no tiene CapDrop ALL (${drop:-vacío})."
fi

sec=$(docker inspect -f '{{join .HostConfig.SecurityOpt " "}}' "$c")
if echo "$sec" | grep -qi 'no-new-privileges'; then
  ok "no-new-privileges está activo."
else
  no "Falta security_opt no-new-privileges (ahora: ${sec:-ninguno})."
fi

if curl -sf --max-time 3 http://127.0.0.1:8080/ | grep -q 'api ok'; then
  ok "La api sigue sirviendo."
else
  no "curl a :8080 no devuelve api ok."
fi

if grep -qi 'cap_drop:' "$P/compose.yaml" && grep -qi 'no-new-privileges' "$P/compose.yaml" \
   && ! grep -qiE 'cap_add:|SYS_ADMIN' "$P/compose.yaml"; then
  ok "compose.yaml declara cap_drop y no-new-privileges, sin cap_add."
else
  no "compose.yaml no deja escrito cap_drop ALL y no-new-privileges (sin cap_add)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 API sin capacidades extra. ¡Lab 89 resuelto!"; exit 0; } || exit 1
