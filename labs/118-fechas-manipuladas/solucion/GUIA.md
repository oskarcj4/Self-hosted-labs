# Resolución guiada · Lab 118

:::piensa Antes de tocar nada
`touch -d` cambia la fecha de modificación (mtime) a lo que quieras. Pero cambiar
mtime es, en sí, un cambio en el inodo: actualiza ctime a "ahora", y ctime no se
puede fijar desde espacio de usuario.
:::

## Paso 1 · ¿Qué dice ls?

**Pregúntate:** si todo parece de hace meses, ¿qué fecha de `ls` estás mirando?

:::pista Cómo comprobarlo
```bash
ls -l /usr/local/bin
ls -l --time=ctime --full-time /usr/local/bin
stat /usr/local/bin/*
```
:::

## Paso 2 · ¿Qué cambió después del último despliegue?

**Pregúntate:** tienes un fichero de referencia (`/var/log/deploy/ultimo.log`). ¿Qué `find` compara contra su ctime en vez de su mtime?

:::pista Cómo comprobarlo
```bash
find /usr/local/bin -newer  /var/log/deploy/ultimo.log    # mtime: nada
find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f
```
Anota cada fichero con su ctime y mtime en `~/fechas.txt`.
:::

## Paso 3 · ¿Qué es cada uno?

**Pregúntate:** ¿es un fichero nuevo o uno legítimo modificado? Compara con la copia.

:::pista Cómo comprobarlo
```bash
tar -tzvf /var/backups/usr-local-bin.tar.gz
cat /usr/local/bin/backup-sync /usr/local/bin/rotate-logs
```
:::

## Paso 4 · Restaura

:::pista Cómo hacerlo
```bash
sudo mkdir -p /root/cuarentena && sudo mv /usr/local/bin/backup-sync /root/cuarentena/
sudo tar -C /tmp -xzf /var/backups/usr-local-bin.tar.gz bin/rotate-logs
sudo install -m 0755 /tmp/bin/rotate-logs /usr/local/bin/rotate-logs
```
:::

## Cómo actuar en una situación así

- **mtime miente, ctime casi nunca** (salvo cambiar el reloj del sistema o editar el disco en crudo).
- En una timeline forense usa las cuatro marcas (atime, mtime, ctime, birth).
- Restaura desde copia y compara hashes, no fechas.

## Si te atascas

- `-cnewer` devuelve demasiado: añade `-type f` y limita a `/usr/local/bin`.
- `tar` no encuentra el fichero: lista el contenido con `tar -tzf` para ver la ruta interna.
