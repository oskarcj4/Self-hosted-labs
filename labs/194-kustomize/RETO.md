# Kustomize

> Kubernetes · Kustomize · base y overlays · configMapGenerator · patches

## Escenario

`~/app/dev/` y `~/app/prod/` contienen la misma aplicación copiada a mano.
Ya se han desviado: alguien quitó la `readinessProbe` sólo en prod y nadie
lo notó. Cada cambio hay que hacerlo dos veces, y la próxima vez a alguien
se le olvidará la segunda.

**Kustomize** (incluido en `kubectl`: `kubectl kustomize`, `kubectl apply -k`)
resuelve esto sin plantillas. Una **base** contiene lo común y cada
**overlay** declara sólo sus diferencias: namespace, réplicas, parches y
config generada.

## Objetivos

1. `~/app/base/` con Deployment y Service, una sola vez y con readinessProbe.
2. `~/app/overlays/dev` y `~/app/overlays/prod` con sólo lo que cambia
   (namespace, réplicas, memoria, `LOG_LEVEL`, `index.html`, etiqueta `entorno`).
3. Config generada con `configMapGenerator`, con sufijo hash.
4. La imagen y el Service no se repiten en los overlays.
5. Sin las copias viejas, y los dos entornos aplicados con `apply -k`.

La tabla exacta de diferencias está en `~/TAREA.txt`.

## Pistas

```bash
kubectl kustomize ~/app/overlays/prod        # lo que se aplicaría
kubectl diff -k ~/app/overlays/prod
kubectl explain deployment.spec.selector     # ¿se puede cambiar?
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
