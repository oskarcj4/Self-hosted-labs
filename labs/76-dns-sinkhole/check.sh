#!/usr/bin/env bash
# Validador del Lab 76. Reinicia dnsmasq (la config debe persistir) y consulta
# TODOS los dominios del feed.
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
end(){ echo "---------------------------------------"; echo "Resultado: $pass superados, $fail pendientes."; }
FEED=/srv/threat-intel/feed-2026-10-20.txt
ALLOW=/srv/threat-intel/allowlist.txt
q(){ dig +short +time=2 +tries=1 @127.0.0.1 A "$1" 2>/dev/null | tail -1; }
blocked(){ local r; r=$(q "$1"); [ "$r" = 0.0.0.0 ] || [ -z "$r" ]; }

echo "== Lab 76 · DNS sinkhole — comprobación =="

if systemctl restart dnsmasq 2>/dev/null && sleep 1 && systemctl is-active --quiet dnsmasq; then
  ok "dnsmasq arranca con tu configuración."
else
  no "dnsmasq no arranca: $(journalctl -u dnsmasq -n 3 --no-pager -o cat 2>/dev/null | grep -v '^$' | tail -1)"
  end; exit 1
fi
[ "$(q www.periodico.example)" = 203.0.113.10 ] && ok "Los dominios normales siguen resolviendo." \
  || no "www.periodico.example no resuelve (debe dar 203.0.113.10)."

# El feed normalizado: sin comentarios, sin \r, en minúsculas, sin localhost ni la allowlist.
mapfile -t DOMS < <(tr -d '\r' < "$FEED" | sed 's/#.*//' | awk 'NF >= 2 {print tolower($2)}' \
  | grep -vxE 'localhost|0\.0\.0\.0' | grep -vxFf <(grep -v '^#' "$ALLOW" | grep .) | sort -u)
miss=()
for d in "${DOMS[@]}"; do blocked "$d" || miss+=("$d"); done
if [ ${#miss[@]} -eq 0 ]; then
  ok "Los ${#DOMS[@]} dominios del feed están en el sinkhole."
else
  no "${#miss[@]} de ${#DOMS[@]} dominios del feed siguen resolviendo (p. ej.: ${miss[*]:0:3})."
fi
blocked "zz$RANDOM.cdn-telemetria.xyz" && blocked "a.b.malsrv.top" \
  && ok "También se bloquean sus subdominios." \
  || no "Los subdominios (x.cdn-telemetria.xyz) siguen resolviendo: el malware usa subdominios aleatorios."
[ "$(q analytics.proveedor.example)" = 203.0.113.10 ] \
  && ok "La allowlist se respeta (analytics.proveedor.example resuelve)." \
  || no "analytics.proveedor.example está bloqueado y está en la allowlist."
grep -rqsE '/localhost/' /etc/dnsmasq.conf /etc/dnsmasq.d/ \
  && no "Bloqueaste 'localhost': la línea '127.0.0.1 localhost' del feed no es un dominio malicioso." \
  || ok "No se ha bloqueado localhost."

lf=$(grep -rhsE '^\s*log-facility=' /etc/dnsmasq.conf /etc/dnsmasq.d/ | tail -1 | cut -d= -f2)
if grep -rqsE '^\s*log-queries' /etc/dnsmasq.conf /etc/dnsmasq.d/; then
  sleep 6
  if [ -n "$lf" ] && [ "${lf:0:1}" = / ]; then recent=$(tail -n 300 "$lf" 2>/dev/null)
  else recent=$(journalctl -u dnsmasq --since -30s --no-pager -o cat 2>/dev/null); fi
  echo "$recent" | grep -qE 'query\[A\] .* from 10\.76\.76\.2[123]' \
    && ok "dnsmasq registra las consultas de los puestos (${lf:-journal})." \
    || no "log-queries está activo, pero no veo consultas recientes de los puestos en ${lf:-el journal}."
else
  no "dnsmasq no registra las consultas (log-queries)."
fi

INF=/home/analista/infectado.txt
got=$(grep -vE '^\s*(#|$)' "$INF" 2>/dev/null | tr -d ' \r' | sort -u | tr '\n' ' ' | xargs)
if [ "$got" = 10.76.76.22 ]; then
  ok "Puesto infectado identificado: $got."
elif [ -z "$got" ]; then
  no "Falta ~/infectado.txt con la IP del puesto infectado."
else
  no "~/infectado.txt dice '$got': no es (sólo) el puesto infectado. ¿Has aplicado la allowlist? ¿Has quitado 127.0.0.1?"
fi

end
[ "$fail" -eq 0 ] && { echo "🎉 Sinkhole en marcha y puesto infectado localizado."; exit 0; } || exit 1
