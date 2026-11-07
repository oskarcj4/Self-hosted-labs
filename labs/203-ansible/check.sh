#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista; A=$H/ansible; R=$A/roles/web
AN(){ runuser -u analista -- env HOME=$H ANSIBLE_NOCOLOR=1 "$@"; }
PB(){ (cd $A && AN ansible-playbook desplegar.yml "$@" 2>&1); }
# cambios <salida> <host>: changed=N del PLAY RECAP (vacío si falló)
cambios(){ echo "$1" | grep -E "^$2 +:" | grep -E 'failed=0' | grep -E 'unreachable=0' | sed -E 's/.*changed=([0-9]+).*/\1/'; }
WS(){ AN ssh -o BatchMode=yes "$1" "${@:2}" 2>/dev/null; }

echo "== Lab 203 · Ansible — comprobación =="

# 1) Estructura del rol
if [ -f $R/tasks/main.yml ] && [ -f $R/handlers/main.yml ] && ls $R/templates/*.j2 >/dev/null 2>&1 \
   && [ -f $R/defaults/main.yml ] && grep -qE '^\s*-?\s*(role:\s*)?web\s*$|role:\s*web' $A/desplegar.yml \
   && grep -qE '^\s*-?\s*roles\s*:' $A/desplegar.yml; then
  ok "roles/web con tasks, handlers, templates y defaults; desplegar.yml aplica el rol."
else
  no "Falta el rol roles/web (tasks/main.yml, handlers/main.yml, templates/*.j2, defaults/main.yml) o desplegar.yml no lo usa con roles:."
fi
SH=$(python3 - $A <<'PY'
import os, sys, yaml
MAL = {"shell", "command", "raw", "script"}
CLAVES = ("tasks", "handlers", "pre_tasks", "post_tasks", "block", "rescue", "always")
def tareas(lista, f, out):
    if not isinstance(lista, list): return
    for t in lista:
        if not isinstance(t, dict): continue
        for k in t:
            if k.split(".")[-1] in MAL: out.append(f"{f}: {t.get('name', k)}")
        for c in CLAVES: tareas(t.get(c), f, out)
out = []
raiz = sys.argv[1]
for d, _, fs in os.walk(raiz):
    if any(x in d for x in ("group_vars", "host_vars", "defaults", "/vars")): continue
    for n in fs:
        if not n.endswith((".yml", ".yaml")): continue
        p = os.path.join(d, n)
        try: doc = yaml.safe_load(open(p, encoding="utf-8"))
        except Exception: continue
        tareas(doc, os.path.relpath(p, raiz), out)
print("; ".join(out[:3]))
PY
)
[ -z "$SH" ] && ok "Sin shell/command/raw: todo son módulos." || no "Aún hay tareas shell/command/raw: $SH"
if grep -rqE '^\s*puerto\s*:\s*8080' $R/defaults/main.yml 2>/dev/null \
   && grep -qE '^\s*entorno\s*:\s*"?prod"?' $A/group_vars/web.yml 2>/dev/null \
   && grep -qE '^\s*entorno\s*:\s*"?canario"?' $A/host_vars/web2.yml 2>/dev/null; then
  ok "Variables: puerto en defaults, entorno en group_vars/web.yml y el canario en host_vars/web2.yml."
else
  no "Variables: puerto: 8080 en roles/web/defaults/main.yml, entorno: prod en group_vars/web.yml y entorno: canario en host_vars/web2.yml."
fi

# 2) Ejecución y resultado
O1=$(PB); C1=$(cambios "$O1" web1); C2=$(cambios "$O1" web2)
if [ -n "$C1" ] && [ -n "$C2" ]; then
  ok "El playbook termina sin fallos en web1 y web2."
else
  no "El playbook falla: $(echo "$O1" | grep -E 'fatal|ERROR' | head -1 | cut -c1-160)"
fi
P1=$(curl -s -m 3 http://web1:8080/); P2=$(curl -s -m 3 http://web2:8080/)
if echo "$P1" | grep -q 'tienda en web1 (entorno prod)' && echo "$P2" | grep -q 'tienda en web2 (entorno canario)'; then
  ok "web1 sirve 'tienda en web1 (entorno prod)' y web2 'tienda en web2 (entorno canario)'."
else
  no "Las páginas no son las esperadas: web1='$(echo $P1 | cut -c1-60)' web2='$(echo $P2 | cut -c1-60)'."
fi
M1=$(WS web1 "grep -c 'gestionado por Ansible' /etc/motd"); M2=$(WS web2 "grep -c 'gestionado por Ansible' /etc/motd")
U1=$(WS web1 getent passwd despliegue | cut -d: -f7); U2=$(WS web2 getent passwd despliegue | cut -d: -f7)
E1=$(WS web1 systemctl is-enabled nginx); E2=$(WS web2 systemctl is-enabled nginx)
if [ "$M1" = 1 ] && [ "$M2" = 1 ] && [ "$U1" = /bin/bash ] && [ "$U2" = /bin/bash ] && [ "$E1" = enabled ] && [ "$E2" = enabled ]; then
  ok "motd con el aviso una sola vez, usuario despliegue con bash y nginx habilitado en los dos."
else
  no "motd (avisos: web1=$M1 web2=$M2, esperaba 1), shell de despliegue ($U1/$U2) o nginx habilitado ($E1/$E2)."
fi

# 3) Idempotencia, sin reinicios innecesarios
PID1=$(WS web1 systemctl show -p MainPID --value nginx)
O2=$(PB); D1=$(cambios "$O2" web1); D2=$(cambios "$O2" web2)
PID2=$(WS web1 systemctl show -p MainPID --value nginx)
if [ "$D1" = 0 ] && [ "$D2" = 0 ] && [ -n "$PID1" ] && [ "$PID1" = "$PID2" ]; then
  ok "Segunda ejecución: changed=0 en los dos y nginx no se reinicia."
else
  no "Segunda ejecución: changed web1=${D1:-fallo} web2=${D2:-fallo} (esperaba 0), nginx PID $PID1 -> $PID2."
fi

# 4) Deriva: alguien toca web1 a mano (puerto 8081 y reinicio)
WS web1 "sudo -n sh -c \"sed -i --follow-symlinks 's/8080/8081/g' /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf 2>/dev/null; systemctl restart nginx\""
O3=$(PB --check --diff); K1=$(cambios "$O3" web1); K2=$(cambios "$O3" web2)
AUN=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://web1:8080/)
if [ "${K1:-0}" -ge 1 ] && [ "$K2" = 0 ] && [ "$AUN" != 200 ]; then
  ok "--check --diff detecta la deriva de web1 (y sólo de web1) sin tocar nada."
else
  no "--check --diff: changed web1=${K1:-fallo} (esperaba ≥1), web2=${K2:-fallo} (esperaba 0), web1:8080 ya respondía $AUN."
fi
PB >/dev/null
P1=$(curl -s -m 3 http://web1:8080/)
echo "$P1" | grep -q 'tienda en web1 (entorno prod)' \
  && ok "Tras ejecutar el playbook, web1 vuelve a servir en 8080 (el handler aplicó el cambio)." \
  || no "Tras ejecutar el playbook web1 no sirve en 8080: el cambio de configuración no reinicia/recarga nginx (¿handler?)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Un rol idempotente: ejecutarlo cien veces es lo mismo que una."; exit 0; } || exit 1
