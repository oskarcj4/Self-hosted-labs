# Resolución guiada · Lab 165

:::piensa Lista blanca, no lista negra
Las NetworkPolicy no tienen "deny". Primero aíslas todo (default-deny) y luego
cada política **suma** un permiso concreto. Si un flujo no está escrito, no existe.
:::

## Paso 1 · Mide antes de tocar

:::pista Qué hacer
`probar-red`: hoy todo dice PERMITIDO, incluido `externo/atacante -> db`.
:::

## Paso 2 · Negar por defecto

:::pista Cómo hacerlo
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: tienda}
spec:
  podSelector: {}
  policyTypes: [Ingress]
```
Tras aplicarla, `probar-red`: todo BLOQUEADO (también lo que debía ir).
:::

## Paso 3 · Abrir lo necesario

:::pista Cómo hacerlo
- Política sobre `app: api`: `from` con dos elementos (**O**):
  `podSelector app=frontend` y `namespaceSelector kubernetes.io/metadata.name=monitoring`; puerto 8080.
- Política sobre `app: db`: `from podSelector app=api`; puerto 5432.
:::

## Cómo actuar en una situación así

- Empieza por ingress default-deny; egress default-deny es el siguiente paso
  (recuerda permitir DNS a kube-dns:53).
- Etiquetas estables (`app`, `kubernetes.io/metadata.name`) como base de las reglas.
- Prueba la matriz completa después de cada cambio.

## Si te atascas

- `monitoring` no llega: el namespaceSelector debe ir como elemento propio de
  `from`, no junto al podSelector de frontend (eso sería Y).
- Todo bloqueado tras tus políticas: revisa `ports` (es el puerto del pod).
