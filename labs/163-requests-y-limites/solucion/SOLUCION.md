# Solución — Requests y límites

## Foto inicial

| Pod | resources | QoS | Consecuencia |
|-----|-----------|-----|--------------|
| api | ninguno | BestEffort | primera en ser desalojada con presión de memoria |
| calc | cpu 20m/20m, mem 32Mi/32Mi | Guaranteed | estrangulada: 2 % de un núcleo, cada trabajo ~20x más lento |
| scraper | ninguno | BestEffort | prescindible; puede quedarse así |

`~/qos.txt`:
```
api=BestEffort
calc=Guaranteed
scraper=BestEffort
estrangulado=calc
```

## Arreglos

```bash
kubectl -n catalogo set resources deploy api --requests=cpu=100m,memory=64Mi --limits=cpu=100m,memory=64Mi
kubectl -n catalogo patch deploy calc --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources","value":{"requests":{"cpu":"200m","memory":"16Mi"},"limits":{"memory":"32Mi"}}}]'
```

```yaml
apiVersion: v1
kind: LimitRange
metadata: {name: defaults, namespace: catalogo}
spec:
  limits:
  - type: Container
    defaultRequest: {cpu: 50m, memory: 32Mi}
    default:        {cpu: 500m, memory: 128Mi}
```

## Por qué

- **CPU es comprimible**: al pasar el límite el kernel no mata, pausa el
  contenedor hasta el siguiente periodo CFS (100 ms). Con 20m sólo corre 2 ms de
  cada 100 ms. `cpu.stat` lo delata (`nr_throttled`, `throttled_usec`).
- **Memoria no es comprimible**: pasar el límite = OOMKilled. Con presión en el
  nodo, kubelet desaloja por orden: BestEffort → Burstable que exceden su
  request → Guaranteed.
- **LimitRange** rellena requests/limits a los contenedores que no los declaran:
  evita BestEffort por olvido y hace que las ResourceQuota funcionen.

## Más allá del lab

- ResourceQuota por namespace para que un equipo no se coma el clúster.
- VPA en modo recomendación para ajustar requests con datos reales.
