# Mantenimiento de nodos

> Kubernetes · `kubectl drain` · PodDisruptionBudget · réplicas y reparto entre nodos

## Escenario

El clúster tiene dos nodos (`nodo1` en este contenedor y `nodo2` en otro).
Hay que parchear `nodo2`, y el procedimiento estándar es vaciarlo primero
con `kubectl drain`, sin `--force`:

```bash
mantenimiento nodo2
  evicting pod tienda/pagos-...
  error when evicting pods/"pagos-..." (will retry after 5s): Cannot evict pod
  as it would violate the pod's disruption budget.
  ...
  cannot delete Pods that declare no controller (use --force to override): tienda/informe
```

`drain` no borra pods: pide **desalojos** (evictions), y la API los rechaza
si violan un **PodDisruptionBudget**. Un PDB que no permite ningún desalojo
bloquea el mantenimiento para siempre. Y un pod sin controlador no se
recrea en ningún sitio: `--force` lo haría desaparecer.

## Objetivos

1. `kubectl drain nodo2 --ignore-daemonsets` termina sin `--force`.
2. Durante el drain, `pagos` nunca baja de 2 pods disponibles ni `catalogo` de 1.
3. Los PDB siguen existiendo y no se relajan.
4. `informe` sigue corriendo después del mantenimiento.
5. Cambios en `~/manifiestos/` y aplicados.

## Pistas

```bash
kubectl get pdb -n tienda              # columna ALLOWED DISRUPTIONS
kubectl get pods -n tienda -o wide     # ¿en qué nodo está cada pod?
kubectl explain pod.spec.topologySpreadConstraints
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh      # hace un drain real de nodo2 (1-2 min)
```
