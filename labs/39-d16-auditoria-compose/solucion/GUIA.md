# Resolución guiada · Día 16

:::piensa El disco no es la verdad
`compose.yaml` y el `README` describen lo que **alguien quería** desplegar. Lo
que está corriendo puede ser otra cosa: aquí alguien aplicó un *hotfix* con
otro fichero y lo borró. La fuente de verdad es el **runtime**: Docker sabe
exactamente cómo creó cada contenedor. Y la regla de oro de una auditoría: no
cambia nada. Un `docker compose up` "para ver" volvería a crear el stack según
el disco y **borraría la evidencia** del hotfix.
:::

**El plan:** (1) qué corre y qué publica, (2) las redes de cada servicio,
(3) el volumen compartido, (4) comparar con la documentación y (5) escribir el
informe.

## Paso 1 · ¿Qué corre y qué publica?

**Objetivo:** el servicio que expone un puerto en el host y cuál es ese puerto.

:::pista Cómo hacerlo
```bash
docker compose -p handoff ps
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```
- `-p handoff` le dice a Compose qué **proyecto** mirar, sin necesitar el
  `compose.yaml`. Compose reconoce sus contenedores por las etiquetas que les
  puso al crearlos.
- `--format` elige las columnas con una plantilla. `{{.Names}}` y `{{.Ports}}`
  son campos de cada contenedor; `table` y `\t` los alinean en columnas.

**Qué deberías ver:** un solo contenedor con algo como `0.0.0.0:A->B/tcp`. En
esa notación, **A** es el puerto del **host** y **B** el del contenedor. El
informe pide A. (`docker port <contenedor>` te da lo mismo, más limpio.)
:::

## Paso 2 · Las redes de cada servicio

**Objetivo:** en qué redes está conectado cada contenedor de verdad.

**Pregúntate:** `docker inspect` devuelve un JSON enorme con toda la
configuración. ¿Cómo sacas sólo la lista de redes?

:::pista Cómo hacerlo
```bash
for s in web api worker db; do
  printf '%s: ' $s
  docker inspect handoff-$s-1 --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
  echo
done
```
`--format` usa las **plantillas de Go**:

| Pieza | Qué hace |
|---|---|
| `.NetworkSettings.Networks` | Dentro del JSON del contenedor, el objeto con una entrada por red. La **clave** de cada entrada es el nombre de la red. |
| `{{range $k,$v := …}} … {{end}}` | Recorre ese objeto: en cada vuelta, `$k` es la clave (el nombre) y `$v` el valor (los detalles). |
| `{{$k}} ` | Imprime el nombre y un espacio. |

El `for` de bash repite el comando para los cuatro servicios; los
contenedores de Compose se llaman `<proyecto>-<servicio>-<n>`.

**Qué deberías ver:** nombres como `handoff_backend`, con el prefijo del
proyecto. El informe acepta los nombres con o sin prefijo.
:::

## Paso 3 · El volumen compartido

**Objetivo:** el volumen que montan **varios** servicios. Es un canal de datos
entre ellos: si uno se ve comprometido, puede leer o alterar lo que escribe el
otro.

:::pista Cómo hacerlo
```bash
for s in web api worker db; do
  echo "$s: $(docker inspect handoff-$s-1 --format '{{range .Mounts}}{{.Type}}:{{.Name}}->{{.Destination}} {{end}}')"
done
```
`.Mounts` es una lista; `{{range .Mounts}}` recorre cada montaje y, dentro,
`.Type` (volumen o carpeta del host), `.Name` (nombre del volumen) y
`.Destination` (dónde aparece dentro del contenedor).

**Qué deberías ver:** un mismo nombre de volumen en dos servicios.
:::

## Paso 4 · Compara con la documentación

**Objetivo:** encontrar las diferencias entre lo documentado y lo real. Son el
valor de tu auditoría: cada una es una tarea pendiente.

```bash
cat ~/handoff/README.md ~/handoff/compose.yaml
```
Fíjate en el puerto, en qué servicios comparten red y en qué volúmenes hay.

## Paso 5 · Escribe el informe

:::pista Cómo hacerlo
```bash
mkdir -p ~/audit
nano ~/audit/handoff.txt
```
```
entrypoint_servicio=<servicio>
entrypoint_puerto=<puerto del host>
redes_web=<redes separadas por comas>
redes_api=<redes>
redes_worker=<redes>
redes_db=<redes>
volumen_compartido=<volumen>
volumen_montado_en=<servicios separados por comas>
```
```bash
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Audita con `docker inspect`**, no con los YAML.
- **No reconcilies** (`up`, `down`, `restart`) hasta haber documentado.
- Filtra por proyecto con sus etiquetas:
  `docker ps --filter label=com.docker.compose.project=handoff`.
- Cada diferencia encontrada es una decisión: incorporar el hotfix al YAML, o
  retirarlo.

## Si te atascas

- **No sabes el nombre de un contenedor:**
  `docker compose -p handoff ps --format '{{.Name}}'`.
- **`template: … map has no entry`:** escribiste mal un campo de la plantilla
  (distingue mayúsculas). Mira el JSON entero con
  `docker inspect handoff-web-1 | less`.
