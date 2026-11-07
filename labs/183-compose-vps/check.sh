#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
V=/home/analista/vps
cd $V || exit 1

echo "== Lab 183 · Compose para un VPS — comprobación =="

if ! docker compose config --format json > /tmp/c183.json 2>/tmp/c183.err; then
  no "docker compose config falla: $(tail -1 /tmp/c183.err)"
  echo "Resultado: $pass superados, $((fail)) pendientes."; exit 1
fi

# Revisión estática del modelo ya resuelto por Compose.
python3 - /tmp/c183.json > /tmp/c183.res <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
s = c.get("services", {})
def out(k, ok, msg): print(f"{k}|{'1' if ok else '0'}|{msg}")
pub = sorted(n for n, x in s.items() if x.get("ports"))
pp = [p for p in s.get("proxy", {}).get("ports", [])]
out("puertos", pub == ["proxy"] and len(pp) == 1 and str(pp[0].get("target")) == "80",
    f"servicios que publican puertos: {pub or 'ninguno'}")
vols = [v for v in s.get("db", {}).get("volumes", []) if v.get("target") == "/var/lib/postgresql/data"]
out("volumen", bool(vols) and vols[0].get("type") == "volume",
    "db: /var/lib/postgresql/data " + (f"es {vols[0].get('type')}" if vols else "sin montar"))
env_db = s.get("db", {}).get("environment") or {}
env_app = s.get("app", {}).get("environment") or {}
sec_db = [x.get("source") for x in s.get("db", {}).get("secrets", [])]
sec_app = [x.get("source") for x in s.get("app", {}).get("secrets", [])]
out("secretos", "POSTGRES_PASSWORD" not in env_db and "DB_PASSWORD" not in env_app
    and str(env_db.get("POSTGRES_PASSWORD_FILE", "")).startswith("/run/secrets/")
    and str(env_app.get("DB_PASSWORD_FILE", "")).startswith("/run/secrets/") and sec_db and sec_app
    and all(c.get("secrets", {}).get(n, {}).get("file") for n in set(sec_db + sec_app)),
    "contraseña por secrets de fichero y *_PASSWORD_FILE en db y app")
dep = (s.get("app", {}).get("depends_on") or {}).get("db", {})
out("salud", bool(s.get("db", {}).get("healthcheck", {}).get("test")) and dep.get("condition") == "service_healthy"
    and bool(s.get("app", {}).get("healthcheck", {}).get("test")),
    f"healthcheck en db y app; app depende de db con condition={dep.get('condition')}")
sin = [n for n, x in s.items() if x.get("restart") not in ("unless-stopped", "always")]
out("reinicio", not sin, f"sin política de reinicio: {sin or 'ninguno'}")
nolog = [n for n, x in s.items()
         if (x.get("logging") or {}).get("driver", "json-file") not in ("json-file", "local")
         or not (x.get("logging") or {}).get("options", {}).get("max-size")]
out("logs", not nolog, f"sin límite de logs (max-size): {nolog or 'ninguno'}")
PY
while IFS='|' read -r k r msg; do
  if [ "$r" = 1 ]; then ok "$msg."; else no "$msg."; fi
done < /tmp/c183.res

if grep -q 'tienda123' compose.yaml .env 2>/dev/null || grep -rqs 'tienda123' secretos/ secrets/ 2>/dev/null; then
  no "La contraseña vieja (tienda123) sigue en compose.yaml, .env o el fichero del secret: genera una nueva."
fi

echo "  ... levantando el stack (puede tardar)"
docker compose down -t 2 >/dev/null 2>&1
if docker compose up -d --build --wait --wait-timeout 120 >/tmp/c183.up 2>&1; then
  P="lab183-$RANDOM"
  curl -s -o /dev/null -X POST "localhost/pedidos?producto=$P"
  docker compose down -t 5 >/dev/null 2>&1
  docker compose up -d --wait --wait-timeout 120 >/dev/null 2>&1
  if curl -s --max-time 5 localhost/pedidos | grep -q "$P"; then
    ok "Un pedido creado sobrevive a down + up, a través del proxy."
  else
    no "El pedido creado antes de 'docker compose down' no está tras volver a levantar."
  fi
  LEAK=""
  for c in $(docker compose ps -q); do
    docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | grep -qiE '^(POSTGRES_PASSWORD|DB_PASSWORD)=' && LEAK="$LEAK $(docker inspect -f '{{.Name}}' "$c")"
  done
  [ -z "$LEAK" ] && ok "Ningún contenedor lleva la contraseña en sus variables de entorno." \
                 || no "Contraseña en variables de entorno de:$LEAK."
else
  no "docker compose up --wait no deja todo sano: $(grep -m1 -iE 'error|unhealthy|exited' /tmp/c183.up || tail -1 /tmp/c183.up)"
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Listo para el VPS."; exit 0; } || exit 1
