#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/gate-ci

echo "== Lab 88 · Gate de seguridad saltado — comprobación =="

if grep -nE 'continue-on-error:[[:space:]]*true' "$P/pipeline.yml" >/dev/null 2>&1; then
  no "Sigue habiendo continue-on-error: true: el gate se puede ignorar."
else
  ok "Ningún job ignora el fallo con continue-on-error."
fi

if python3 - <<PY
from pathlib import Path
import re
text = Path("$P/pipeline.yml").read_text()
jobs, cur = {}, None
for line in text.splitlines():
    m = re.match(r'^  ([\w-]+):\s*$', line)
    if m:
        cur = m.group(1); jobs[cur] = {"needs": []}
        continue
    if cur is None: continue
    m = re.match(r'^    needs:\s*\[([^\]]*)\]', line)
    if m:
        jobs[cur]["needs"] = [x.strip() for x in m.group(1).split(',') if x.strip()]
dep = jobs.get("deploy", {}).get("needs", [])
raise SystemExit(0 if "secret-scan" in dep else 1)
PY
then
  ok "deploy necesita secret-scan."
else
  no "deploy no declara needs: [secret-scan]."
fi

if grep -RInE 'PASSWORD[[:space:]]*=[[:space:]]*"' "$P/app" >/dev/null 2>&1; then
  no "app/ sigue con una contraseña hardcodeada."
else
  ok "app/ ya no hardcodea PASSWORD."
fi

if (cd "$P" && su -s /bin/bash analista -c './run-ci.sh' >/tmp/ci88.out 2>&1); then
  ok "./run-ci.sh termina 0."
else
  no "./run-ci.sh falló:"; tail -n 30 /tmp/ci88.out
fi

if [ -f "$P/dist/deployed.txt" ]; then ok "Hay marca de deploy."
else no "Falta dist/deployed.txt."; fi
rm -f /tmp/ci88.out

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 El gate es obligatorio y está verde. ¡Lab 88 resuelto!"; exit 0; } || exit 1
