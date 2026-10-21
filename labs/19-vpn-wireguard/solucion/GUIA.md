# Resolución guiada · Lab 19

:::piensa Antes de tocar nada
WireGuard funciona con pares de claves, como SSH: cada lado tiene una **privada** (nunca sale de la máquina) y le da su **pública** al otro. Para montar el túnel cada lado necesita tres cosas del otro: su clave pública, dónde encontrarlo (endpoint) y qué IPs le pertenecen (`AllowedIPs`).
:::

## Paso 1 · Tu par de claves

**Pregúntate:** ¿quién debe poder leer la clave privada? Sólo root. Créala ya con permisos cerrados.

:::pista Cómo hacerlo
```bash
umask 077
wg genkey | sudo tee /etc/wireguard/lab.key | wg pubkey | sudo tee /etc/wireguard/lab.pub
```
`umask 077` hace que los ficheros nuevos nazcan sin permisos para grupo ni otros.
:::

## Paso 2 · Intercambio de públicas

**Pregúntate:** ¿qué le doy al otro lado y qué cojo de él? Le das tu **pública**; coges la **suya**. Nunca intercambies privadas.

:::pista Cómo hacerlo
```bash
sudo cp /etc/wireguard/lab.pub /shared/lab.pub
cat /shared/peer.pub
```
:::

## Paso 3 · Crea la interfaz

**Pregúntate:** una interfaz WireGuard es como una tarjeta de red virtual. ¿Qué necesita? Existir, una IP, una clave privada y un peer.

:::pista Cómo hacerlo
```bash
sudo ip link add wg0 type wireguard
sudo ip addr add 10.8.0.1/24 dev wg0
sudo wg set wg0 private-key /etc/wireguard/lab.key \
     peer "$(cat /shared/peer.pub)" endpoint peer:51820 \
     allowed-ips 10.8.0.2/32 persistent-keepalive 15
sudo ip link set wg0 up
```
`allowed-ips 10.8.0.2/32` significa: "el tráfico hacia 10.8.0.2 va por este peer, y sólo acepto de él paquetes con origen 10.8.0.2".
:::

## Paso 4 · Comprueba el handshake

**Pregúntate:** ¿cómo sé que los dos lados se han reconocido? WireGuard muestra el último handshake.

```bash
ping -c 3 10.8.0.2
sudo wg show wg0
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **La privada nunca se copia**: si sale de la máquina, regenera el par.
- **Diagnóstico por capas**: ¿existe la interfaz? (`ip a`) → ¿tiene peer? (`wg show`) → ¿hay handshake? → ¿hay ruta? (`ip route`).
- **Sin handshake** suele ser: clave pública equivocada, endpoint inalcanzable o puerto UDP bloqueado.
- En producción: usa `wg-quick` con un `/etc/wireguard/wg0.conf` en `0600` y un servicio `wg-quick@wg0`.

## Si te atascas

- `ip link add` falla: el kernel del host no tiene el módulo WireGuard (lo indica el enunciado).
- Hay ping pero el validador falla: comprueba que `/shared/lab.pub` contiene tu pública.
