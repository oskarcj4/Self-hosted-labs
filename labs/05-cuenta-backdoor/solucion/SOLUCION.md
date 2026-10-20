# Solución — Lab 05

## 1. ¿Quién tiene UID 0?

```bash
awk -F: '$3==0 {print $1, $3}' /etc/passwd
```

Aparecen `root` **y** `supportsvc`, ambos con UID 0. `supportsvc` es la cuenta
backdoor: con UID 0 es root a todos los efectos, aunque el nombre parezca de
servicio.

## 2. Eliminar la cuenta backdoor

```bash
sudo userdel supportsvc
grep supportsvc /etc/passwd /etc/shadow    # comprueba que ya no queda rastro
```

(Si `userdel` se queja porque no tiene home propio, puedes editar a mano
`/etc/passwd` y `/etc/shadow` con `sudo vipw` y `sudo vipw -s`.)

## 3. Quitar la regla de sudo backdoor

```bash
cat /etc/sudoers.d/*            # verás 'backup ALL=(ALL) NOPASSWD:ALL'
sudo rm -f /etc/sudoers.d/backup
sudo userdel backup            # opcional: elimina también la cuenta
sudo visudo -c                 # valida que sudo sigue consistente
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- Root = **UID 0**, no el nombre. Audita siempre `awk -F: '$3==0'`.
- La persistencia también vive en `/etc/sudoers.d/`: un archivo por regla hace
  fácil esconder una puerta trasera entre reglas legítimas.
- Cambiar la contraseña de `root` no sirve si existe otra cuenta UID 0.
