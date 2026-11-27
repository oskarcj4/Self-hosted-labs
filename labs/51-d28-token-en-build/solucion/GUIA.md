# Resolución guiada · Día 28

:::piensa Una imagen no olvida
Una imagen de Docker es una pila de **capas**, y cada instrucción del
`Dockerfile` deja su rastro: `ENV` en los metadatos, `ARG` en el historial,
`RUN`/`COPY` en una capa. Aunque una capa posterior borre un fichero, la capa
anterior sigue dentro de la imagen. Y cuando reconstruyes, la imagen vieja no
desaparece: se queda como `<none>`, con el token dentro. Arreglar el
`Dockerfile` es sólo la mitad.
:::

**El plan:** (1) encontrar el token en la imagen, (2) guardarlo en un
fichero fuera de la imagen, (3) limpiar el `Dockerfile`, (4) entregarlo en
ejecución, (5) reconstruir y borrar las imágenes viejas y (6) comprobarlo.

## Paso 1 · ¿Por cuántas vías está el token en la imagen?

**Objetivo:** ver con tus ojos las tres fugas que menciona el reto.

:::pista Cómo hacerlo
```bash
cd ~/notify
cat app/Dockerfile
docker history --no-trunc notify/app:1.0 | grep -i token
docker image inspect notify/app:1.0 --format '{{json .Config.Env}}'
docker run --rm notify/app:1.0 cat /app/.token
```

| Comando | Qué enseña |
|---|---|
| `docker history --no-trunc` | La lista de capas con la instrucción que creó cada una. `--no-trunc` muestra las líneas completas; sin él se cortan y no verías el token. El valor del `ARG` aparece en la línea del `RUN` que lo usó. |
| `docker image inspect … {{json .Config.Env}}` | Las variables de entorno guardadas en los **metadatos** de la imagen: ahí acaba todo `ENV`. |
| `docker run --rm … cat /app/.token` | Arranca un contenedor desechable (`--rm` lo borra al terminar) y lee el fichero que escribió el `RUN echo`: está en una **capa**. |

**Qué deberías ver:** el mismo `ntf_live_…` en los tres sitios.
:::

## Paso 2 · Guarda el token fuera de la imagen (antes de reconstruir)

**Objetivo:** tener el token en un fichero protegido. Hazlo **ahora**: cuando
reconstruyas y borres la imagen vieja, ya no podrás sacarlo de ahí.

:::pista Cómo hacerlo
```bash
install -d -m 0700 secrets
install -m 0600 /dev/null secrets/notify_token.txt
docker run --rm notify/app:1.0 cat /app/.token > secrets/notify_token.txt
echo 'secrets/' >> .gitignore
```
- `install -d -m 0700 secrets` crea la carpeta **ya** con permisos `700`
  (sólo tú). Con `mkdir` + `chmod` habría un instante en que es legible.
- `install -m 0600 /dev/null fichero` crea un fichero **vacío** (copia de
  `/dev/null`) que nace con permisos `600`. Después lo rellenas: en ningún
  momento ha sido legible por otros.
- `>` sustituye el contenido del fichero, pero respeta sus permisos.
- `.gitignore` evita que el secreto acabe en el repositorio.
:::

## Paso 3 · Dockerfile limpio

**Objetivo:** que la imagen sólo lleve lo necesario para funcionar: el código.

**Pregúntate:** ¿necesita la imagen el token para **construirse**, o sólo para
**ejecutarse**?

:::pista Cómo hacerlo
Sólo para ejecutarse. Quita el `ARG`, el `ENV` y el `RUN` que escribe el
token. `app/Dockerfile` queda así:
```dockerfile
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
CMD ["python", "-u", "app.py"]
```
:::

## Paso 4 · Token en ejecución, como fichero

**Objetivo:** que el contenedor reciba el token al arrancar, sin que aparezca
en la imagen ni en su entorno.

