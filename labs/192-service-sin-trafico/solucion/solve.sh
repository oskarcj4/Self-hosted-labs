#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/manifiestos
# 1. catalogo: el selector del Service no coincide con las etiquetas de los pods.
sed -i 's/selector: {app: catalog, equipo: productos}/selector: {app: catalogo, equipo: productos}/' catalogo.yaml
# 2. pagos: targetPort apunta a un puerto en el que no escucha nadie.
sed -i 's/ports: \[{port: 80, targetPort: 80}\]/ports: [{port: 80, targetPort: 8080}]/' pagos.yaml
# 3. carrito: la readinessProbe pide una ruta que no existe (404) -> nunca Ready.
sed -i 's#httpGet: {path: /healthz, port: 8080}#httpGet: {path: /salud, port: 8080}#' carrito.yaml
# 4. usuarios: targetPort con nombre "http", pero el puerto del contenedor se llama "web".
sed -i 's/targetPort: http}/targetPort: web}/' usuarios.yaml
kubectl apply -f .
kubectl -n tienda rollout status deploy/carrito --timeout=120s
sleep 2
probar-servicios
echo "solve.sh completado."
