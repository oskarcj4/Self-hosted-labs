#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
U=http://127.0.0.1:8080

echo "== Lab 185 · Logs para producción — comprobación =="

systemctl restart tienda; sleep 2
DESDE=$(date '+%F %T'); sleep 1.1
RID="chk-$RANDOM$RANDOM"
TOKEN="sk_live_$RANDOM$RANDOM"
CLAVE="Clave-$RANDOM$RANDOM"
H=$(curl -s -D - -o /dev/null -H "X-Request-ID: $RID" -H "Authorization: Bearer $TOKEN" $U/productos)
GEN=$(curl -s -D - -o /dev/null $U/productos | tr -d '\r' | sed -n 's/^[Xx]-[Rr]equest-[Ii][Dd]: *//p')
curl -s -o /dev/null -H "X-Request-ID: $RID-err" $U/error
curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" -d "email=marta.lopez@ejemplo.com&password=$CLAVE" $U/login
curl -s -o /dev/null -d "importe=19.90&tarjeta=4111111111111111&email=marta.lopez@ejemplo.com" $U/pagar
sleep 1.5
journalctl _SYSTEMD_UNIT=tienda.service --since "$DESDE" -o cat --no-pager > /tmp/c185.log 2>/dev/null

python3 - /tmp/c185.log "$RID" "$GEN" > /tmp/c185.res <<'PY'
import json, sys
lineas = [l for l in open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines() if l.strip()]
rid, gen = sys.argv[2], sys.argv[3]
objs, malas = [], []
for l in lineas:
    try:
        o = json.loads(l)
        (objs if isinstance(o, dict) else malas).append(o if isinstance(o, dict) else l)
    except ValueError:
        malas.append(l)
def out(k, ok, msg): print(f"{k}|{'1' if ok else '0'}|{msg}")
campos = all({"ts", "level", "msg"} <= set(o) for o in objs)
out("json", lineas and not malas and campos,
    f"{len(lineas)} líneas, {len(malas)} no son JSON" + ("" if campos else "; faltan ts/level/msg en alguna")
    + (f" (p. ej. {malas[0][:70]!r})" if malas else ""))
acc = [o for o in objs if {"method", "path", "status", "duration_ms"} <= set(o)]
paths = {(o["path"], int(o["status"])) for o in acc if str(o.get("status")).isdigit()}
out("acceso", ("/productos", 200) in paths and ("/error", 500) in paths and ("/pagar", 200) in paths,
    f"líneas de acceso con method/path/status/duration_ms: {len(acc)}")
con = [o for o in objs if o.get("request_id") == rid]
err = [o for o in objs if o.get("request_id") == f"{rid}-err"]
out("rid", con and gen and gen != rid and any(o.get("request_id") == gen for o in objs) and err,
    f"request_id: {len(con)} líneas con el X-Request-ID recibido; generado nuevo: {gen or 'no devuelto'}")
e = [o for o in err if str(o.get("level", "")).upper() == "ERROR"]
out("exc", len(e) == 1 and "ZeroDivisionError" in str(e[0].get("exc", "")) and "Traceback" in str(e[0].get("exc", ""))
    and not any("Traceback" in str(o.get("msg", "")) for o in objs),
    f"errores de /error: {len(e)} línea(s) ERROR con la traza en 'exc'")
dbg = [o for o in objs if str(o.get("level", "")).upper() == "DEBUG"]
out("nivel", not dbg, f"líneas DEBUG con LOG_LEVEL=INFO: {len(dbg)}")
PY
while IFS='|' read -r k r msg; do
  if [ "$r" = 1 ]; then ok "$msg."; else no "$msg."; fi
done < /tmp/c185.res
if [ "$(echo "$H" | tr -d '\r' | sed -n 's/^[Xx]-[Rr]equest-[Ii][Dd]: *//p')" = "$RID" ]; then
  ok "La respuesta devuelve el X-Request-ID recibido."
else
  no "La respuesta no devuelve la cabecera X-Request-ID con el valor recibido."
fi

FUGA=""
grep -q "$TOKEN" /tmp/c185.log && FUGA="$FUGA token"
grep -qE '4111[ -]?1111[ -]?1111[ -]?1111' /tmp/c185.log && FUGA="$FUGA tarjeta"
grep -q 'marta.lopez@ejemplo.com' /tmp/c185.log && FUGA="$FUGA email"
grep -q "$CLAVE" /tmp/c185.log && FUGA="$FUGA contraseña"
[ -z "$FUGA" ] && ok "Ni tokens, ni contraseñas, ni tarjetas, ni emails completos en los logs." \
               || no "En los logs aparece:$FUGA."

if [ "$(systemctl show tienda -p Environment --value | grep -o 'LOG_LEVEL=[A-Z]*')" != LOG_LEVEL=DEBUG ] \
   && grep -q 'LOG_LEVEL' /home/analista/tienda/app.py; then
  ok "El nivel se lee de LOG_LEVEL."
else
  no "app.py debe leer el nivel de LOG_LEVEL (y el servicio no debe estar en DEBUG)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Logs que se pueden buscar, seguir y enseñar sin miedo."; exit 0; } || exit 1
