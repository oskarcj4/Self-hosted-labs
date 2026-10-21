# Resolución guiada · Lab 17

:::piensa Antes de tocar nada
Endurecer SSH tiene un riesgo real: **dejarte fuera** del servidor. Por eso el método importa tanto como el resultado: cambia, **valida**, y sólo después recarga. Y pregúntate en cada directiva qué ataque cierra.
:::

## Paso 1 · ¿Cómo está ahora?

**Pregúntate:** ¿qué valor tiene **realmente** cada directiva? El fichero puede tener líneas comentadas, repetidas o includes.

**Por qué importa:** `sshd -T` muestra la configuración efectiva, la que de verdad aplica.

:::pista Cómo comprobarlo
```bash
grep -inE 'permitrootlogin|passwordauthentication|x11forwarding' /etc/ssh/sshd_config
sudo sshd -T | grep -iE 'permitrootlogin|passwordauthentication|x11forwarding'
```
:::

## Paso 2 · Decide qué cerrar y por qué

- `PermitRootLogin no`: el atacante tiene que adivinar **usuario y** contraseña, y todo queda atribuido a una persona.
- `PasswordAuthentication no`: la fuerza bruta (lab 14) deja de tener sentido; sólo entran claves.
- Extras: `X11Forwarding no`, `PermitEmptyPasswords no`, `MaxAuthTries 3`.

## Paso 3 · Edita sin duplicar

**Pregúntate:** si una directiva aparece dos veces, ¿cuál gana? En sshd, **la primera**. Por eso es mejor modificar la línea existente que añadir otra al final.

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
```
`^#\?` también encaja si la línea estaba comentada.
:::

## Paso 4 · Valida antes de nada más

```bash
sudo sshd -t && echo "config OK"
sudo sshd -T | grep -iE 'permitrootlogin|passwordauthentication'
bash /opt/lab/check.sh
```

:::ojo En un servidor real
Antes de `systemctl reload ssh`, deja **otra sesión SSH abierta**. Si la nueva configuración te bloquea, la sesión vieja te permite arreglarlo. Y comprueba que tu clave pública está en `authorized_keys` antes de desactivar contraseñas.
:::

## Cómo actuar en una situación así

- **Cambiar → validar (`sshd -t`) → recargar → probar con una sesión nueva**, sin cerrar la vieja.
- **Comprueba el valor efectivo** con `sshd -T`, no sólo el fichero.
- Mira también `/etc/ssh/sshd_config.d/`: un include puede sobrescribir lo que pones.

## Si te atascas

- El validador dice que sigue en `yes`: busca duplicados con `grep -in permitrootlogin /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*`.
