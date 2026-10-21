# Resolución guiada · Día 11

:::piensa Antes de tocar nada
El código se lee, se copia, se pega en tickets y se sube a repositorios. Un secreto dentro del código acaba en todos esos sitios. La solución es **separar**: el código dice *dónde* está el secreto; el secreto vive en un fichero propio, con sus propios permisos.
:::

## Paso 1 · Encuentra el secreto y todas sus copias

**Pregúntate:** ¿dónde aparece la contraseña? No sólo en el script: busca copias de respaldo y cualquier otro fichero.

:::pista Cómo comprobarlo
```bash
cat /opt/maint/db-maintenance.sh
ls -la /opt/maint/
sudo grep -rlF '<un trozo de la contraseña>' /opt /etc /home /var/log 2>/dev/null
```
:::

## Paso 2 · Crea el fichero de credenciales YA cerrado

**Pregúntate:** si escribo el fichero y después le hago `chmod 600`, ¿hay un momento en que es legible? Sí, unos segundos. Créalo vacío con los permisos correctos y escribe después.

:::pista Cómo hacerlo
```bash
sudo install -d -m 0700 -o root -g root /etc/maint
sudo install -m 0600 -o root -g root /dev/null /etc/maint/db.cred
sudo nano /etc/maint/db.cred
```
Dentro, las mismas líneas `DB_USER=...` y `DB_PASSWORD=...` que tenía el script.
:::

## Paso 3 · Que el script lo cargue

**Pregúntate:** ¿cómo carga bash variables de otro fichero? Con `source` (o `.`). ¿Y si el fichero no está? Mejor fallar con un mensaje claro que conectar sin contraseña.

:::pista Cómo hacerlo
Sustituye en el script las líneas `DB_USER=` y `DB_PASSWORD=` por:
```bash
. /etc/maint/db.cred || { echo 'ERROR: no puedo leer /etc/maint/db.cred'; exit 1; }
```
Y asegura el script: `sudo chown root:root` y `sudo chmod 0755`.
:::

## Paso 4 · Limpia las copias y prueba

```bash
sudo rm /opt/maint/db-maintenance.sh.orig
sudo /opt/maint/db-maintenance.sh                   # VACUUM OK
grep -c '<trozo-de-la-contraseña>' /opt/maint/db-maintenance.sh   # 0
cat /etc/maint/db.cred                              # como analista: denegado
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Separa código y secreto**: el fichero de credenciales tiene permisos propios y se rota sin tocar el código.
- **Crea cerrado, escribe después** (`install -m 0600 /dev/null`).
- **Busca copias** y también historiales de git, logs con `set -x`, tickets.
- Si estuvo expuesta: **rótala** en la base de datos. Moverla no la des-filtra.

## Si te atascas

- El script dice "no puedo leer": lo estás ejecutando sin `sudo`, o la ruta tiene una errata.
