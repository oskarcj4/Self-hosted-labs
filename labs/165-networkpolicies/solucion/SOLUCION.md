# Solución — NetworkPolicies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: tienda}
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: api-desde-frontend-y-monitoring, namespace: tienda}
spec:
  podSelector: {matchLabels: {app: api}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: frontend}}
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: monitoring}}
    ports: [{port: 8080}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: db-desde-api, namespace: tienda}
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: api}}
    ports: [{port: 5432}]
```

## Por qué

- Un pod sin políticas que lo seleccionen acepta todo. En cuanto una política
  `Ingress` lo selecciona, sólo entra lo permitido por la unión de políticas.
- `podSelector` dentro de `from` sin `namespaceSelector` = pods del **mismo**
  namespace que la política. Por eso `externo/atacante` (app distinta, otro
  namespace) queda fuera.
- `kubernetes.io/metadata.name` lo pone Kubernetes en todo namespace: no hace
  falta etiquetar a mano.

## Más allá del lab

- Egress default-deny con excepción para DNS y los servicios que la app usa.
- Cilium/Calico añaden políticas L7 (HTTP) y por FQDN.
- Con Hubble (Cilium) ves qué flujos se bloquean en tiempo real.
