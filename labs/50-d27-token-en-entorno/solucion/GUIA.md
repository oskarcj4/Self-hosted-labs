# Resolución guiada · Día 27

:::piensa Antes de tocar nada
Un token escrito en `compose.yaml` está en el repositorio, en su historial, en `docker inspect` y en el entorno de cada proceso del contenedor. El patrón que lo arregla tiene un nombre: `*_FILE`. La variable de entorno lleva **la ruta**; el secreto vive en un fichero montado en sólo lectura.
:::

## Paso 1 · ¿Dónde se ve hoy?

:::pista Cómo comprobarlo
```bash
cd ~/files
grep -n TOKEN compose.yaml
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep TOKEN
```
:::

## Paso 2 · ¿Qué soporta la app?

**Pregúntate:** antes de diseñar, ¿de dónde sabe leer el token?

:::pista Cómo comprobarlo
```bash
grep -n 'TOKEN' app/app.py
```
Busca la variable `*_FILE`: le das una ruta y lee el fichero.
:::

## Paso 3 · El token a un fichero, creado ya cerrado

**Pregúntate:** ¿cómo creo el fichero sin que haya un instante en que sea legible?

:::pista Cómo hacerlo
```bash
mkdir -p secrets && chmod 0700 secrets
install -m 0600 /dev/null secrets/uploader_token.txt
grep -o 'upl_live_[a-z0-9]*' compose.yaml > secrets/uploader_token.txt
echo 'secrets/' >> .gitignore
```
Añadirlo a `.gitignore` evita que el fichero acabe en el repositorio.
:::

## Paso 4 · Que Compose lo monte

**Pregúntate:** ¿qué hace un `secret` de Compose con `file:`? Monta el fichero en `/run/secrets/<nombre>`, en sólo lectura, y no aparece en el entorno.

:::pista Cómo hacerlo
En el servicio `uploader`: quita la variable con el token y añade:
```yaml
    environment:
      ROLE: uploader
      UPLOADER_API_TOKEN_FILE: /run/secrets/uploader_token
    secrets:
      - uploader_token
```
Y al final del fichero:
```yaml
secrets:
  uploader_token:
    file: ./secrets/uploader_token.txt
```
```bash
docker compose up -d
```
:::

## Paso 5 · Verifica

```bash
grep -c upl_live compose.yaml                 # 0
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep TOKEN
sleep 5; docker compose exec uploader cat /tmp/status
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Patrón `*_FILE`**: muchas imágenes oficiales lo soportan (`POSTGRES_PASSWORD_FILE`…).
- **Crea cerrado, escribe después** (`install -m 0600 /dev/null`).
- **El token estuvo en el YAML y en su historial de git**: en un caso real, **rótalo**. Quitarlo del fichero no lo borra del historial.

## Si te atascas

- La app dice que no encuentra el token: comprueba que la ruta de `UPLOADER_API_TOKEN_FILE` coincide con `/run/secrets/<nombre-del-secret>`.
