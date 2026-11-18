# Pipeline full stack: PHP con despliegue atómico

> DevOps · CI/CD · Gitea Actions · PHP 8.2 · Composer · PHPUnit · php-fpm · releases atómicas

## Escenario

La app de reservas de salas (PHP 8.2 + SQLite, servida por nginx + php-fpm)
"se despliega" con un `rsync` en caliente sobre `/var/www/reservas`. Las
quejas se acumulan:

- en producción están `.git`, los tests, PHPUnit y el **`.env` con la
  contraseña SMTP**, que además está **versionado en git**;
- *"cada vez que desplegamos desaparecen las reservas"*;
- *"no se puede reservar una sala justo cuando acaba otra reserva"*;
- *"a veces desplegamos y no cambia nada hasta que alguien reinicia algo"*;
- cualquier rama despliega, y no se pasa ni un test.

Toca montar despliegues **atómicos**, al estilo Capistrano/Deployer:

```
/var/www/reservas/releases/<sha>    una carpeta por despliegue
/var/www/reservas/shared/           .env y data/ (sobreviven a los despliegues)
/var/www/reservas/current -> releases/<sha>    cambio atómico del enlace
```

Forja: <http://localhost:4216> (`analista` / `analista123`) · App: <http://localhost:8216>

## Objetivos

1. Pipeline de `main` en verde, con PHPUnit pasando; sólo publica si pasan los tests, y sólo desde `main`.
2. El `.env` fuera del repo, y la contraseña SMTP que se filtró, **rotada**.
3. `current` → `releases/<sha de main>`, nginx sirve `current/public`, como mucho 5 releases.
4. Las releases sin `.git` ni dependencias de desarrollo.
5. `.env` y la base de datos en `shared/`, y **las reservas reales intactas**.
6. Producción corre el commit de `main` y acepta reservas consecutivas.

## Pistas

```bash
cat ~/TAREA.txt; cat /usr/local/bin/publicar-reservas
ls -la /var/www/reservas; cat /etc/php/8.2/fpm/conf.d/90-produccion.ini
ci-log; ls /var/backups/
```

Piensa en el orden: ¿qué pasa con los datos si el pipeline despliega **una
vez más** con el script viejo antes de que los saques de ahí?

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
