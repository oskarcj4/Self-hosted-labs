# Escaneo de imágenes: a 0 CRITICAL

> Operaciones · seguridad · contenedores · grype · CVE · imagen base

## Escenario

Estás en `build-01`, con su propio Docker. El pipeline nuevo escanea cada
imagen con **grype** y **bloquea** si hay algún CVE de severidad **CRITICAL**.
`inventario-api:local` no pasa. Lee `~/ticket/SEC-7401.txt`.

El escáner ya está instalado, con su base de datos cargada **en local** (no
hace falta Internet). Hay dos imágenes base de python precargadas.

## Objetivos

1. `inventario-api:local` con **0 vulnerabilidades CRITICAL**.
2. La app sigue arrancando:
   `docker run --rm inventario-api:local` → `inventario-api ok`.
3. El arreglo queda en el **Dockerfile** de `/srv/api` (versionado), no en una
   imagen suelta.

## Comandos que te pueden servir

```bash
cd /srv/api ; cat Dockerfile
grype inventario-api:local                       # tabla de CVE
grype inventario-api:local -o json | jq -r '.matches[]
  | [.vulnerability.severity, .artifact.name, .vulnerability.id] | @tsv' \
  | sort | grep -i critical                      # ¿de qué paquetes salen?
docker images | grep python                      # bases disponibles
docker build -t inventario-api:local .           # reconstruir tras editar
docker run --rm inventario-api:local
```

Pista: fíjate en la **columna del paquete** de los CRITICAL. Si casi todos
vienen del sistema base (openssl, busybox, sqlite...), el problema es la
**imagen base**, no tu código. Actualizar la base suele quitar la mayoría de
un plumazo. Lo mismo vale, dicho sea de paso, para las dependencias que fijes
tú (requirements.txt, package-lock...): escanéalas y súbelas de versión.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
