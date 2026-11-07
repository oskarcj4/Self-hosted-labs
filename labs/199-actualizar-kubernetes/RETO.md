# Actualizar la versión de Kubernetes

> Kubernetes · APIs deprecadas y eliminadas · backup del estado · actualización de k3s

## Escenario

Kubernetes publica una versión menor cada ~4 meses y cada una tiene unos
14 meses de soporte. Quedarse atrás no es una opción. Este clúster (k3s
v1.31.4) tiene que pasar a **v1.32.0**. El binario ya está en
`/opt/k3s/v1.32.0/`, junto con su lista de sumas sha256.

Lo que rompe una actualización casi nunca es el binario: son las **APIs
eliminadas**. Un manifiesto o un chart de Helm que usa una versión beta
retirada deja de aplicarse en cuanto el API server nuevo arranca, a menudo
semanas después, en el siguiente despliegue.

## Objetivos

1. `~/manifiestos/` sin APIs eliminadas en v1.32.
2. Copia de seguridad consistente del estado del clúster en `/var/backups/k3s/`, **antes** de actualizar.
3. Binario verificado por sha256 e instalado. El nodo y el API server en `v1.32.0+k3s1`.
4. La tienda sigue sirviendo y los manifiestos se aplican contra v1.32.

El procedimiento detallado está en `~/TAREA.txt`.

## Pistas

```bash
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
kubectl api-resources | grep flowcontrol
sha256sum -c --ignore-missing sha256sum-amd64.txt
python3 -c 'import sqlite3; help(sqlite3.Connection.backup)'
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
