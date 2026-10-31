#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 113.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 113 · Firewall con ufw — comprobación =="
ST=$($SUDO ufw status verbose 2>/dev/null)
echo "$ST" | grep -q '^Status: active' && ok "ufw está activo." || no "ufw no está activo."
echo "$ST" | grep -q 'Default: deny (incoming)' && ok "Política por defecto: deny (incoming)." \
  || no "La política de entrada por defecto no es deny."
if $SUDO grep -q '^ENABLED=yes' /etc/ufw/ufw.conf; then ok "ufw arranca solo tras reiniciar."; else no "ufw no quedará activo tras reiniciar (ENABLED=yes)."; fi

# Puertos permitidos (IPv4, ignorando las filas (v6)).
ALLOWED=$(echo "$ST" | grep -E 'ALLOW IN' | grep -v '(v6)' | awk '{print $1}' | sed 's/OpenSSH/22\/tcp/' | sort -u | tr '\n' ' ')
for p in 22/tcp 80/tcp 443/tcp; do
  echo " $ALLOWED" | grep -q " $p" && ok "Permitido $p." || no "Falta permitir $p."
done
EXTRA=$(echo "$ALLOWED" | tr ' ' '\n' | grep -vE '^(22/tcp|80/tcp|443/tcp|80,443/tcp|)$')
[ -z "$EXTRA" ] && ok "No quedan reglas que abran de más." || no "Sobran reglas: $(echo $EXTRA)"

# Vista desde fuera: el escáner tiene que haber pasado DESPUÉS del cambio.
F=/srv/escaneo/ultimo.txt
if [ -s $F ] && [ $(( $(date +%s) - $(stat -c %Y $F) )) -lt 60 ]; then
  L=$(tail -1 $F)
  open(){ echo "$L" | grep -qE " $1/open/"; }
  if open 22 && open 80; then ok "Desde fuera se ve SSH y web."; else no "Desde fuera no se ven 22 y 80 abiertos (¿cortaste SSH?)."; fi
  if open 3306 || open 6379 || open 8080; then
    no "Desde fuera aún se ve algo de 3306/6379/8080 (espera 15 s a la siguiente pasada si acabas de cambiarlo)."
  else
    ok "MySQL, Redis y el panel ya no se ven desde fuera."
  fi
else
  no "No hay escaneo externo reciente en $F."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Sólo lo necesario expuesto."; exit 0; } || exit 1
