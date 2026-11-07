#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export TRIVY_CACHE_DIR=/opt/trivy-cache TRIVY_SKIP_DB_UPDATE=true TRIVY_SKIP_JAVA_DB_UPDATE=true \
       TRIVY_OFFLINE_SCAN=true TRIVY_NO_PROGRESS=true TRIVY_SKIP_VERSION_CHECK=true \
       SEMGREP_SEND_METRICS=off SEMGREP_ENABLE_VERSION_CHECK=0
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
R=/home/analista/api
as(){ runuser -u analista -- env HOME=/home/analista TRIVY_CACHE_DIR=$TRIVY_CACHE_DIR TRIVY_SKIP_DB_UPDATE=true \
      TRIVY_SKIP_JAVA_DB_UPDATE=true TRIVY_OFFLINE_SCAN=true TRIVY_NO_PROGRESS=true TRIVY_SKIP_VERSION_CHECK=true \
      SEMGREP_SEND_METRICS=off SEMGREP_ENABLE_VERSION_CHECK=0 "$@"; }

echo "== Lab 174 · Escaneo en el pipeline — comprobación =="

if [ -z "$(as git -C $R status --porcelain 2>/dev/null)" ] && as ci-run $R >/tmp/ci174.log 2>&1; then
  ok "El pipeline del último commit está en verde (y no hay cambios sin commit)."
else
  no "ci-run no está en verde o hay cambios sin commit (tail -30 /tmp/ci174.log)."
fi

# Fallos inyectados en copias del repo: cada uno debe poner el pipeline en rojo.
inyecta(){   # $1 = descripción, $2 = script python que modifica la copia
  local W; W=$(mktemp -d); chown analista "$W"
  as git clone -q "$R" "$W/r" 2>/dev/null
  (cd "$W/r" && as python3 -c "$2") && as git -C "$W/r" -c user.name=c -c user.email=c@c commit -qam "fallo: $1" >/dev/null 2>&1
  if as ci-run "$W/r" >"$W/log" 2>&1; then
    echo "      (el pipeline dejó pasar: $1)"; rm -rf "$W"; return 1
  fi
  rm -rf "$W"; return 0
}
F=0
inyecta "SQL con f-string" '
s=open("app.py").read()
s+="\n\ndef buscar(db, texto):\n    cur = db.cursor()\n    cur.execute(f\"SELECT id FROM pedidos WHERE cliente LIKE '"'"'%{texto}%'"'"'\")\n    return cur.fetchall()\n"
open("app.py","w").write(s)' || F=$((F+1))
inyecta "shell=True" '
s=open("app.py").read()
s+="\n\ndef borrar_temporales(ruta):\n    return subprocess.run(\"rm -rf \" + ruta, shell=True)\n"
open("app.py","w").write(s)' || F=$((F+1))
inyecta "PyYAML 5.3 (CVE crítico)" '
import re
s=open("requirements.txt").read()
s=re.sub(r"(?im)^pyyaml.*$","", s)+"\npyyaml==5.3\n"
open("requirements.txt","w").write(s)' || F=$((F+1))
if [ "$F" = 0 ]; then
  ok "El pipeline bloquea los 3 fallos inyectados (SQL, shell=True, dependencia con CVE crítico)."
else
  no "El pipeline dejó pasar $F de 3 fallos inyectados: los escaneos no bloquean."
fi

if cd $R && as python3 - <<'PY' 2>/dev/null
import os, sys
os.environ["ADMIN_PASSWORD"] = "clave-del-check"
sys.path.insert(0, ".")
import app
db = app.conectar()
db.execute("INSERT INTO pedidos (cliente, total) VALUES ('ana', 10.0), ('luis', 5.0)")
assert app.pedidos_de(db, "ana") == [(1, 10.0)]
assert app.pedidos_de(db, "x' OR '1'='1") == []
assert app.es_admin("clave-del-check")
PY
then
  ok "app.py: la consulta usa parámetros y la clave de admin sale del entorno."
else
  no "app.py: pedidos_de sigue siendo inyectable o ADMIN_PASSWORD no se lee del entorno."
fi

L=$(grep -nE '^\s*PASSWORD_MIN_LEN\s*=\s*12' $R/config.py 2>/dev/null)
if echo "$L" | grep -qE 'nosemgrep:\s*secreto-en-codigo' && [ "$(echo "$L" | sed 's/.*secreto-en-codigo//' | tr -dc 'A-Za-z' | wc -c)" -ge 5 ]; then
  ok "Falso positivo suprimido en su línea, con la regla y el motivo."
else
  no "PASSWORD_MIN_LEN = 12 debe seguir y llevar '# nosemgrep: secreto-en-codigo <motivo>'."
fi

if grep -nE '^\s*(trivy|semgrep)\b' $R/ci/pipeline.sh | grep -q '|| *true'; then
  no "ci/pipeline.sh todavía tiene '|| true' en un escaneo."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Los escaneos ya paran el código vulnerable antes de producción."; exit 0; } || exit 1
