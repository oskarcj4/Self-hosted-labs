# Services sin tráfico

> Kubernetes · Services · EndpointSlices · selectores · targetPort · readiness

## Escenario

`kubectl get pods`: todo `Running`. Y aun así, ningún servicio de la tienda
responde:

```bash
probar-servicios
  catalogo  -> sin respuesta
  pagos     -> sin respuesta
  ...
```

Un Service no "tiene" pods. Es un nombre, una IP virtual y un **selector**.
Kubernetes busca los pods que encajan con el selector, se queda con los que
están **Ready**, traduce `targetPort` al puerto del contenedor y lo publica
en los **EndpointSlices**. kube-proxy reparte el tráfico sólo entre esas
direcciones. Si cualquier eslabón falla, el Service existe pero no lleva
tráfico a ningún sitio.

Hay cuatro Services rotos (`catalogo`, `pagos`, `carrito` y `usuarios`),
cada uno por una causa distinta.

## Objetivos

1. Los cuatro responden `<nombre> ok` en el puerto 80 desde el pod `cliente`.
2. Todas las réplicas de cada uno reciben tráfico.
3. `carrito` conserva su readinessProbe: hay que arreglarla, no quitarla.
4. Los cambios quedan en `~/manifiestos/` y aplicados.

## Pistas

```bash
kubectl -n tienda get endpointslices                 # ¿hay direcciones? ¿están ready?
kubectl -n tienda describe svc catalogo              # Selector, TargetPort, Endpoints
kubectl -n tienda get pods --show-labels
kubectl -n tienda describe pod -l app=carrito        # eventos: Readiness probe failed
kubectl -n tienda exec deploy/cliente -- wget -qO- http://<IP-del-pod>:<puerto>/
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
