# Resolución guiada · Día 15

:::piensa Antes de tocar nada
Lo que root ejecuta de forma automática tiene que ser **tan difícil de modificar como root**. Eso incluye el fichero y **cada carpeta de su ruta**: si puedes escribir en la carpeta, puedes sustituir el fichero. Y hay una segunda pregunta: el script estuvo escribible por todos… **¿sigue siendo el original?**
:::

## Paso 1 · Mira toda la cadena

**Pregúntate:** ¿quién puede modificar el script, directa o indirectamente?

**Por qué importa:** `namei -l` enseña dueño y permisos de cada carpeta del camino. Basta con un eslabón débil.

:::pista Cómo comprobarlo
```bash
cat /etc/cron.d/cache-cleanup
namei -l /var/tmp/jobs/cleanup-cache.sh
```
:::

## Paso 2 · Léelo antes de promoverlo

**Pregúntate:** si cualquiera pudo editarlo, ¿cómo sé que sólo hace lo que debe?

**Por qué importa:** si copias un script manipulado a una ruta segura, sólo has hecho la puerta trasera permanente.

:::pista Cómo comprobarlo
```bash
cat /var/tmp/jobs/cleanup-cache.sh
```
Debe limitarse a borrar `/var/cache/app/*.tmp`. Cualquier otra línea (copias de `bash`, `chmod u+s`, descargas…) es sospechosa. En un caso real, lo compararías con el control de versiones.
:::

## Paso 3 · Muévelo a una ruta de root

**Pregúntate:** ¿qué hace `install` que no haga `cp`? Copia y fija dueño y modo en un solo paso.

:::pista Cómo hacerlo
```bash
sudo install -m 0755 -o root -g root /var/tmp/jobs/cleanup-cache.sh /usr/local/sbin/cleanup-cache
namei -l /usr/local/sbin/cleanup-cache
```
Todo debe ser de root y sin `w` para grupo ni otros.
:::

## Paso 4 · Apunta cron al nuevo y retira el viejo

:::pista Cómo hacerlo
```bash
sudo sed -i 's#/var/tmp/jobs/cleanup-cache.sh#/usr/local/sbin/cleanup-cache#' /etc/cron.d/cache-cleanup
sudo chown root:root /etc/cron.d/cache-cleanup
sudo chmod 0644 /etc/cron.d/cache-cleanup
sudo rm -rf /var/tmp/jobs
grep -r '/var/tmp/jobs' /etc/cron* || echo "ninguna tarea apunta ya ahí"
```
:::

## Paso 5 · Verifica

```bash
sudo /usr/local/sbin/cleanup-cache
ls /var/cache/app
systemctl is-active cron
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Toda la cadena de carpetas**, no sólo el fichero.
- **Lo que estuvo escribible por todos es sospechoso**: revísalo antes de confiar en él.
- `/tmp` y `/var/tmp` son de todos: el sticky bit no protege una subcarpeta `0777`.
- Revisa también `crontab -l -u root`, `/etc/cron.*` y los timers de systemd.

## Si te atascas

- El validador dice que la ruta no es segura: `namei -l` te señala la carpeta con permisos de más.