:::pista Cómo hacerlo
La app ya sabe leerlo de un fichero si le dices dónde con `NOTIFY_TOKEN_FILE`
(mira la función `token()` en `app/app.py`). En `compose.yaml`, deja el
servicio `notifier` así:
```yaml
  notifier:
    image: notify/app:1.0
    build: ./app
    environment:
      ROLE: notifier
      NOTIFY_TOKEN_FILE: /run/secrets/notify_token
    secrets:
      - notify_token
    restart: unless-stopped
```
Y al final del fichero, al nivel de `services:` (sin sangría):
```yaml
secrets:
  notify_token:
    file: ./secrets/notify_token.txt
```

| Pieza | Qué hace |
|---|---|
| `secrets:` (al final) | Declara un secreto llamado `notify_token` cuyo contenido sale de ese fichero de tu máquina. |
| `secrets: [notify_token]` (en el servicio) | Monta ese secreto dentro del contenedor, en `/run/secrets/notify_token`, en sólo lectura. |
| `NOTIFY_TOKEN_FILE` | La variable de entorno lleva **la ruta**, no el token. Quien vea el entorno (`docker inspect`) sólo ve una ruta. |
:::

## Paso 5 · Reconstruye y borra el pasado

**Objetivo:** que la imagen nueva sustituya a la vieja, y que la vieja deje de
existir.

**Pregúntate:** al reconstruir con la misma etiqueta `notify/app:1.0`, ¿qué
pasa con la imagen anterior?

:::pista Cómo hacerlo
```bash
docker compose up -d --build
docker images -a
```
- `--build` reconstruye la imagen antes de arrancar; `up -d` recrea el
  contenedor porque su imagen y su configuración han cambiado.
- `docker images -a` lista **todas** las imágenes, incluidas las intermedias.

**Qué deberías ver:** la nueva `notify/app:1.0` y una línea `<none> <none>`:
es la vieja, que ha perdido la etiqueta pero sigue ahí, con el token dentro.
(Versiones más nuevas de Docker pueden borrarla solas; si no la ves, sigue
igualmente.) Bórrala:
```bash
docker image prune -f
docker builder prune -af
docker images -a
```
- `image prune` borra las imágenes **colgantes** (`<none>`) que no usa ningún
  contenedor. `-f` no pide confirmación.
- `builder prune -af` vacía la caché de construcción, que también guarda las
  capas de los builds anteriores.
:::

## Paso 6 · Verifica en todas las imágenes

```bash
for i in $(docker images -aq); do echo "$i $(docker save $i | grep -ac ntf_live)"; done
docker compose exec notifier cat /tmp/status
bash /opt/lab/check.sh
```
- `docker images -aq` da sólo los IDs (`-q`) de todas las imágenes (`-a`).
- `docker save` vuelca la imagen entera (todas sus capas) como un `tar`.
  `grep -ac` cuenta las líneas que contienen el texto tratando el binario como
  texto (`-a`). Si sale algo distinto de `0`, el token sigue en esa imagen.

**Qué deberías ver:** todas con `0`, y `ok (file) gateway ok`: la app se
autentica con el token del fichero.

## Cómo actuar en una situación así

- **`RUN rm` no borra nada:** la capa anterior sigue dentro de la imagen.
- Si el **build** necesita de verdad un secreto (por ejemplo, para descargar de
  un registro privado): `RUN --mount=type=secret` de BuildKit, que no deja
  rastro en ninguna capa.
- Si la imagen con el token llegó a un registro, el token está filtrado:
  **rótalo** y borra esas etiquetas.

## Si te atascas

- **`image prune` no borra la `<none>`:** algún contenedor, aunque esté
  parado, la sigue usando. `docker ps -a` y `docker rm` ese contenedor.
- **`/tmp/status` dice `ok (image)` o `ok (env)`:** la app no encuentra el
  fichero. Revisa `NOTIFY_TOKEN_FILE` y el bloque `secrets` del servicio.
- **`secrets/notify_token.txt` está vacío:** lo rellenaste después de borrar la
  imagen vieja, y ya no queda ninguna copia del token de la que sacarlo. Es
  justo el orden que evita el paso 2: reinicia el lab y guarda el token antes
  de reconstruir.
