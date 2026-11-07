# Vistas previas por PR

> DevOps · entornos efímeros · Docker Compose (proyectos) · datos de prueba · limpieza

## Escenario

Producto quiere ver cada cambio antes de fusionarlo. `ci/preview.sh`
levanta una "vista previa" por PR, pero:

- todas comparten proyecto, imagen y puerto: **la última pisa a la anterior**;
- hace `git checkout` en tu copia de trabajo;
- copia la base de datos de **producción**, con datos personales reales, en
  cada vista previa (que además ve más gente);
- `down` deja el volumen, y los PRs cerrados se quedan levantados para siempre.

Docker corre **dentro** del lab. El repo es `~/tienda`, con las ramas
`pr-11`, `pr-12` y `pr-13`.

## Objetivos

`preview` (= `~/tienda/ci/preview.sh`):

| Orden | Qué hace |
|-------|----------|
| `preview up N` | rama `pr-N` en `http://127.0.0.1:<9000+N>`. Proyecto `pr-N`, imagen `tienda:pr-N`, datos propios desde `datos/semilla.sql`. Relanzarlo actualiza. No toca `~/tienda`. |
| `preview down N` | borra contenedores, red, volumen e imagen del PR |
| `preview gc` | borra las de PRs que no están en `/srv/prs-abiertos.txt` |

Y borra los restos del script viejo, con la copia de producción.

## Pistas

```bash
docker compose -p pr-11 -f ci/preview.compose.yaml up -d   # -p: nombre de proyecto
git archive pr-11 | tar -x -C /tmp/pr-11                     # la rama, sin checkout
docker ps -a --format '{{.Label "com.docker.compose.project"}}'
docker compose -p pr-11 down -v                              # -v: también los volúmenes
```

En el compose, `${PREVIEW_PORT:?}` falla si la variable no está definida.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
