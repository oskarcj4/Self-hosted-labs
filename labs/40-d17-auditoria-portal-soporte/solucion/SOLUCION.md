# Solución — Día 17: Auditar un contenedor del portal de soporte

## 1. Imagen, usuario y puertos

```bash
docker inspect support-portal --format '{{.Config.Image}} user="{{.Config.User}}"'
# support/portal:2.3.1 user=""      <- vacío = root (las notas decían 2.2 y "portal")
docker exec support-portal id        # uid=0(root)
docker port support-portal           # 8000/tcp -> 0.0.0.0:8088 (las notas decían 8080)
```

## 2. Montaje

```bash
docker inspect support-portal --format '{{json .Mounts}}' | jq
# Type: bind, Source: /srv/support/uploads, Destination: /app/uploads, RW: true
```

Las notas hablaban de un volumen con nombre en sólo lectura: en realidad es un
**bind mount** de una carpeta del host, en **lectura/escritura**.

## 3. Secretos en el entorno

```bash
docker inspect support-portal --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1
# SUPPORT_SMTP_PASSWORD   <- docker run -e
# SUPPORT_SMTP_HOST
# PATH, LANG, GPG_KEY, PYTHON_VERSION, PYTHON_SHA256   <- de la imagen base (no son secretos)
# PORTAL_ENV
# ZENDESK_API_TOKEN       <- horneado en la imagen (ENV del Dockerfile)
docker history --no-trunc support/portal:2.3.1 | grep ZENDESK   # confirma que viene de la imagen
```

`GPG_KEY` es la huella pública con la que se verificó Python: no es una credencial.

## 4. Informe

```
imagen=support/portal:2.3.1
puerto_host=8088
puerto_contenedor=8000
montaje_origen=/srv/support/uploads
montaje_destino=/app/uploads
montaje_modo=rw
usuario=root
secretos_env=SUPPORT_SMTP_PASSWORD,ZENDESK_API_TOKEN
```

## Lecciones

- La documentación describe la intención; `docker inspect` describe la realidad.
- `Config.User` vacío = root.
- `Config.Env` mezcla lo pasado con `-e` y lo heredado de la imagen: un secreto
  en `ENV` del Dockerfile lo tiene **cualquiera que descargue la imagen**.
- Los informes de auditoría no deben convertirse en otra fuga: nombres, no valores.
