# Resolución guiada · Día 27

:::piensa La variable lleva la ruta, no el secreto
Un token escrito en `compose.yaml` está en el repositorio (y en su historial),
en `docker inspect`, en `docker compose config` y en el entorno de cada
proceso del contenedor. El patrón que lo arregla tiene nombre: `*_FILE`. La
variable de entorno lleva **la ruta** de un fichero; el secreto vive en ese
fichero, montado en sólo lectura.
:::

**El plan:** (1) ver dónde se filtra hoy, (2) confirmar que la app sabe leer
un fichero, (3) pasar el token a un fichero protegido, (4) que Compose lo
monte y (5) comprobar.

## Paso 1 · ¿Dónde se ve hoy?

:::pista Cómo hacerlo
```bash
cd ~/files
grep -n TOKEN compose.yaml
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep TOKEN
```
`{{range .Config.Env}}{{println .}}{{end}}` recorre la lista de variables del
contenedor y las imprime una por línea (`.` es el elemento actual).

**Qué deberías ver:** el mismo `upl_live_…` en el fichero y en el contenedor.
Cualquiera con acceso a Docker en esta máquina puede leerlo.
:::

## Paso 2 · ¿Qué sabe leer la app?

:::pista Cómo hacerlo
```bash
grep -n 'TOKEN' app/app.py
```
**Qué deberías ver:** la función `token()` mira primero
`UPLOADER_API_TOKEN_FILE`: si existe, abre ese fichero y lee el token. Sólo si
no existe usa la variable con el token directo.
:::

## Paso 3 · El token a un fichero, creado ya cerrado

**Pregúntate:** ¿cómo creas el fichero sin que haya un instante en que otros
puedan leerlo?

:::pista Cómo hacerlo
```bash
install -d -m 0700 secrets
install -m 0600 /dev/null secrets/uploader_token.txt
grep -o 'upl_live_[a-z0-9]*' compose.yaml > secrets/uploader_token.txt
echo 'secrets/' >> .gitignore
ls -la secrets/
```
- `install -d -m 0700` crea la carpeta **ya** con permisos `700`.
- `install -m 0600 /dev/null fichero` crea un fichero vacío que nace con
  permisos `600`. Con `echo … > fichero` nacería con `644` (legible por todos)
  y luego tendrías que cerrarlo: durante ese instante, cualquiera podría leerlo.
- `grep -o` imprime sólo el trozo que coincide con el patrón (el token), no la
  línea entera. `>` lo escribe en el fichero respetando sus permisos.
- `.gitignore` evita que el fichero acabe en el repositorio.

**Qué deberías ver:** `-rw-------` en `uploader_token.txt`.
:::

## Paso 4 · Que Compose lo monte

**Objetivo:** que el contenedor reciba el fichero y la ruta, y nada más.

:::pista Cómo hacerlo
En `compose.yaml`, el servicio `uploader` queda así (sin la línea
`UPLOADER_API_TOKEN: upl_live_…`):
```yaml
  uploader:
    image: files/app:1.0
    environment:
      ROLE: uploader
      UPLOADER_API_TOKEN_FILE: /run/secrets/uploader_token
    secrets:
      - uploader_token
    restart: unless-stopped
```
Y al final del fichero, sin sangría:
```yaml
secrets:
  uploader_token:
    file: ./secrets/uploader_token.txt
```
- El bloque `secrets:` de abajo declara un secreto y de qué fichero sale.
- `secrets: [uploader_token]` en el servicio lo monta en
  `/run/secrets/uploader_token`, en sólo lectura.

```bash
docker compose up -d
```
`up -d` recrea `uploader` porque su configuración ha cambiado.
:::

## Paso 5 · Comprueba

```bash
grep -c upl_live compose.yaml
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep TOKEN
sleep 5; docker compose exec uploader cat /tmp/status
bash /opt/lab/check.sh
```
**Qué deberías ver:** `0` en el `grep -c`, sólo `UPLOADER_API_TOKEN_FILE=/run/secrets/…`
en el entorno, y `ok (file) storage ok`: el `(file)` confirma que el token
salió del fichero.

## Cómo actuar en una situación así

- **Patrón `*_FILE`:** muchas imágenes oficiales lo soportan
  (`POSTGRES_PASSWORD_FILE`, `MYSQL_ROOT_PASSWORD_FILE`…).
- **Crea cerrado, escribe después** (`install -m 0600 /dev/null`).
- El token estuvo en el YAML y, si estaba en git, en su historial: **rótalo**.
  Quitarlo del fichero no lo borra del historial.

## Si te atascas

- **`/tmp/status` dice `ok (env)`:** el contenedor sigue con la variable vieja.
  Revisa que la quitaste y que hiciste `docker compose up -d`.
- **`No such file or directory: '/run/secrets/…'`:** el nombre de
  `UPLOADER_API_TOKEN_FILE` no coincide con el nombre del secreto.
- **`secrets/uploader_token.txt` está vacío:** el `grep -o` se hizo después de
  quitar el token de `compose.yaml`. Está en `docker inspect` mientras el
  contenedor viejo exista.
