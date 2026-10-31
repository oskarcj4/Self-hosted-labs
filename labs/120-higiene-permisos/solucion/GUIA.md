# Resolución guiada · Lab 120

:::piensa Antes de tocar nada
Los permisos no son sólo "que funcione". Una clave privada legible por otros,
un script de root escribible por todos o un umask 000 son escaladas de
privilegios esperando a alguien.
:::

## Paso 1 · ¿Qué está mal?

**Pregúntate:** ¿qué permisos exige SSH para `~/.ssh` y la clave privada?

:::pista Cómo comprobarlo
```bash
sudo stat -c '%a %U %n' /home/deploy/.ssh /home/deploy/.ssh/* /srv/app/.env
sudo find / -xdev -type f -perm -0002 2>/dev/null
```
:::

## Paso 2 · Arregla cada fichero

**Pregúntate:** ¿quién necesita leer, quién escribir? Ni un bit más.

:::pista Cómo hacerlo
```bash
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/id_ed25519 /home/deploy/.ssh/authorized_keys
sudo chmod 600 /srv/app/.env
sudo chmod 755 /usr/local/bin/backup.sh
sudo chmod 644 /etc/app/config.yml
```
`backup.sh` lo ejecuta root desde cron: si cualquiera puede escribirlo, cualquiera es root.
:::

## Paso 3 · ¿De dónde sale el umask 000?

**Pregúntate:** ¿qué ficheros se leen al iniciar sesión? Sistema (`/etc/profile`, `/etc/profile.d/`) y usuario (`~/.profile`, `~/.bashrc`).

:::pista Cómo comprobarlo
```bash
sudo grep -rn umask /etc/profile /etc/profile.d/ /etc/login.defs /home/deploy/.profile /home/deploy/.bashrc
sudo su - deploy -c umask
```
Debe dar `0022` o `0027`.
:::

## Cómo actuar en una situación así

- Revisa los **world-writable** fuera de `/tmp` periódicamente.
- **Scripts que ejecuta root** deben ser de root y `755` como mucho, igual que su directorio.
- `umask 027` en servidores: los grupos leen, el resto nada.

## Si te atascas

- SSH sigue rechazando la clave: el directorio home tampoco puede ser escribible por otros.
- `su - deploy -c umask` sigue en 000: queda otra línea; busca en todos los ficheros de inicio.
