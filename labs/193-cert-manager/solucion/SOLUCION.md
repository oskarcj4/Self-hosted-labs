# Solución — cert-manager

| Fallo | Síntoma | Arreglo |
|-------|---------|---------|
| `Issuer ca-tienda` en el namespace cert-manager | CertificateRequest: issuer not found | `ClusterIssuer ca-tienda` + `issuerRef.kind: ClusterIssuer` |
| `dnsNames: [www.tienda.local]` | curl: certificate subject name does not match | `tienda.local`, `tienda.tienda.svc.cluster.local` |
| el pod monta `tienda-tls` | pod en ContainerCreating | `secretName: web-tls` |

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: ca-tienda}
spec:
  ca: {secretName: ca-tienda}        # en el namespace de cert-manager
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: web, namespace: tienda}
spec:
  secretName: web-tls
  dnsNames: [tienda.local, www.tienda.local, tienda.tienda.svc.cluster.local]
  duration: 2160h       # 90 días
  renewBefore: 360h     # renueva 15 días antes
  privateKey: {algorithm: ECDSA, size: 256, rotationPolicy: Always}
  issuerRef: {name: ca-tienda, kind: ClusterIssuer, group: cert-manager.io}
```

## La CA interna

```
ClusterIssuer raiz-autofirmada (selfSigned)
   └─ Certificate ca-tienda (isCA) → Secret cert-manager/ca-tienda
        └─ ClusterIssuer ca-tienda (ca) → firma → Secret tienda/web-tls
```

## Más allá del lab

- Ingress con `cert-manager.io/cluster-issuer: ...`: cert-manager crea el Certificate solo.
- `rotationPolicy: Always`: clave nueva en cada renovación. Una clave filtrada caduca con el certificado.
- La raíz autofirmada en el clúster vale para el lab. En producción, la raíz va offline o en un KMS/Vault (lab 175).
