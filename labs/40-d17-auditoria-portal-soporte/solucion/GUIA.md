# Resolución guiada · Día 17

:::piensa Antes de tocar nada
Las notas de traspaso describen la intención; `docker inspect` describe la realidad. Ve campo por campo y desconfía de cada afirmación de las notas hasta comprobarla. Y recuerda: el informe de auditoría no puede convertirse en otra fuga. **Nombres de variables, nunca valores.**
:::

## Paso 1 · Imagen y usuario

**Pregúntate:** ¿qué imagen exacta (con etiqueta) corre? ¿Con qué usuario? ¿Qué significa un `User` vacío?

:::pista Cómo comprobarlo
```bash
docker inspect support-portal --format '{{.Config.Image}} user="{{.Config.User}}"'
docker exec support-portal id
```
`User` vacío = el usuario por defecto de la imagen, que casi siempre es root. `id` lo confirma.
:::

## Paso 2 · Puertos

**Pregúntate:** en una publicación, ¿cuál es el lado del host y cuál el del contenedor?

:::pista Cómo comprobarlo
```bash
docker port support-portal
```
`8000/tcp -> 0.0.0.0:NNNN`: izquierda = contenedor, derecha = host.
:::

## Paso 3 · Montaje

**Pregúntate:** ¿es un volumen con nombre o una carpeta del host (bind)? ¿Lectura o escritura?

:::pista Cómo comprobarlo
```bash
docker inspect support-portal --format '{{json .Mounts}}'
```
Mira `Type`, `Source`, `Destination` y `RW`.
:::

## Paso 4 · Secretos en el entorno

**Pregúntate:** ¿de dónde salen las variables? Unas se pasaron con `-e`; otras vienen **horneadas en la imagen** (`ENV` del Dockerfile). ¿Cuáles son credenciales y cuáles no?

:::pista Cómo comprobarlo
```bash
docker inspect support-portal --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1
docker image inspect support/portal:2.3.1 --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1
```
`cut -d= -f1` te deja sólo los nombres: así no ves ni copias valores. Descarta las de la imagen base (`PATH`, `LANG`, `PYTHON_*`, `GPG_KEY` — esta última es una huella pública, no una credencial). Busca nombres con `PASSWORD`, `TOKEN`, `SECRET`, `KEY`.
:::

## Paso 5 · Informe

:::pista Formato
```bash
mkdir -p ~/audit
cat > ~/audit/support-portal.txt <<'EOF'
imagen=<imagen:etiqueta>
puerto_host=<n>
puerto_contenedor=<n>
montaje_origen=<ruta>
montaje_destino=<ruta>
montaje_modo=<rw|ro>
usuario=<usuario>
secretos_env=<NOMBRE1,NOMBRE2>
EOF
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Cada dato de las notas, contrastado** con el runtime.
- **Un secreto en `ENV` del Dockerfile** lo tiene cualquiera que descargue la imagen: es un hallazgo grave.
- **Informes sin valores secretos**: si el informe se filtra, no debe filtrar credenciales.
- Hallazgos típicos a reportar: corre como root, bind mount `rw` del host, secretos en la imagen.

## Si te atascas

- No sabes si una variable es secreto: si su nombre habla de contraseña, token o clave, lo es.
