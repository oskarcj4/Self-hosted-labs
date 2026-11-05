# Resolución guiada · Lab 150

:::piensa Recuperar y blindar
Primero vuelve a estar en pie (restaurar); luego asegúrate de que el próximo
golpe no se lleve también la copia (inmutable, fuera de sitio).
:::

## Paso 1 · Restaura desde restic

:::pista Cómo hacerlo
```bash
export RESTIC_REPOSITORY=/srv/backup/restic
export RESTIC_PASSWORD_FILE=/etc/restic/pass
restic snapshots
restic restore latest --target /
sha256sum /srv/datos/master.key
```
`--target /` devuelve los ficheros a su ruta original (`/srv/datos/...`).
:::

## Paso 2 · Copia inmutable fuera de sitio

**Pregúntate:** si el ransomware vuelve con permisos de root, ¿qué copia NO
podría borrar?

:::pista Cómo hacerlo
```bash
sudo cp -a /srv/backup/restic /srv/offsite/restic
sudo chattr -R +i /srv/offsite/restic
lsattr -d /srv/offsite/restic
```
Ni root borra un fichero con `+i` sin quitarlo antes.
:::

## Paso 3 · Escribe el plan 3-2-1

:::pista Cómo hacerlo
`~/plan-321.txt`: 3 copias, 2 medios, 1 fuera de sitio/inmutable. Nombra cada
una y di cómo verificas (restic check + restauración de prueba).
:::

## Cómo actuar en una situación así

- La defensa contra ransomware no es el antivirus: es la copia que no puede
  cifrar. Inmutable + offsite + probada.
- RTO (tiempo hasta recuperar) y RPO (dato perdido entre copias) son objetivos
  de negocio: diséñalos antes del incidente, no durante.

## Si te atascas

- `restic` pide contraseña: exporta `RESTIC_PASSWORD_FILE=/etc/restic/pass` y
  `RESTIC_REPOSITORY=/srv/backup/restic`.
- No puedes actualizar `/srv/offsite`: es intencional (`+i`). Levanta con
  `chattr -i`, copia, y vuelve a fijar.
