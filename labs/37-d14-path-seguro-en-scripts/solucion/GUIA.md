# Resolución guiada · Día 14

:::piensa Antes de tocar nada
Cuando un script escribe `tar` sin ruta, está diciendo "ejecuta el primer `tar` que encuentres en el `PATH` que me hayan dado". Si el script corre como root y alguien controla una carpeta de ese `PATH`, ese alguien decide qué ejecuta root. Un script privilegiado **no puede confiar en el entorno que hereda**.
:::

## Paso 1 · Reproduce el ataque

**Pregúntate:** ¿cómo demuestro que el riesgo es real? Simula un `PATH` envenenado y mira si el script ejecuta tu `tar` falso.

**Por qué importa:** si puedes reproducirlo, puedes demostrar después que lo has arreglado con la misma prueba.

:::pista Cómo hacerlo
```bash
cat /usr/local/sbin/backup-config.sh /etc/cron.d/backup-config
ls -ld /opt/tools/bin
mkdir -p /tmp/evil
printf '#!/bin/sh\necho "PWNED como $(id -un)" >&2\nexec /usr/bin/tar "$@"\n' > /tmp/evil/tar
chmod +x /tmp/evil/tar
sudo env PATH=/tmp/evil:/usr/bin:/bin /usr/local/sbin/backup-config.sh
```
Si ves `PWNED como root`, el problema está confirmado.
:::

## Paso 2 · Que el script defina su entorno

**Pregúntate:** ¿rutas absolutas en cada comando o fijar el `PATH` al principio? Las dos funcionan. Fijar el `PATH` es más difícil de olvidar cuando el script crece.

:::pista Cómo hacerlo
Justo después del shebang:
```bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
```
Y asegura el fichero: `sudo chown root:root` y `sudo chmod 0755`.
:::

## Paso 3 · Cierra el origen del problema

**Pregúntate:** aunque el script ya sea seguro, ¿quedan otras dos piezas mal? Sí: la carpeta escribible por todos y el `PATH` de la tarea de cron.

:::pista Cómo hacerlo
```bash
sudo chown -R root:root /opt/tools
sudo chmod 0755 /opt/tools /opt/tools/bin
sudo sed -i 's#^PATH=.*#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#' /etc/cron.d/backup-config
```
:::

## Paso 4 · Repite la prueba de fuego

```bash
sudo env PATH=/tmp/evil:/usr/bin:/bin /usr/local/sbin/backup-config.sh   # sin PWNED
sudo ls -t /var/backups/config | head -2
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Script privilegiado = entorno propio**: `PATH`, `umask`, `IFS`, `LC_ALL`.
- **En el `PATH`, la primera carpeta gana**: nunca delante una carpeta que pueda escribir alguien que no sea root.
- **Revisa quién lanza el script** (cron, timers, otros scripts): cada uno pasa su propio entorno.
- `sudo` ya usa `secure_path`, pero cron y systemd no lo aplican.

## Si te atascas

- Sigue saliendo `PWNED`: comprueba que las líneas de `PATH` están **antes** del primer comando del script.
