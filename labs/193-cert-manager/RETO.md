# cert-manager

> Kubernetes · TLS · cert-manager · Issuer y ClusterIssuer · CA interna · renovación automática

## Escenario

Se acabó renovar certificados a mano un viernes por la tarde: el clúster
tiene **cert-manager** y una **CA interna** (`~/manifiestos/01-ca.yaml`).
La tienda debería servir HTTPS con un certificado firmado por esa CA y
renovado automáticamente. Pero:

```bash
kubectl -n tienda get certificate,certificaterequest,pods
probar-tls tienda.local        # curl --cacert <CA interna> https://tienda.local/
```

El certificado no se emite y el pod no arranca. Hay tres fallos.

Cómo funciona cert-manager: un `Certificate` describe el certificado que
quieres. cert-manager crea una `CertificateRequest`, el **emisor**
(`Issuer`, de un namespace, o `ClusterIssuer`, de todo el clúster) la
firma, y el resultado queda en un `Secret` (`tls.crt` y `tls.key`). El pod
monta ese Secret.

## Objetivos

1. `Certificate` `tienda/web` en Ready, firmado por la CA interna.
2. Válido para `tienda.local` y `tienda.tienda.svc.cluster.local`.
3. La tienda sirve HTTPS verificable con la CA en los dos nombres.
4. Si el Secret desaparece, cert-manager lo vuelve a emitir.
5. Todo en `~/manifiestos/` y aplicado.

## Pistas

```bash
kubectl -n tienda describe certificate web
kubectl -n tienda describe certificaterequest
kubectl get issuer -A; kubectl get clusterissuer
kubectl -n tienda describe pod -l app=tienda        # eventos: MountVolume ... not found
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
