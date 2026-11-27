# Resolución guiada · Lab 209

:::piensa Evidencia antes que arreglo
`/tmp`, `/var/tmp` y `/dev/shm` son escribibles por todos: el primer sitio
donde un atacante deja y ejecuta su código. Montarlos con `noexec` lo impide.
Pero montar un `tmpfs` encima de `/tmp` **tapa** lo que había debajo: si no
guardas antes lo sospechoso, pierdes la evidencia.
:::

**El plan:** (1) encontrar y guardar lo sospechoso, (2) escribir las reglas en
`/etc/fstab`, (3) aplicarlas sin reiniciar y (4) demostrar que funcionan.

## Paso 1 · Encuentra y guarda lo sospechoso

**Objetivo:** copiar los tres ficheros ocultos a `~/evidencia/` sin
alterarlos.

:::pista Cómo hacerlo
```bash
sudo find /tmp /var/tmp /dev/shm -type f -ls
```
`find … -type f -ls` lista todos los ficheros, también los ocultos (los que
empiezan por `.`, que un `ls` normal no enseña), con permisos y dueño.

**Qué deberías ver:** `/tmp/.font-unix/.kworker`, `/dev/shm/.run` y
`/var/tmp/.cache-x`. Nombres que imitan cosas del sistema, ocultos y
ejecutables. Guárdalos:
```bash
mkdir -p ~/evidencia
cp -p /tmp/.font-unix/.kworker /dev/shm/.run /var/tmp/.cache-x ~/evidencia/
ls -la ~/evidencia
```
`cp -p` conserva permisos y fechas de modificación, que forman parte de la
evidencia (cuándo se dejaron ahí).
:::

## Paso 2 · Las tres reglas de `fstab`

**Objetivo:** que los tres montajes estén declarados y se apliquen en cada
arranque.

**Pregúntate:** `/var/tmp` ¿necesita su propio disco, o basta con que muestre
lo mismo que `/tmp`?

:::pista Cómo hacerlo
```bash
sudo tee -a /etc/fstab <<'F'
tmpfs  /tmp      tmpfs  defaults,nosuid,nodev,noexec,size=256m,mode=1777  0 0
tmpfs  /dev/shm  tmpfs  defaults,nosuid,nodev,noexec,size=128m            0 0
/tmp   /var/tmp  none   bind,nosuid,nodev,noexec                          0 0
F
```
`tee -a` **añade** al final (sin `-a` sustituiría el fichero entero y
perderías el resto de montajes). Cada línea de `fstab` tiene seis campos:
qué, dónde, tipo, opciones, y dos números (copia de seguridad con `dump` y
orden de `fsck`; `0 0` en sistemas en memoria).

| Opción | Qué significa |
|---|---|
| `tmpfs` | Sistema de ficheros en memoria: se vacía al reiniciar. |
| `noexec` | Prohíbe ejecutar programas desde ahí. |
| `nosuid` | Ignora el bit SUID (programas que se ejecutan con los permisos de su dueño, a menudo root). |
| `nodev` | Ignora ficheros de dispositivo: nadie puede crear ahí un "disco" falso. |
| `size=256m` | Límite de memoria que puede usar. |
| `mode=1777` | Permisos: todos escriben, pero el `1` (*sticky bit*) hace que sólo el dueño pueda borrar sus propios ficheros. |
| `bind` | `/var/tmp` no es un disco nuevo: es otra vista de `/tmp`, con sus propias opciones. |
:::

## Paso 3 · Aplícalo ya, sin reiniciar

:::pista Cómo hacerlo
```bash
sudo mount /tmp
sudo mount -o remount,nosuid,nodev,noexec /dev/shm
sudo mount /var/tmp
findmnt /tmp /var/tmp /dev/shm
```
- `mount /tmp`, con sólo el punto de montaje, busca la línea en `fstab` y la
  aplica.
- `/dev/shm` ya está montado: `remount` cambia sus opciones sin desmontarlo.
- `findmnt` muestra qué hay montado en cada sitio y con qué opciones.

**Qué deberías ver:** las tres rutas con `nosuid,nodev,noexec`. Y `/tmp`
vacío: lo de antes sigue en el disco, pero tapado.
:::

## Paso 4 · Demuestra que funciona

```bash
cp /bin/true /tmp/t && /tmp/t; echo "exit=$?"
bash /opt/lab/check.sh
```
**Qué deberías ver:** `bash: /tmp/t: Permission denied` y `exit=126`: el
fichero tiene permiso de ejecución, pero el montaje lo prohíbe.

## Cómo actuar en una situación así

- `noexec` no frena `sh /tmp/script`: ahí quien se ejecuta es `/bin/sh`, que no
  está en `/tmp`. Es una capa más, no una solución completa: combínalo con
  AppArmor/SELinux y monitorización.
- Algunas herramientas (instaladores, compiladores) ejecutan desde `/tmp` y
  fallarán. Se arregla dándoles otro directorio (`TMPDIR`), no quitando el
  `noexec`.
- `/var/tmp` sobrevive a los reinicios; al enlazarlo a un `tmpfs` deja de
  hacerlo. Comprueba que nada dependa de ello.

## Si te atascas

- **El check dice que faltan ficheros en `~/evidencia`:** montaste antes de
  copiar. Desmonta (`sudo umount /var/tmp /tmp`), vuelven a verse, cópialos y
  monta otra vez.
- **`mount /var/tmp`: `can't find in /etc/fstab`:** la línea no está o tiene
  un error de escritura.
- **El bind sigue permitiendo ejecutar:** las opciones deben ir en la misma
  línea que `bind`, o remonta con `sudo mount -o remount,bind,nosuid,nodev,noexec /var/tmp`.
