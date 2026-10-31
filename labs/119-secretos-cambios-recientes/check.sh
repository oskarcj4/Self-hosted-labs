#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 119.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 119 · Secretos y cambios recientes — comprobación =="
S=/home/analista/secretos.txt
miss=""
for f in config/database.yml src/payments.py scripts/deploy.sh .cache/notas.txt; do grep -qF "$f" $S 2>/dev/null || miss="$miss $f"; done
[ -z "$miss" ] && ok "secretos.txt inventaría los 4 ficheros con secretos." || no "A ~/secretos.txt le faltan:$miss"

R=/home/analista/recientes.txt
if grep -qF scripts/deploy.sh $R 2>/dev/null && grep -qF .cache/notas.txt $R 2>/dev/null; then ok "recientes.txt tiene los dos cambios de hoy."; else no "~/recientes.txt debe listar lo cambiado en las últimas 24 h (find -mtime -1, ojo a los ocultos)."; fi
grep -qE 'main.py|settings.py|README|arquitectura' $R 2>/dev/null && no "recientes.txt incluye ficheros que no cambiaron hoy." || ok "Sin ficheros antiguos en recientes.txt."

SH=$(getent passwd soporte2 | cut -d: -f7)
if [ -z "$SH" ] || { [[ "$SH" =~ nologin|false ]] && $SUDO passwd -S soporte2 | awk '{print $2}' | grep -q '^L'; }; then
  ok "soporte2 sin acceso (borrada, o bloqueada y con nologin)."
else
  no "soporte2 sigue con shell interactiva o contraseña válida."
fi

LEAK=$($SUDO grep -rlF -e 'Tienda#Prod2024' -e 'sk_live_LAB-119-clave-de-pruebas' -e 'Wq8tLab/Tc0r+DeployK3y9mZpQ1vXc5bN7hJ2fRs' -e 'Verano2024!' /srv/app --exclude=.env 2>/dev/null)
[ -z "$LEAK" ] && ok "No quedan secretos en claro fuera de .env." || no "Siguen secretos en: $(echo $LEAK)"
grep -q 'curl -s http://203.0.113.80' /srv/app/scripts/deploy.sh 2>/dev/null && no "deploy.sh aún descarga y ejecuta el 'hotfix' externo." || ok "Fuera la línea curl|bash de deploy.sh."
E=/srv/app/.env
if $SUDO test -f $E && [ "$($SUDO stat -c '%a %U' $E)" = "600 app" ] && $SUDO grep -qF 'sk_live_LAB-119-clave-de-pruebas' $E; then
  ok "/srv/app/.env con los secretos, 600 y propiedad de app."
else
  no "/srv/app/.env debe existir con los secretos, modo 600 y dueño app."
fi
grep -qE 'environ|getenv' /srv/app/src/payments.py 2>/dev/null && ok "payments.py lee la clave del entorno." || no "payments.py debería leer API_KEY de os.environ."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Repositorio limpio de secretos."; exit 0; } || exit 1
