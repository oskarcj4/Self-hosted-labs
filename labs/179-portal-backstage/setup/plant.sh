#!/usr/bin/env bash
# Lab 179: catálogo de software al estilo Backstage. El repo del catálogo tiene
# errores de formato y referencias rotas, y el servicio de notificaciones no
# está en el catálogo. El alumno lo arregla y lo registra con su documentación.
set -e
H=/home/analista
R=$H/plataforma/catalogo
install -m 0755 /opt/lab/setup/catalogo /usr/local/bin/catalogo
mkdir -p $R/sistemas $R/servicios/{pagos,catalogo,envios,notificaciones}

cat > $R/catalog-info.yaml <<'Y'
# Location raíz: el portal sólo carga lo que esté aquí.
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: catalogo-raiz
  description: Todo el software de la tienda
spec:
  targets:
    - ./equipos.yaml
    - ./sistemas/tienda.yaml
    - ./servicios/pagos/catalog-info.yaml
    - ./servicios/catalogo/catalog-info.yaml
    - ./servicios/envios/catalog-info.yaml
Y
cat > $R/equipos.yaml <<'Y'
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: ingenieria
spec:
  type: area
  children: [equipo-pagos, equipo-catalogo, plataforma]
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: equipo-pagos
  description: Cobros y reembolsos
spec:
  type: team
  parent: ingenieria
  children: []
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: equipo-catalogo
spec:
  type: team
  parent: ingenieria
  children: []
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: plataforma
  description: Infraestructura, CI/CD y herramientas internas
spec:
  type: team
  parent: ingenieria
  children: []
Y
cat > $R/sistemas/tienda.yaml <<'Y'
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: tienda
  description: La tienda online
spec:
  owner: ingenieria
Y
cat > $R/servicios/pagos/catalog-info.yaml <<'Y'
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: pagos
  description: Cobra los pedidos con la pasarela
  annotations:
    github.com/project-slug: tienda/pagos
spec:
  type: service
  lifecycle: production
  owner: equipo-pagos
  system: tienda
  providesApis: [pagos-api]
  dependsOn: [resource:postgres-pagos]
Y
cat > $R/servicios/pagos/openapi.yaml <<'Y'
openapi: 3.0.3
info: {title: API de pagos, version: 1.4.0}
paths:
  /cobros:
    post:
      summary: Crea un cobro
      responses: {"201": {description: Cobro creado}}
  /cobros/{id}/reembolso:
    post:
      summary: Reembolsa un cobro
      parameters: [{name: id, in: path, required: true, schema: {type: string}}]
      responses: {"200": {description: Reembolsado}}
Y
cat > $R/servicios/catalogo/catalog-info.yaml <<'Y'
apiVersion: backstage.io/v1
kind: Component
metadata:
  name: Catalogo de productos
  description: Búsqueda y fichas de producto
spec:
  type: service
  lifecycle: production
  owner: equipo-catalogo
  system: tienda
Y
cat > $R/servicios/envios/catalog-info.yaml <<'Y'
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: envios
  description: Calcula y contrata envíos
spec:
  type: service
  lifecycle: production
  owner: equipo-logistica
  system: tienda
  consumesApis: [pagos-api]
Y
cat > $R/servicios/notificaciones/app.py <<'PY'
"""notificaciones: envía correos y SMS cuando cambia el estado de un pedido.
Lee los envíos (servicio envios) y escribe en la cola 'eventos-pedido'."""
PY
cat > $R/servicios/notificaciones/README.md <<'MD'
# notificaciones

Envía correos y SMS a los clientes cuando cambia el estado de su pedido.

- Equipo: plataforma (canal #plataforma)
- Depende de: el servicio de envíos
- Guardia: rotación de plataforma
MD
cat > $R/CONTRIBUIR.md <<'MD'
# Cómo añadir un servicio al catálogo

1. Crea `catalog-info.yaml` junto al código del servicio (kind: Component).
2. Rellena owner (un Group), system, lifecycle y type.
3. Añade su ruta a `targets` en el `catalog-info.yaml` raíz.
4. Documentación (TechDocs): `mkdocs.yml` + `docs/index.md` y la anotación
   `backstage.io/techdocs-ref: dir:.`
5. `catalogo validar` debe salir sin errores ni avisos.
MD
cd $R && git init -q -b main && git add -A && git -c user.name=plataforma -c user.email=plataforma@tienda.local commit -qm "Catálogo inicial"
chown -R analista:analista $H/plataforma
git config --system --add safe.directory '*'

cat > /etc/systemd/system/portal.service <<'U'
[Unit]
Description=Portal interno (catálogo de software)
[Service]
User=analista
ExecStart=/usr/local/bin/catalogo servir /home/analista/plataforma/catalogo 7007
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now portal

cat > $H/TAREA.txt <<'TXT'
TAREA · Portal interno (catálogo de software al estilo Backstage)

El catálogo vive en git: ~/plataforma/catalogo. El portal (http://127.0.0.1:7007)
lo lee en cada petición. Hoy nadie se fía de él: tiene errores y le faltan cosas.

1. catalogo validar ~/plataforma/catalogo   -> arregla TODOS los errores:
   formato, nombres, dueños que no existen, APIs y recursos que no existen.
   (El equipo de envíos es "equipo-logistica", dentro de ingenieria.
    La base de datos de pagos es un Resource de tipo database, de equipo-pagos.
    La API de pagos es de tipo openapi; su definición está en openapi.yaml.)
2. Registra el servicio notificaciones (lee su README.md y CONTRIBUIR.md):
   Component con owner, system, lifecycle production, dependencia de envios
   y documentación TechDocs.
3. catalogo validar debe salir sin errores ni avisos, y el portal debe
   mostrar a notificaciones con su dueño y su dependencia.
4. Haz commit de los cambios en el repo del catálogo.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 179 plantado."
