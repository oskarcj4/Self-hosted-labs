# Solución — RBAC con mínimo privilegio

| Identidad | Antes | Después |
|-----------|-------|---------|
| tienda/despliegue | ClusterRoleBinding → `cluster-admin` | `Role despliegue` en tienda: deployments, services y configmaps (get…patch); pods y pods/log (lectura); replicasets (lectura) |
| tienda/default | `Role app-todo`: `*` sobre `*` | sin bindings; `automountServiceAccountToken: false` en la SA y en el pod |
| observabilidad/monitor | `RoleBinding` a `view` sólo en su namespace | `ClusterRole monitor-lectura` (pods y nodes: get/list/watch) + `ClusterRoleBinding` |

```bash
# Lo que apply no borra
kubectl delete clusterrolebinding despliegue-admin
kubectl -n tienda delete rolebinding,role app-todo
kubectl -n observabilidad delete rolebinding monitor-view
kubectl apply -f ~/rbac/ -f ~/manifiestos/tienda.yaml
```

Los YAML completos están en `solve.sh`.

## Verificar

```bash
puede despliegue get secrets -n tienda                    # no
puede despliegue create rolebindings -n tienda            # no
puede despliegue patch deployments -n tienda              # yes
puede monitor list pods -A                                # yes
puede monitor get secrets -n pagos                        # no
kubectl --as=system:serviceaccount:tienda:despliegue -n tienda rollout restart deploy/tienda
```

## Trampas de RBAC

- Los permisos sólo se suman: no hay "deny". Para quitar un permiso, hay que quitar el binding que lo da.
- `list secrets` devuelve el contenido de todos los secrets, no sólo los nombres.
- `create pods` en un namespace da acceso a cualquier secret o ServiceAccount de ese namespace: basta montarlos en un pod nuevo.
- `escalate`, `bind` e `impersonate` son verbos peligrosos: revísalos en cualquier rol.
