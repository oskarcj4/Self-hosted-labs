# Solución — Lab 17

## Editar la configuración

```bash
sudo nano /etc/ssh/sshd_config
```

Cambia (o añade, sin `#` delante):

```
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
```

O con `sed`:

```bash
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config
```

## Validar

```bash
sudo sshd -t && echo "config OK"
sudo sshd -T | grep -iE 'permitrootlogin|passwordauthentication'
bash /opt/lab/check.sh
```

En un servidor real, tras validar se recarga: `sudo systemctl reload ssh`.

## Lecciones

- Base mínima de hardening SSH: sin login de root, sin contraseñas (sólo clave
  pública), sin contraseñas vacías, `MaxAuthTries` bajo, y `AllowUsers`/`AllowGroups`
  para limitar quién entra.
- Antes de recargar, **valida** con `sshd -t`: una config rota puede dejarte
  fuera del servidor.
- Complementa con fail2ban (lab 20) y con no exponer el 22 a todo internet.
