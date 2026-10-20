# Día 17 — Auditar un contenedor del portal de soporte

> 30 días de DevSecOps · Docker · Exposición del runtime de contenedores

## Escenario

El portal de soporte corre en este host como un contenedor lanzado a mano
(`docker run`, sin Compose). En `~/support/NOTAS-TRASPASO.md` el equipo
anterior describe cómo está desplegado… pero nadie ha comprobado si es verdad.

Registra lo que **realmente** corre, sacándolo del runtime.

## Objetivos

Crea `~/audit/support-portal.txt` con este formato `clave=valor`:

```
imagen=<imagen:etiqueta del contenedor>
puerto_host=<puerto publicado en el host>
puerto_contenedor=<puerto del contenedor al que llega>
montaje_origen=<ruta o volumen de origen>
montaje_destino=<ruta dentro del contenedor>
montaje_modo=<rw | ro>
usuario=<usuario efectivo del proceso>
secretos_env=<NOMBRES de las variables de entorno que contienen credenciales, separados por comas>
```

- Mira **todas** las variables: las que se pasaron con `-e` y las que trae la imagen.
- Apunta sólo **nombres** de variables, nunca sus valores.
- No recrees ni pares el contenedor.

## Comandos que te pueden servir

```bash
docker ps
docker inspect support-portal | jq '.[0].Config.Image, .[0].Config.User'
docker inspect support-portal --format '{{json .NetworkSettings.Ports}}' | jq
docker inspect support-portal --format '{{json .Mounts}}' | jq
docker inspect support-portal --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1
docker image inspect support/portal:2.3.1 --format '{{json .Config.Env}}' | jq
docker exec support-portal id
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
