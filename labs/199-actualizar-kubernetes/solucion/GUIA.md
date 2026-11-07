# Resolución guiada · Lab 199

:::piensa El orden importa
Primero lo que se puede hacer sin riesgo (migrar manifiestos, que también
funcionan en v1.31). Después la red de seguridad (backup). Por último lo
irreversible (cambiar el binario). Si inviertes el orden, el primer error
te pilla sin backup o con el clúster ya actualizado.
:::

## Paso 1 · APIs eliminadas

:::pista Qué buscar
La métrica `apiserver_requested_deprecated_apis` lista qué APIs deprecadas
se han usado y en qué versión desaparecen (`removed_release="1.32"`). Aquí
es `flowcontrol.apiserver.k8s.io/v1beta3`: FlowSchema y
PriorityLevelConfiguration. `v1` tiene el mismo esquema, así que basta con
cambiar `apiVersion`. Aplica ya, en v1.31, y comprueba que no hay errores.
:::

## Paso 2 · Copia de seguridad

:::pista Por qué no `cp`
`state.db` es un SQLite en uso, con WAL: un `cp` puede copiar una base de
datos a medio escribir. Usa la API de backup de SQLite
(`sqlite3.Connection.backup` en Python, o `.backup` en el cliente sqlite3)
o para k3s antes. Guarda también `/var/lib/rancher/k3s/server/token`: sin
él, la copia no se puede restaurar.
:::

## Paso 3 · Binario

:::pista Cómo
En `/opt/k3s/v1.32.0`: `grep ' k3s$' sha256sum-amd64.txt | sha256sum -c -`.
Después `sudo install -m 0755 k3s /usr/local/bin/k3s` y
`sudo systemctl restart k3s`. Los contenedores siguen corriendo durante el
reinicio del plano de control: el servicio tiene `KillMode=process`.
:::

## Paso 4 · Verificar

:::pista Qué mirar
`kubectl get nodes` (VERSION), `kubectl version`, la tienda y
`kubectl diff -f ~/manifiestos/`: si algo sigue usando una API eliminada,
aquí da "no matches for kind".
:::

## Cómo actuar en una situación así

- En CI, pasa `pluto` o `kubent` sobre manifiestos y charts renderizados para detectar APIs deprecadas antes de que llegue la actualización.
- Una versión menor cada vez (1.31→1.32→1.33): Kubernetes no soporta saltarse versiones del plano de control.
- Con varios nodos: primero el plano de control y después cada nodo con drain, actualización y uncordon (lab 197). El system-upgrade-controller de k3s lo automatiza.
