#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
R=${CATALOGO:-$HOME/plataforma/catalogo}
cd "$R"
catalogo validar . || true

# 1. catalogo: apiVersion y nombre válidos.
sed -i 's#^apiVersion: backstage.io/v1$#apiVersion: backstage.io/v1alpha1#; s#^  name: Catalogo de productos$#  name: catalogo-productos#' \
  servicios/catalogo/catalog-info.yaml

# 2. El equipo que falta (y su sitio en el árbol).
sed -i 's#children: \[equipo-pagos, equipo-catalogo, plataforma\]#children: [equipo-pagos, equipo-catalogo, equipo-logistica, plataforma]#' equipos.yaml
cat >> equipos.yaml <<'Y'
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: equipo-logistica
  description: Envíos y transportistas
spec:
  type: team
  parent: ingenieria
  children: []
Y

# 3. La API y el recurso que pagos declara.
cat >> servicios/pagos/catalog-info.yaml <<'Y'
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: pagos-api
  description: Cobros y reembolsos
spec:
  type: openapi
  lifecycle: production
  owner: equipo-pagos
  system: tienda
  definition:
    $text: ./openapi.yaml
---
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: postgres-pagos
  description: PostgreSQL de pagos
spec:
  type: database
  owner: equipo-pagos
  system: tienda
Y

# 4. notificaciones: descriptor, TechDocs y registro en la Location raíz.
N=servicios/notificaciones
cat > $N/catalog-info.yaml <<'Y'
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: notificaciones
  description: Correos y SMS cuando cambia el estado de un pedido
  annotations:
    backstage.io/techdocs-ref: dir:.
  tags: [python, correo]
spec:
  type: service
  lifecycle: production
  owner: plataforma
  system: tienda
  dependsOn: [component:envios]
Y
cat > $N/mkdocs.yml <<'Y'
site_name: notificaciones
nav:
  - Inicio: index.md
plugins:
  - techdocs-core
Y
mkdir -p $N/docs
cp $N/README.md $N/docs/index.md
sed -i 's#^    - ./servicios/envios/catalog-info.yaml$#&\n    - ./servicios/notificaciones/catalog-info.yaml#' catalog-info.yaml

catalogo validar .
git add -A
git -c user.name=analista -c user.email=analista@tienda.local commit -qm "Catálogo: arregla referencias y registra notificaciones"
curl -s http://127.0.0.1:7007/api/entities/component/notificaciones | head -30 || true
echo "solve.sh completado."
