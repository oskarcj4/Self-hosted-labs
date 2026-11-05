#!/usr/bin/env bash
# Lab 138 · verificación de la guía USB en Linux.
# Sólo LEE la configuración de este equipo: no cambia nada.
# Uso: sudo bash verificar.sh
pass=0; fail=0; warn=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
aviso(){ echo "  [~] $1"; warn=$((warn+1)); }

[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo con sudo: sudo bash $0"; exit 2; }
H="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"

echo "== Lab 138 · USB del estacionamiento (Linux) — verificación =="

# 1. usbguard
if systemctl is-active --quiet usbguard; then ok "usbguard activo."; else no "usbguard no está activo (systemctl enable --now usbguard)."; fi
systemctl is-enabled --quiet usbguard 2>/dev/null && ok "usbguard arranca con el sistema." || no "usbguard no está habilitado al arranque."
CONF=/etc/usbguard/usbguard-daemon.conf
grep -qE '^\s*ImplicitPolicyTarget\s*=\s*(block|reject)' "$CONF" 2>/dev/null \
  && ok "Lo que no está en la lista se bloquea (ImplicitPolicyTarget)." || no "ImplicitPolicyTarget debe ser block o reject."
grep -qE '^\s*InsertedDevicePolicy\s*=\s*apply-policy' "$CONF" 2>/dev/null \
  && ok "Los USB nuevos pasan por la política." || no "InsertedDevicePolicy debe ser apply-policy."
RULES=/etc/usbguard/rules.conf
n_allow=$(grep -cE '^\s*allow ' "$RULES" 2>/dev/null)
[ "${n_allow:-0}" -ge 1 ] && ok "Lista de permitidos con ${n_allow} dispositivos." || no "rules.conf no tiene reglas allow."
grep -qE '^\s*allow\s*$|^\s*allow\s+with-interface\s+(equals\s+)?\{?\s*03:\*:\*' "$RULES" 2>/dev/null \
  && no "Hay un 'allow' genérico (todo, o todo HID): un BadUSB pasaría." || ok "Sin reglas allow genéricas."
grep -qE '^\s*reject\s+with-interface\s+all-of\s*\{[^}]*08:\*:\*[^}]*03:0[01]:\*' "$RULES" 2>/dev/null \
  && ok "Regla anti-BadUSB (almacenamiento + teclado a la vez = reject)." || no "Falta la regla reject para almacenamiento+teclado."

# 2. usb-storage
for m in usb-storage uas; do
  modprobe -n -v "$m" 2>/dev/null | grep -q '/bin/false\|/bin/true' \
    && ok "modprobe $m queda anulado (install /bin/false)." || no "El módulo $m todavía se puede cargar."
done
lsmod | grep -qE '^(usb_storage|uas) ' && no "usb-storage/uas siguen cargados ahora (modprobe -r)." || ok "usb-storage/uas no están cargados."

# 3. noexec por defecto en udisks2
grep -qE '^\s*defaults\s*=.*noexec' /etc/udisks2/mount_options.conf 2>/dev/null \
  && ok "udisks2 monta por defecto con noexec." || no "/etc/udisks2/mount_options.conf no fija noexec."
grep -qE '^\s*defaults\s*=.*nosuid' /etc/udisks2/mount_options.conf 2>/dev/null \
  && ok "udisks2 monta por defecto con nosuid." || no "Falta nosuid en defaults de udisks2."

# 4. auditd
systemctl is-active --quiet auditd && ok "auditd activo." || no "auditd no está activo."
auditctl -l 2>/dev/null | grep -q 'usbguard' && ok "auditd vigila /etc/usbguard." || no "Falta la regla auditd sobre /etc/usbguard."
auditctl -l 2>/dev/null | grep -q 'modprobe.d' && ok "auditd vigila /etc/modprobe.d." || no "Falta la regla auditd sobre /etc/modprobe.d."

# 5. Evidencia (no bloquea el resultado si aún no probaste con un pendrive)
E="$H/tclab-138/evidencia.txt"
if [ -s "$E" ]; then
  ok "Evidencia en $E."
  grep -qiE 'block|reject' "$E" && ok "La evidencia muestra un USB bloqueado." \
    || aviso "La evidencia no muestra ningún bloqueo: conecta un USB no permitido y repite."
else
  aviso "Aún no existe $E (entregable)."
fi

echo "---------------------------------------"
echo "Resultado: $pass correctos, $fail pendientes, $warn avisos."
[ "$fail" -eq 0 ] && { echo "🎉 Política de dispositivos USB endurecida."; exit 0; } || exit 1
