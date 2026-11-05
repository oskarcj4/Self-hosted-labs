#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 150.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
export RESTIC_REPOSITORY=/srv/backup/restic
export RESTIC_PASSWORD_FILE=/etc/restic/pass

echo "== Lab 150 · El 5/9: llaves destruidas — comprobación =="

# 1) El repositorio restic tiene al menos una instantánea
if $SUDO env RESTIC_REPOSITORY=$RESTIC_REPOSITORY RESTIC_PASSWORD_FILE=$RESTIC_PASSWORD_FILE \
     restic snapshots >/tmp/snaps.out 2>&1 && grep -qE '[0-9a-f]{8}' /tmp/snaps.out; then
  ok "El repositorio restic conserva instantáneas."
else
  no "No se pueden listar instantáneas del repositorio restic."
fi

# 2) Datos restaurados e intactos
WANT=$($SUDO cat /etc/restic/.gt_masterkey 2>/dev/null)
GOT=$($SUDO sha256sum /srv/datos/master.key 2>/dev/null | cut -d' ' -f1)
if [ -n "$WANT" ] && [ "$WANT" = "$GOT" ]; then
  ok "master.key restaurado byte a byte desde la copia."
else
  no "/srv/datos/master.key no está o no coincide con el original (restaura desde restic)."
fi
[ -f /srv/datos/claves.gpg ] && ok "claves.gpg también restaurado." || no "Falta /srv/datos/claves.gpg."
$SUDO grep -rqi fsociety /srv/datos 2>/dev/null && no "Aún queda la nota del ransomware en /srv/datos." || ok "/srv/datos limpio de la nota del ataque."

# 3) Copia inmutable fuera de sitio (3-2-1)
if [ -n "$($SUDO ls -A /srv/offsite 2>/dev/null)" ]; then
  if $SUDO lsattr -R /srv/offsite 2>/dev/null | grep -qE '^-{4}i'; then
    ok "Hay una copia en /srv/offsite marcada como inmutable (chattr +i)."
  else
    no "La copia de /srv/offsite no es inmutable: aplícale chattr +i."
  fi
else
  no "No hay copia del repositorio en /srv/offsite."
fi

# 4) Plan 3-2-1 documentado
P=$H/plan-321.txt
if grep -q '3' "$P" 2>/dev/null && grep -q '2' "$P" 2>/dev/null && grep -q '1' "$P" 2>/dev/null \
   && grep -qiE 'fuera de sitio|offsite|externa|inmutable' "$P" 2>/dev/null; then
  ok "plan-321.txt describe 3 copias, 2 medios y 1 fuera de sitio."
else
  no "~/plan-321.txt debe describir la regla 3-2-1 (3 copias, 2 medios, 1 fuera de sitio/inmutable)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Datos recuperados y una copia que el ransomware no puede tocar."; exit 0; } || exit 1
