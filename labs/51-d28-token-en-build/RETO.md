# Día 28 — Sacar un token del build de la imagen

> 30 días de DevSecOps · Docker · Endurecimiento de imágenes

## Escenario

`notifier` (stack `notify`, en `~/notify`) envía avisos a una pasarela con un
token. El `Dockerfile` lo mete **en la imagen**: como `ARG` con valor por
defecto, como `ENV` y además en un fichero `/app/.token`. Cualquiera que
tenga la imagen (registro, CI, un portátil) tiene el token:

```bash
docker history --no-trunc notify/app:1.0 | grep -i token
docker image inspect notify/app:1.0 --format '{{json .Config.Env}}'
```

## Objetivos

1. El `Dockerfile` no debe contener el token ni declarar `ARG`/`ENV NOTIFY_TOKEN`.
2. **Ninguna imagen local** (tampoco las `<none>` que quedan al reconstruir)
   puede contener el token en historial, metadatos o capas.
3. El token se entrega **en ejecución** como fichero (la app lo lee de
   `NOTIFY_TOKEN_FILE`) y no aparece en el entorno del contenedor.
4. `notifier` se autentica: `/tmp/status` → `ok (file) gateway ok`.

## Comandos que te pueden servir

```bash
cd ~/notify && cat compose.yaml app/Dockerfile
docker images -a                      # incluye las <none>
docker compose up -d --build
docker image prune                    # borra imágenes colgantes (<none>)
docker rmi <id>
docker save notify/app:1.0 | grep -ac ntf_live    # ¿sigue en alguna capa?
docker compose exec notifier cat /tmp/status
```

> El validador revisa **todas** las imágenes locales, incluido `docker save`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
