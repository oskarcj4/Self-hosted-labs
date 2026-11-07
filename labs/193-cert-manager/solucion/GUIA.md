# Resolución guiada · Lab 193

:::piensa Sigue la cadena
Certificate → CertificateRequest → emisor → Secret → volumen del pod →
nginx → cliente que verifica con la CA. Cada eslabón tiene su `describe`
con eventos. Empieza por el primero que esté mal.
:::

## Paso 1 · El emisor

:::pista Qué pasa
La CertificateRequest dice que no encuentra el `Issuer` `ca-tienda`. Existe,
pero en el namespace `cert-manager`: un `Issuer` sólo firma certificados de
**su** namespace. Conviértelo en `ClusterIssuer`, que lee su secret
(`ca-tienda`) del namespace de cert-manager, y cambia el `issuerRef` a
`kind: ClusterIssuer`.
:::

## Paso 2 · Los nombres

:::pista Qué pasa
`dnsNames: [www.tienda.local]` no cubre `tienda.local` ni el nombre interno
del Service. El cliente comprueba que el nombre al que conecta está en el
certificado: añade los dos.
:::

## Paso 3 · El Secret

:::pista Qué pasa
El pod monta `tienda-tls`, pero el `Certificate` guarda el resultado en
`web-tls`. Mientras el Secret no exista, el pod se queda en
`ContainerCreating`.
:::

## Paso 4 · Renovación

:::pista Qué probar
`kubectl -n tienda delete secret web-tls`: en segundos vuelve, con otro
número de serie (`openssl x509 -noout -serial`). nginx carga el certificado
al arrancar: tras una renovación hay que recargarlo (`rollout restart`, o
una herramienta como Reloader).
:::

## Cómo actuar en una situación así

- Alerta con `certmanager_certificate_expiration_timestamp_seconds` y con los Certificates que no están Ready.
- Para la web pública, un `ClusterIssuer` ACME (Let's Encrypt). Para tráfico interno, una CA propia como esta.
- Distribuye la CA a los clientes (trust-manager) en lugar de desactivar la verificación.
