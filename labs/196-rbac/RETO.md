# RBAC con mínimo privilegio

> Kubernetes · RBAC · Role y ClusterRole · ServiceAccounts · `kubectl auth can-i`

## Escenario

Los permisos del clúster se pusieron "hasta que funcionara":

- **tienda/despliegue**, la cuenta del CI, es `cluster-admin`. Quien robe
  ese token puede leer la clave de la pasarela de pagos, borrar namespaces
  o darse cualquier permiso.
- **tienda/default**, la cuenta con la que corre la app, tiene `*` sobre
  todo su namespace, y su token está montado en cada pod. Un RCE en la web
  basta para leer todos los secrets.
- **observabilidad/monitor** sólo ve su propio namespace, así que el
  dashboard de pods está vacío.

RBAC suma permisos y nunca resta. Un `Role` da permisos dentro de un
namespace y un `ClusterRole` en todo el clúster (o sirve de plantilla para
un `RoleBinding`). El binding asocia el rol a una identidad.

## Objetivos

1. `despliegue`: sólo desplegar en `tienda` (la lista exacta está en `~/TAREA.txt`). Sin secrets ni otros namespaces, y sin poder escalar privilegios.
2. `default` de tienda: sin permisos, y el pod sin token montado.
3. `monitor`: leer pods de todos los namespaces y nodos. Nada más.
4. Todo en `~/rbac/` y `~/manifiestos/` y aplicado.

## Pistas

```bash
puede despliegue get secrets -n pagos           # envoltorio de kubectl auth can-i
kubectl auth can-i --list --as=system:serviceaccount:tienda:despliegue -n tienda
kubectl get clusterrolebindings -o wide | grep -v system:
kubectl -n tienda exec deploy/tienda -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
