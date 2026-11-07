# Resolución guiada · Lab 192

:::piensa Divide el camino en tramos
cliente → DNS del Service → IP del Service → EndpointSlice → IP del pod y
puerto → proceso escuchando. Prueba cada tramo por separado: si llegas al
pod directamente por su IP y no por el Service, el problema está en el
Service (selector, targetPort o readiness), no en la app.
:::

## Paso 1 · ¿Tiene endpoints?

:::pista Qué mirar
`kubectl -n tienda get endpointslices`. Sin direcciones: el selector no
encaja o ningún pod está Ready. Con direcciones pero sin respuesta: el
puerto está mal.
:::

## Paso 2 · catalogo

:::pista Qué pasa
El Service pide `app: catalog` y los pods llevan `app: catalogo`. Todas las
etiquetas del selector tienen que estar en el pod.
:::

## Paso 3 · pagos

:::pista Qué pasa
Hay endpoints, pero `targetPort: 80` y el contenedor escucha en 8080:
connection refused. `targetPort` es el puerto **del pod**; `port`, el del Service.
:::

## Paso 4 · carrito

:::pista Qué pasa
Los pods están `Running` pero `0/1` Ready: la probe pide `/healthz`, que da
404. La app sirve `/salud`. Un pod que no está Ready no recibe tráfico.
Es lo que se busca: el problema es la ruta, no la probe.
:::

## Paso 5 · usuarios

:::pista Qué pasa
`targetPort: http` es un **nombre** de puerto, y el contenedor llama `web`
a su puerto. Cambia uno de los dos para que coincidan.
:::

## Cómo actuar en una situación así

- `kubectl get endpointslices` es lo primero que se mira cuando un Service "no va".
- Usa etiquetas y nombres de puerto consistentes desde una plantilla (Helm, Kustomize): son errores de copiar y pegar.
- Un linter en CI (kubeconform, kube-linter) detecta selectores sin pods y puertos con nombre inexistentes.
