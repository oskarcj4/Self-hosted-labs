# Requests y límites

> Kubernetes · requests · limits · QoS · CFS throttling · LimitRange

## Escenario

Namespace `catalogo`, dos quejas:

- *"calc va lentísimo aunque el nodo está ocioso"*.
- *"Anoche, con el nodo corto de memoria, se cayó la api y el scraper siguió vivo"*.

Dos conceptos:

- **requests** = lo que el scheduler reserva. **limits** = el techo. En CPU,
  pasar el límite no mata: el kernel **estrangula** el contenedor (CFS
  throttling) aunque haya núcleos libres. En memoria, pasar el límite = OOMKilled.
- **Clase QoS** (la calcula Kubernetes a partir de los resources):
  - `Guaranteed`: requests = limits en cpu y memoria en todos los contenedores.
  - `Burstable`: tiene algún request o límite, sin ser Guaranteed.
  - `BestEffort`: nada. Es **lo primero que se desaloja** si el nodo se queda
    sin memoria.

Manifiestos en `~/manifiestos/catalogo.yaml`.

## Objetivos

1. `~/qos.txt` con la clase QoS actual de `api`, `calc` y `scraper`, y
   `estrangulado=<pod>`.
2. `api` crítica: QoS **Guaranteed**.
3. `calc`: sin estrangulamiento (límite de CPU >= 500m o sin límite de CPU) y
   con request de CPU >= 100m.
4. LimitRange `defaults` en `catalogo` con `default` y `defaultRequest` de cpu
   y memoria.

## Pistas

```bash
kubectl -n catalogo get pods -o custom-columns=POD:.metadata.name,QOS:.status.qosClass
kubectl -n catalogo logs deploy/calc --tail=5
kubectl -n catalogo exec deploy/calc -- cat /sys/fs/cgroup/cpu.stat   # nr_throttled, throttled_usec
kubectl top pod -n catalogo
kubectl -n catalogo set resources deploy api --requests=cpu=100m,memory=64Mi --limits=cpu=100m,memory=64Mi
kubectl explain limitrange.spec.limits
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
