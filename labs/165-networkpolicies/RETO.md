# NetworkPolicies

> Kubernetes · NetworkPolicy · negar por defecto · podSelector · namespaceSelector

## Escenario

En Kubernetes, sin políticas, **todo pod habla con todo pod**, de cualquier
namespace. La auditoría lo comprobó: desde `externo/atacante` se llega a
`tienda/db`.

Una **NetworkPolicy** selecciona pods (`podSelector`) y, en cuanto un pod está
seleccionado por alguna política de tipo `Ingress`, **sólo** acepta el tráfico
que alguna política permita explícitamente. Las políticas suman permisos; no
hay reglas de "denegar".

Flujos que deben existir:

| Origen | Destino |
|--------|---------|
| `tienda/frontend` | `tienda/api:8080` |
| `tienda/api` | `tienda/db:5432` |
| cualquier pod del namespace `monitoring` | `tienda/api:8080` |

Todo lo demás hacia `tienda`: bloqueado.

## Objetivos

1. `default-deny` en `tienda`: `podSelector: {}` y `policyTypes: [Ingress]`
   sin reglas.
2. Políticas que permitan sólo los tres flujos.
3. Guárdalas en `~/politicas/` y aplícalas.
4. `probar-red` sin ninguna línea `MAL`.

## Pistas

```bash
probar-red                                   # matriz de conectividad
kubectl -n tienda get pods --show-labels
kubectl get ns --show-labels                 # kubernetes.io/metadata.name=<ns>
kubectl explain networkpolicy.spec.ingress.from
kubectl -n tienda get networkpolicy
kubectl apply -f ~/politicas/
```

Esqueleto de una regla:
```yaml
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: api}}
    ports: [{port: 5432}]
```

Ojo: dentro de un mismo elemento de `from`, `namespaceSelector` y `podSelector`
juntos son **Y**; como elementos separados de la lista son **O**.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
