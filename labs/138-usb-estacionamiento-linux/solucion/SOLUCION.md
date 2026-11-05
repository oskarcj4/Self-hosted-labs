# Solución — USB del estacionamiento (Linux)

> Recuerda: estos cambios se aplican en tu sistema y bajo tu propio riesgo.
> Al final está cómo deshacerlos.

## Configuración completa

```bash
mkdir -p ~/tclab-138
sudo apt install -y usbguard auditd

# 1. Lista de permitidos (con tus periféricos conectados y el pendrive fuera)
sudo sh -c 'usbguard generate-policy > /tmp/permitidos.conf'
sudo tee /etc/usbguard/rules.conf <<'EOF'
reject with-interface all-of { 08:*:* 03:00:* }
reject with-interface all-of { 08:*:* 03:01:* }
EOF
sudo sh -c 'cat /tmp/permitidos.conf >> /etc/usbguard/rules.conf'
sudo chmod 0600 /etc/usbguard/rules.conf
sudo sed -i -E 's/^ImplicitPolicyTarget=.*/ImplicitPolicyTarget=block/;
                s/^PresentDevicePolicy=.*/PresentDevicePolicy=apply-policy/;
                s/^InsertedDevicePolicy=.*/InsertedDevicePolicy=apply-policy/' \
  /etc/usbguard/usbguard-daemon.conf
sudo systemctl enable --now usbguard
sudo usbguard list-devices

# 2. Sin almacenamiento USB
printf 'blacklist usb-storage\nblacklist uas\ninstall usb-storage /bin/false\ninstall uas /bin/false\n' \
  | sudo tee /etc/modprobe.d/tclab-usb-storage.conf
sudo modprobe -r uas usb-storage 2>/dev/null || true
sudo update-initramfs -u

# 3. noexec por defecto
sudo mkdir -p /etc/udisks2
printf '[defaults]\ndefaults=noexec,nosuid,nodev\n' | sudo tee /etc/udisks2/mount_options.conf
sudo systemctl restart udisks2

# 4. auditd
sudo tee /etc/audit/rules.d/tclab-usb.rules <<'EOF'
-w /etc/usbguard/      -p wa -k usb-politica
-w /etc/modprobe.d/    -p wa -k usb-politica
-w /etc/udisks2/       -p wa -k usb-politica
-w /usr/bin/usbguard   -p x  -k usb-admin
EOF
sudo augenrules --load

# 5. Evidencia (conecta antes un USB no permitido)
{ sudo usbguard list-devices
  sudo journalctl -u usbguard --since "30 min ago" --no-pager
  sudo ausearch -k usb-politica -i ; } > ~/tclab-138/evidencia.txt

sudo bash labs/138-usb-estacionamiento-linux/verificar.sh
```

## Por qué cada capa

- **usbguard** decide por dispositivo (VID:PID, serie, hash del descriptor,
  interfaces). Es la única capa que frena un BadUSB, porque éste no usa
  `usb-storage`: se presenta como teclado.
- **usb-storage/uas** fuera del kernel es lo más simple y robusto contra
  pendrives, aunque usbguard falle o se pare.
- **noexec,nosuid,nodev** limita el daño si se reabre una excepción.
- **auditd** registra quién cambia la política; **journalctl** qué se conectó.

## Deshacer

```bash
sudo systemctl disable --now usbguard
sudo rm -f /etc/modprobe.d/tclab-usb-storage.conf /etc/udisks2/mount_options.conf \
           /etc/audit/rules.d/tclab-usb.rules
sudo update-initramfs -u && sudo augenrules --load && sudo systemctl restart udisks2
```
