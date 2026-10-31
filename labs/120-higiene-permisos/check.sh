#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 120.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
m(){ $SUDO stat -c '%a' "$1" 2>/dev/null; }

echo "== Lab 120 · Higiene de permisos — comprobación =="
[ "$(m /home/deploy/.ssh)" = 700 ] && ok "~deploy/.ssh en 700." || no "~deploy/.ssh debe ser 700 (es $(m /home/deploy/.ssh))."
[ "$(m /home/deploy/.ssh/id_ed25519)" = 600 ] && ok "Llave privada en 600." || no "La llave privada debe ser 600 (es $(m /home/deploy/.ssh/id_ed25519))."
[ "$(m /home/deploy/.ssh/authorized_keys)" = 600 ] && ok "authorized_keys en 600." || no "authorized_keys debe ser 600 (es $(m /home/deploy/.ssh/authorized_keys))."
[ "$($SUDO stat -c '%U' /home/deploy/.ssh/id_ed25519)" = deploy ] && ok "La llave sigue siendo de deploy." || no "La llave privada debe pertenecer a deploy."
[ "$($SUDO stat -c '%a %U' /srv/app/.env 2>/dev/null)" = "600 app" ] && ok "/srv/app/.env: 600 y dueño app." || no "/srv/app/.env debe ser 600 y de app."

WW=$($SUDO find / -xdev -type f -perm -0002 2>/dev/null | grep -vE '^/(proc|sys)/')
[ -z "$WW" ] && ok "Ningún fichero world-writable." || no "Ficheros world-writable: $(echo $WW)"
[ -x /usr/local/bin/backup.sh ] && [ "$($SUDO stat -c '%U' /usr/local/bin/backup.sh)" = root ] && ok "backup.sh sigue ejecutable y de root (cron lo necesita)." || no "backup.sh debe seguir existiendo, ejecutable y de root."
WD=$($SUDO find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | grep -vE '^/(proc|sys)/')
[ -z "$WD" ] && ok "Ningún directorio world-writable sin sticky bit." || no "Directorios 777 sin sticky: $(echo $WD)"

U1=$($SUDO su - deploy -s /bin/bash -c umask 2>/dev/null)
U2=$($SUDO su - analista -c umask 2>/dev/null)
if [[ "$U1" =~ ^0?0[27]7$ ]]; then ok "umask de deploy: $U1."; else no "umask de deploy es $U1: debe ser 027 o 077."; fi
if [[ "$U2" =~ ^0?0[02][27]$ ]] && [ $((8#$U2 & 8#022)) -eq $((8#022)) ]; then ok "umask global sin escritura para grupo/otros ($U2)."; else no "umask global es $U2 (revisa /etc/profile.d/)."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Permisos en orden."; exit 0; } || exit 1
