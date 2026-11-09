# Resolución guiada · Lab 209

:::piensa Evidencia antes que arreglo
Endurecer es rápido; reconstruir una intrusión sin evidencia, imposible. Guarda
primero lo que vas a "tapar".
:::

## Paso 1 · Encuentra y guarda lo sospechoso

:::pista Cómo hacerlo
```bash
ls -la /tmp /tmp/.font-unix /dev/shm /var/tmp
mkdir -p ~/evidencia
cp -p /tmp/.font-unix/.kworker /dev/shm/.run /var/tmp/.cache-x ~/evidencia/
```
:::

## Paso 2 · Las tres reglas de fstab

**Pregúntate:** `/var/tmp` ¿necesita su propio disco o basta con apuntar a `/tmp`?

:::pista Cómo hacerlo
```bash
sudo tee -a /etc/fstab <<'F'
tmpfs  /tmp      tmpfs  defaults,nosuid,nodev,noexec,size=256m,mode=1777  0 0
tmpfs  /dev/shm  tmpfs  defaults,nosuid,nodev,noexec,size=128m            0 0
/tmp   /var/tmp  none   bind,nosuid,nodev,noexec                          0 0
F
```
:::

## Paso 3 · Aplícalo ya

:::pista Cómo hacerlo
```bash
sudo mount /tmp
sudo mount -o remount,nosuid,nodev,noexec /dev/shm
sudo mount /var/tmp
findmnt /tmp /var/tmp /dev/shm
```
:::

## Paso 4 · Demuestra que funciona

:::pista Cómo hacerlo
```bash
cp /bin/true /tmp/t && /tmp/t       # bash: /tmp/t: Permission denied
```
:::

## Cómo actuar en una situación así

- `systemctl enable tmp.mount` es la alternativa systemd para `/tmp`.
- Trampa: `noexec` no frena a `sh /tmp/script`; combínalo con AppArmor/SELinux y monitoreo.
- `/var/tmp` conserva datos entre reinicios; al enlazarlo a `/tmp` los pierdes: ajusta si algo depende de ello.

## Si te atascas

- `mount /var/tmp` dice "can't find in /etc/fstab": faltó la línea o los espacios.
- El bind sigue permitiendo exec: la opción debe ir en la misma línea (`bind,nosuid,nodev,noexec`) o remonta con `-o remount,bind,noexec`.
