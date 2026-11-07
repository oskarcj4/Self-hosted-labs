# Solución — Services sin tráfico

| Service | Síntoma | Causa | Arreglo |
|---------|---------|-------|---------|
| catalogo | EndpointSlice vacío | selector `app: catalog` ≠ etiqueta `app: catalogo` | selector `app: catalogo` |
| pagos | endpoints, pero connection refused | `targetPort: 80`, el contenedor escucha en 8080 | `targetPort: 8080` |
| carrito | endpoints `ready: false`, pods 0/1 | readinessProbe en `/healthz` (404) | probe en `/salud` |
| usuarios | EndpointSlice sin puertos que sirvan | `targetPort: http`, el puerto se llama `web` | `targetPort: web` |

Los `sed` exactos están en `solve.sh`.

## La cadena de un Service

```
Service (selector, port → targetPort)
   └─ EndpointSlice: IPs de los pods que encajan Y están Ready, con el puerto resuelto
        └─ kube-proxy: reglas iptables/ipvs hacia esas IPs
```

Un pod que encaja pero no está Ready aparece con `ready: false` y no recibe
tráfico. Por eso una readiness probe mal escrita deja un servicio sin
tráfico aunque los pods estén `Running`.

## Más allá del lab

- `kubectl port-forward svc/carrito 8080:80` recorre el mismo camino desde tu máquina.
- Los puertos con nombre permiten cambiar el puerto del contenedor sin tocar el Service.
- Lab 165: si además hay NetworkPolicies, el tráfico puede estar bloqueado aunque todo lo anterior esté bien.
