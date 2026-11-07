# Solución — Mantenimiento de nodos

| Carga | Bloqueo | Arreglo |
|-------|---------|---------|
| pagos | 2 réplicas, PDB `minAvailable: 2`: 0 desalojos permitidos | 3 réplicas (el PDB no cambia) + reparto entre nodos |
| catalogo | 1 réplica, PDB `minAvailable: 1`: 0 desalojos | 2 réplicas + reparto entre nodos |
| informe | `Pod` sin controlador: drain exige `--force`, que lo perdería | `Deployment` + borrar el pod suelto |

```yaml
spec:
  replicas: 3
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector: {matchLabels: {app: pagos}}
```

```bash
kubectl apply -f ~/manifiestos/
kubectl -n tienda delete pod informe
mantenimiento nodo2      # kubectl drain nodo2 --ignore-daemonsets
```

## Qué hace drain

1. `cordon`: el nodo deja de aceptar pods nuevos.
2. Por cada pod (salvo DaemonSets), pide una Eviction a la API.
3. La API la concede sólo si el PDB lo permite. Si no, drain reintenta cada 5 s.
4. El controlador (Deployment, StatefulSet...) crea el sustituto en otro nodo.

Un pod sin controlador no tiene sustituto. Por eso drain exige `--force`
para tocarlo.

## Relación con otros labs

- Lab 199 (actualizar Kubernetes): cada nodo se vacía así antes de actualizarse.
- Lab 195: un StatefulSet con PDB se desaloja pod a pod, y respetarlo es justo lo que protege el quórum.
