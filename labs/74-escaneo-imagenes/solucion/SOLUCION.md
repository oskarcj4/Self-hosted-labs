# Solución — Escaneo de imágenes: a 0 CRITICAL

## 1. Escanear y leer bien el resultado

```bash
cd /srv/api
grype inventario-api:local
```

Salen decenas de CVE, varios CRITICAL. La pregunta no es "cuántos", sino
**de dónde**:

```bash
grype inventario-api:local -o json \
  | jq -r '.matches[] | [.vulnerability.severity, .artifact.name, .vulnerability.id] | @tsv' \
  | sort | grep -i critical
# Critical  busybox   CVE-...
# Critical  openssl   CVE-...
# Critical  libcrypto3 CVE-...
# ...
```

Casi todos son paquetes del **sistema base** (busybox, openssl, sqlite...),
no de tu app. Eso apunta a la imagen base, no a tu `main.py`.

```bash
head -3 Dockerfile
# FROM python:3.12.0-alpine3.18        <- Alpine 3.18, de hace año y medio
```

## 2. Actualizar la base

```bash
docker images | grep python
# python  3.12.0-alpine3.18   ...   (vieja)
# python  3.12-alpine         ...   (mantenida)
```

```bash
sed -i 's#^FROM python:3.12.0-alpine3.18#FROM python:3.12-alpine#' Dockerfile
docker build -t inventario-api:local .
grype inventario-api:local
# ... 0 Critical
docker run --rm inventario-api:local      # inventario-api ok
```

Subir la base a la versión mantenida se lleva por delante todos los CRITICAL
(y casi todos los HIGH): son fallos del sistema operativo de la imagen, que
los mantenedores ya han parcheado. Tu código no cambia.

## 3. Verificar

```bash
bash /opt/lab/check.sh
```

## Por qué así (y no de otras formas)

- **Arreglar en el Dockerfile**, no "parcheando" una imagen a mano. La imagen
  se reconstruye en cada pipeline: si no está en el Dockerfile versionado, el
  arreglo se pierde en el siguiente build.
- **Fijar la versión de la base** (`python:3.12-alpine` o, mejor aún, por
  digest `@sha256:...`) para que el build sea reproducible, y
  **re-escanear periódicamente**: una imagen "limpia" hoy acumula CVE con el
  tiempo sin tocar una línea. El escaneo va en CI y también programado.
- **0 CRITICAL como puerta (gate)**, no "revisarlo luego". Un umbral
  automático que bloquea el merge es lo que de verdad frena la deuda de
  seguridad.
- Mismo método para **tus dependencias**: `grype dir:.` o sobre el
  `requirements.txt`/`package-lock.json`. Un Django o un openssl viejos en tus
  deps salen igual; la cura es la misma: subir de versión y volver a escanear.

## Sobre el escáner mismo

En este lab grype está **fijado a una versión** y se instaló verificando su
**checksum** (ver el Dockerfile del lab), con la base de datos de CVE cargada
en local. Un escáner de seguridad es código con mucho privilegio en tu
pipeline: trátalo como cualquier otra dependencia crítica —versión fijada,
checksum, origen de confianza— y no lo bajes "a pelo" en cada ejecución.

## Lecciones

- La mayoría de los CVE de una imagen vienen de la **base**, no de tu código.
- Actualizar y fijar la base, y re-escanear, es el 80% del trabajo.
- El gate automático (0 CRITICAL bloquea) es lo que mantiene la higiene.
- El propio escáner es cadena de suministro: fíjalo y verifícalo (lab 77).
