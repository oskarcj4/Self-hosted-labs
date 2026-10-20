# Solución — Día 27: Token del entorno a un fichero secreto

## 1. La fuga

```bash
cd ~/files
grep TOKEN compose.yaml
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep TOKEN
```

## 2. El token a un fichero cerrado

```bash
mkdir -p secrets && chmod 0700 secrets
install -m 0600 /dev/null secrets/uploader_token.txt
grep -o 'upl_live_[a-z0-9]*' compose.yaml > secrets/uploader_token.txt
echo 'secrets/' >> .gitignore
```

## 3. compose.yaml

```yaml
services:
  storage:
    ...
  uploader:
    image: files/app:1.0
    environment:
      ROLE: uploader
      UPLOADER_API_TOKEN_FILE: /run/secrets/uploader_token
    secrets:
      - uploader_token
    restart: unless-stopped

secrets:
  uploader_token:
    file: ./secrets/uploader_token.txt
```

```bash
docker compose up -d
```

## 4. Verificar

```bash
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep TOKEN
# UPLOADER_API_TOKEN_FILE=/run/secrets/uploader_token     <- la ruta, no el valor
docker inspect files-uploader-1 --format '{{json .Mounts}}' | jq '.[] | {Source,Destination,RW}'
sleep 5; docker compose exec uploader cat /tmp/status     # ... ok (file) storage ok
```

## Lecciones

- Patrón `*_FILE`: la variable lleva **la ruta**; el secreto va en un fichero.
  Muchas imágenes oficiales lo soportan (`POSTGRES_PASSWORD_FILE`, `MYSQL_ROOT_PASSWORD_FILE`…).
- Compose `secrets:` monta en `/run/secrets/` en sólo lectura y no aparece en `docker inspect … Env`.
- El token estuvo en el YAML (y en su historial de git): en un caso real, **rotarlo**.
