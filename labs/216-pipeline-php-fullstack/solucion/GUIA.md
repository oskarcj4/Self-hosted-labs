# Resolución guiada · Lab 216

:::piensa ¿Por qué desaparecen las reservas en cada despliegue?
`rsync -a --delete DIR/ /var/www/reservas/` deja el destino **idéntico** al
repo. `data/` está en `.gitignore`: no está en el repo, así que `--delete` la
borra. Lo mismo le pasaría a cualquier fichero subido por usuarios.
:::

## Paso 1 · Pon los datos a salvo, lo primero

:::pista Cómo hacerlo
Antes de cualquier `git push`:
```bash
sudo mkdir -p /var/www/reservas/shared/data
sudo cp -a /var/www/reservas/data/reservas.sqlite /var/www/reservas/shared/data/
```
Si ya se borró: `/var/backups/reservas-*.sqlite`.
:::

## Paso 2 · El `.env`

:::pista Cómo hacerlo
Crea `/var/www/reservas/shared/.env` con `DB_PATH` apuntando a `shared/data`
y una contraseña SMTP **nueva** (la vieja está en el historial de git para
siempre). En el repo: `git rm --cached .env` y añádelo a `.gitignore`.
:::

## Paso 3 · El script de despliegue atómico

:::pista Cómo hacerlo
Reescribe `/usr/local/bin/publicar-reservas DIR SHA`:
1. `releases/$SHA`: copia el código **sin** `.git`, `tests`, `vendor`, `.env`.
2. `composer install --no-dev --optimize-autoloader` dentro de la release.
3. `ln -s ../../shared/.env` (o ruta absoluta) en la release; `REVISION` con el SHA.
4. Enlace atómico: `ln -sfn releases/$SHA current.tmp && mv -T current.tmp current`.
5. `systemctl reload php8.2-fpm`.
6. Borra las releases viejas (quédate con 5).
:::

:::piensa ¿Por qué "a veces no cambia nada"?
`opcache.validate_timestamps=0`: php-fpm no vuelve a mirar los ficheros
una vez compilados. Es lo normal en producción (rendimiento), y obliga a
recargar php-fpm en cada despliegue. Con releases y enlace simbólico,
además, nginx debe pasar `$realpath_root` (ya lo hace) para que cada
petición use una sola release.
:::

## Paso 4 · nginx y el pipeline

:::pista Cómo hacerlo
`root /var/www/reservas/current/public;` y recarga nginx. En el workflow:
un job `test` (`composer install`, `vendor/bin/phpunit`, si quieres
`phpstan`) y un job `deploy` con `needs: test`, sólo para `main`,
que llama a `sudo /usr/local/bin/publicar-reservas "$PWD" "${{ github.sha }}"`.
:::

## Paso 5 · El bug

:::pista Cómo hacerlo
PHPUnit marca `testReservasConsecutivasNoSeSolapan`. En `seSolapa`, dos
franjas se solapan si `desde_existente < hasta_nueva` **y**
`hasta_existente > desde_nueva`: comparaciones estrictas.
:::

## Cómo actuar en una situación así

- Lo que debe sobrevivir a un despliegue (datos, subidas, `.env`) vive fuera de la carpeta de código.
- Un secreto que tocó git está filtrado: rótalo, no basta con borrarlo.
- Desplegar = cambiar un enlace. Volver atrás = cambiar el enlace a la release anterior.
