# Solución — Pipeline full stack: PHP con despliegue atómico

## Qué fallaba y cómo se arregla

| Problema | Causa | Arreglo |
|----------|-------|---------|
| Desaparecen las reservas | `rsync --delete` borra `data/` (no está en git) | base en `shared/data`, `DB_PATH` en `shared/.env` |
| `.env` con secretos en git y en producción | versionado | `git rm --cached .env`, `.gitignore`, `shared/.env` y **rotar** `SMTP_PASS` |
| `.git`, tests y PHPUnit en producción | rsync de todo el checkout | release limpia + `composer install --no-dev --optimize-autoloader` |
| "Despliego y no cambia nada" | `opcache.validate_timestamps=0` | `systemctl reload php8.2-fpm` tras cambiar `current` |
| Despliegue a medias durante el rsync | se copia encima del código en uso | `releases/<sha>` + `mv -T` atómico del enlace `current` |
| Reservas consecutivas rechazadas | `<=` / `>=` en el solape | `<` / `>` (lo detecta PHPUnit) |
| Cualquier rama, sin tests | workflow de un solo paso | job `test` + job `deploy` con `needs: test` sólo en `main` |

El script de despliegue y el workflow completos están en `solve.sh`.

## Por qué así

- **`mv -T` sobre un enlace temporal** es un `rename(2)`: atómico. `ln -sfn`
  directamente sobre `current` borra y crea: hay un instante sin enlace.
- **`$realpath_root` en nginx**: php-fpm recibe la ruta real
  (`releases/<sha>/public/index.php`), no `current/...`, así una petición que
  empieza durante el cambio no mezcla ficheros de dos releases.
- **`--no-dev --optimize-autoloader`**: menos código en producción (nada de
  PHPUnit expuesto) y un autoloader con mapa de clases, más rápido.
- **5 releases**: rollback instantáneo (`ln -sfn releases/<anterior>`) sin
  llenar el disco.

## Más allá del lab

- Deployer (PHP) o Capistrano automatizan exactamente este esquema, también en varios servidores.
- Migraciones de base de datos compatibles con la release anterior (lab 157, expand/contract).
- Un paso de *smoke test* tras el cambio de enlace, con vuelta atrás automática si falla.
