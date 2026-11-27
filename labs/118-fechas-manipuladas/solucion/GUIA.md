# Resolución guiada · Lab 118

:::piensa La fecha que no se puede falsificar
Cada fichero guarda varias fechas. La que enseña `ls -l` es el **mtime**
(última modificación del contenido), y `touch -d` la pone a lo que quieras. El
**ctime** (último cambio del inodo: contenido, permisos, dueño… o el propio
mtime) lo pone el kernel a "ahora" cada vez que algo cambia, y no hay forma de
fijarlo desde un programa. Un `touch` para disimular **actualiza** el ctime.
:::

**El plan:** (1) comparar las dos fechas, (2) buscar lo cambiado después del
último despliegue, (3) entender qué es cada fichero, (4) documentar y
(5) revertir.

## Paso 1 · ¿Qué fecha estás mirando?

:::pista Cómo hacerlo
```bash
ls -l /usr/local/bin
ls -l --time=ctime --full-time /usr/local/bin
stat /usr/local/bin/backup-db
```
- `--time=ctime` hace que `ls` enseñe el ctime en vez del mtime;
  `--full-time` la fecha completa, con segundos.
- `stat` muestra las cuatro marcas: `Access` (último acceso), `Modify` (mtime),
  `Change` (ctime) y `Birth` (creación, si el sistema la guarda).

**Qué deberías ver:** con `ls -l`, todo de 2023. Con `--time=ctime`, unos pocos
ficheros con fecha de hoy.
:::

## Paso 2 · ¿Qué cambió después del último despliegue?

**Pregúntate:** el log del despliegue es tu referencia. ¿Cómo le preguntas a
`find` por lo que cambió después, comparando ctime y no mtime?

:::pista Cómo hacerlo
```bash
find /usr/local/bin -newer  /var/log/deploy/ultimo.log -type f
find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f
```
- `-newer <ref>` compara el **mtime** de cada fichero con el de la referencia.
- `-cnewer <ref>` compara el **ctime**.

**Qué deberías ver:** con `-newer`, nada: el atacante falsificó el mtime. Con
`-cnewer`, `backup-sync` y `rotate-logs`.

Una línea de tiempo con las dos fechas juntas:
```bash
find /usr/local/bin -type f -printf '%C+  %T+  %p\n' | sort
```
`-printf` da formato: `%C+` es el ctime, `%T+` el mtime y `%p` la ruta.
:::

## Paso 3 · ¿Qué es cada uno?

**Pregúntate:** ¿es un fichero nuevo o uno legítimo modificado?

:::pista Cómo hacerlo
```bash
tar -tzvf /var/backups/usr-local-bin.tar.gz
cat /usr/local/bin/backup-sync
diff <(tar -xzOf /var/backups/usr-local-bin.tar.gz bin/rotate-logs) /usr/local/bin/rotate-logs
```
- `tar -tzvf` lista el contenido de la copia sin extraerlo (`t` = listar).
- `tar -xzOf … bin/rotate-logs` extrae ese fichero a la salida (`-O`), y
  `diff <(…) fichero` compara esa salida con el fichero actual. `<(…)` pasa la
  salida de un comando como si fuera un fichero.

**Qué deberías ver:** `backup-sync` no está en la copia: es **nuevo** (el que
sube datos fuera). `rotate-logs` sí está, y el `diff` enseña las líneas que
añadió el atacante.
:::

## Paso 4 · Documenta

:::pista Cómo hacerlo
```bash
for f in $(find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f); do
  echo "$f  ctime=$(stat -c %z "$f")  mtime=$(stat -c %y "$f")"
done > ~/fechas.txt
cat ~/fechas.txt
```
`stat -c %z` imprime sólo el ctime; `%y`, el mtime.
:::

## Paso 5 · Revierte

:::pista Cómo hacerlo
```bash
sudo mkdir -p /root/cuarentena
sudo mv /usr/local/bin/backup-sync /root/cuarentena/
sudo tar -C /tmp -xzf /var/backups/usr-local-bin.tar.gz bin/rotate-logs
sudo install -m 0755 /tmp/bin/rotate-logs /usr/local/bin/rotate-logs
bash /opt/lab/check.sh
```
- El script nuevo se **mueve** a cuarentena, no se borra: es evidencia.
- `tar -C /tmp` extrae dentro de `/tmp` sólo ese fichero.
- `install -m 0755` copia y fija los permisos (ejecutable) en un solo paso.
:::

## Cómo actuar en una situación así

- El mtime miente; el ctime casi nunca (haría falta cambiar el reloj del
  sistema o editar el disco en crudo, y eso deja otras huellas).
- En una línea de tiempo forense usa las cuatro marcas.
- Para saber si un fichero es el bueno, compara con la copia o con su hash, no
  por fechas.

## Si te atascas

- **El check dice que hay falsos positivos:** metiste scripts que no se
  tocaron. Usa sólo lo que sale de `-cnewer`.
- **`tar` no encuentra `rotate-logs`:** la ruta dentro del archivo es
  `bin/rotate-logs`; compruébalo con `tar -tzf`.
