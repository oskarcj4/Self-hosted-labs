#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 57. Lanza ssh de verdad como 'analista', en modo BatchMode
# (sin preguntar contraseñas), igual que lo haría un pipeline.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista
as_analista(){ if [ "$(id -un)" = analista ]; then bash -c "$1"; else su - analista -c "$1"; fi; }
SSH='ssh -o BatchMode=yes -o ConnectTimeout=6'

echo "== Lab 57 · SSH con bastión — comprobación =="

if [ -f "$H/.ssh/id_ed25519" ] && [ -f "$H/.ssh/id_ed25519.pub" ]; then
  mode=$(stat -c %a "$H/.ssh/id_ed25519")
  if [ "$mode" = 600 ] || [ "$mode" = 400 ]; then ok "Clave ed25519 de analista creada y protegida ($mode)."
  else no "La clave privada ~/.ssh/id_ed25519 tiene permisos $mode (debe ser 600)."; fi
else
  no "No existe ~/.ssh/id_ed25519 (y .pub) de analista."
fi

if as_analista "ssh -G app-02" 2>/dev/null | grep -qiE '^proxyjump (deploy@)?(bastion|10\.76\.57\.5)'; then
  ok "~/.ssh/config: app-02 sale por el bastión (ProxyJump)."
else
  no "~/.ssh/config no define un Host app-02 con ProxyJump al bastión."
fi

out=$(as_analista "$SSH bastion hostname" 2>/dev/null)
if [ "$out" = bastion ]; then ok "'ssh bastion' entra con clave y sin contraseña."
else no "'ssh bastion hostname' no funciona en modo BatchMode (¿alias en ~/.ssh/config? ¿clave instalada?)."; fi

out=$(as_analista "$SSH app-02 hostname" 2>/dev/null)
if [ "$out" = app-02 ]; then ok "'ssh app-02' llega a través del bastión con clave y sin contraseña."
else no "'ssh app-02 hostname' no funciona en modo BatchMode. Prueba: ssh -v app-02"; fi

# Ni el home, ni ~/.ssh, ni authorized_keys pueden ser escribibles por grupo u otros.
perm=$(as_analista "$SSH app-02 'stat -c %a ~ ~/.ssh ~/.ssh/authorized_keys'" 2>/dev/null | paste -sd' ' -)
bad=0
for m in $perm; do case "${m: -2}" in *[2367]*) bad=1 ;; esac; done
if [ -z "$perm" ]; then
  no "No se pudieron leer los permisos de deploy en app-02."
elif [ "$bad" -eq 1 ]; then
  no "En app-02 siguen permisos abiertos (home, .ssh, authorized_keys): $perm."
else
  ok "Permisos de ~/, ~/.ssh y authorized_keys en app-02 correctos ($perm)."
fi

if as_analista "$SSH app-02 'grep -c old-laptop ~/.ssh/authorized_keys'" 2>/dev/null | grep -qx 0; then
  ok "La clave antigua 'old-laptop' ya no da acceso a app-02."
else
  no "authorized_keys de app-02 aún tiene la clave 'old-laptop' de alguien que ya no está."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Acceso por clave a través del bastión listo para el pipeline."; exit 0; } || exit 1
