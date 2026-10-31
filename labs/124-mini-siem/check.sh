#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 124.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
L=http://loki:3100

echo "== Lab 124 · Mini SIEM — comprobación =="
curl -fs $L/ready >/dev/null 2>&1 && ok "Loki responde." || no "Loki no responde en $L."
if curl -fsG $L/loki/api/v1/query_range --data-urlencode 'query={host="ssh-01"}' --data-urlencode 'limit=1' 2>/dev/null | grep -q '"values"'; then
  ok "Llegan logs de los servidores al punto central."
else
  no "No llegan logs de ssh-01 a Loki."
fi

RULES=$(curl -fs $L/prometheus/api/v1/rules 2>/dev/null)
ALERTS=$(curl -fs $L/prometheus/api/v1/alerts 2>/dev/null)
read -r NR NF FASES EXPL <<<"$(python3 - "$RULES" "$ALERTS" <<'PY'
import json, sys, unicodedata
def norm(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return s.replace(" ", "_").replace("-", "_")
valid = {"reconocimiento", "armamento", "entrega", "explotacion", "instalacion",
         "mando_y_control", "mando_control", "c2", "acciones", "acciones_sobre_objetivos"}
try:
    groups = json.loads(sys.argv[1])["data"]["groups"]
except Exception:
    groups = []
rules = [r for g in groups for r in g.get("rules", []) if r.get("type") == "alerting"]
fases = {norm(r.get("labels", {}).get("kill_chain")) for r in rules} & valid
try:
    alerts = json.loads(sys.argv[2])["data"]["alerts"]
except Exception:
    alerts = []
firing = {a["labels"].get("alertname") for a in alerts if a.get("state") == "firing"}
expl = any(norm(a["labels"].get("kill_chain")) == "explotacion" and a.get("state") == "firing" for a in alerts)
print(len(rules), len(firing), len(fases), int(expl))
PY
)"
[ "${NR:-0}" -ge 4 ] && ok "$NR reglas de alerta cargadas en el ruler." || no "Hay ${NR:-0} reglas de alerta cargadas; hacen falta al menos 4 en /etc/siem/reglas/."
[ "${FASES:-0}" -ge 4 ] && ok "Las reglas cubren $FASES fases distintas de la Kill Chain (label kill_chain)." || no "Las reglas cubren ${FASES:-0} fases de la Kill Chain; hacen falta 4 (label kill_chain)."
[ "${NF:-0}" -ge 3 ] && ok "$NF alertas distintas disparadas (firing)." || no "Sólo ${NF:-0} alertas en firing; hacen falta 3 (revisa que tus consultas casen con los logs)."
[ "${EXPL:-0}" = 1 ] && ok "La fuerza bruta SSH (explotación) está detectada." || no "No hay una alerta de explotación (fuerza bruta SSH) disparada."

S=/home/analista/soc.md
if [ -s $S ] && grep -qi 'antivirus' $S && grep -q 'EDR' $S && grep -q 'SIEM' $S && grep -qiE 'nivel 1|N1|tier 1' $S && grep -qiE 'nivel 2|N2|tier 2' $S; then
  ok "soc.md explica antivirus/EDR/SIEM y los niveles del SOC."
else
  no "~/soc.md debe explicar antivirus vs EDR vs SIEM y los niveles del SOC (N1, N2...)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 SIEM detectando la intrusión de punta a punta."; exit 0; } || exit 1
