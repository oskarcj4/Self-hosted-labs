#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 148.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista

echo "== Lab 148 · Accesos que nadie revocó — comprobación =="

# 1) Cuentas de baja revocadas (bloqueadas o eliminadas)
for u in tyrell scripted; do
  if ! id -u "$u" >/dev/null 2>&1; then
    ok "Cuenta '$u' eliminada."
  else
    st=$($SUDO passwd -S "$u" 2>/dev/null | awk '{print $2}')
    [ "$st" = "L" ] && ok "Cuenta '$u' bloqueada." || no "Cuenta '$u' sigue activa (de BAJA en RRHH)."
  fi
done

# 2) La cuenta de servicio activa NO se tocó
id -u deploy >/dev/null 2>&1 && ok "La cuenta de servicio 'deploy' sigue existiendo (es activa)." || no "No elimines 'deploy': está de ALTA."

# 3) Llave NO aprobada eliminada de todos los authorized_keys
if $SUDO find /home /root -name authorized_keys -exec grep -l 'darkarmy@exfil' {} + 2>/dev/null | grep -q .; then
  no "Queda la llave no aprobada (darkarmy@exfil) en algún authorized_keys."
else
  ok "La llave no aprobada (darkarmy@exfil) ya no está en ningún authorized_keys."
fi
# 4) La llave aprobada sigue
$SUDO grep -rql 'ops@allsafe' /home/deploy/.ssh 2>/dev/null \
  && ok "La llave aprobada (ops@allsafe) se conservó en deploy." || no "Se perdió la llave aprobada (ops@allsafe) de deploy."

# 5) sudoers.d del ex-empleado eliminado
if $SUDO grep -rqw 'tyrell' /etc/sudoers.d 2>/dev/null; then
  no "Todavía hay una regla sudoers.d para tyrell."
else
  ok "No queda sudoers.d para personal de baja."
fi

# 6) Documento de revocaciones
R=$H/revocados.txt
if grep -qw tyrell "$R" 2>/dev/null && grep -qw scripted "$R" 2>/dev/null && grep -q 'darkarmy@exfil' "$R" 2>/dev/null; then
  ok "revocados.txt documenta cuentas, llave y sudoers."
else
  no "~/revocados.txt debe listar lo revocado (tyrell, scripted y la llave darkarmy@exfil)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Puertas cerradas: sin accesos huérfanos."; exit 0; } || exit 1
