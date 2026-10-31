# Resolución guiada · Lab 130

:::piensa Antes de tocar nada
Un router hace dos cosas: deja pasar paquetes de una interfaz a otra
(`ip_forward`) y sabe a dónde mandar cada destino (tabla de rutas). Aquí fallan
las dos. Y lo que arregles tiene que sobrevivir a un reinicio.
:::

## Paso 1 · ¿Qué redes conoces?

:::pista Cómo comprobarlo
```bash
ip -br addr
ip route
sysctl net.ipv4.ip_forward
```
Conoces `10.130.1.0/24` y `10.130.2.0/24`. El PC está en `10.130.3.0/24`, detrás de `10.130.2.253`.
:::

## Paso 2 · Activa el reenvío (persistente)

**Pregúntate:** `sysctl -w` se pierde al reiniciar. ¿Qué fichero lo fija ahora a 0?

:::pista Cómo hacerlo
```bash
grep -r ip_forward /etc/sysctl.conf /etc/sysctl.d/
sudo sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.d/90-router.conf
sudo sysctl --system
```
:::

## Paso 3 · La ruta que falta (persistente)

:::pista Cómo hacerlo
```bash
systemctl cat rutas-router.service
sudo nano /etc/systemd/system/rutas-router.service
#   ExecStart=-/sbin/ip route add 10.130.3.0/24 via 10.130.2.253
sudo systemctl daemon-reload && sudo systemctl restart rutas-router.service
ip route
```
:::

## Paso 4 · TTL y saltos

**Pregúntate:** Linux envía con TTL 64 y cada router resta 1. Si la respuesta llega con 63, ¿cuántos routers cruzó?

:::pista Cómo comprobarlo
```bash
ping -c 1 10.130.3.30
traceroute -n 10.130.3.30
cat /srv/estado/pc.txt
```
Escribe `ttl_respuesta=` y `saltos_pc=` (routers entre el PC y la red 1) en `~/ttl.txt`.
:::

## Cómo actuar en una situación así

- **Comprueba ida y vuelta**: una ruta que falta en un sentido rompe la conexión igual.
- **Todo cambio de red, persistente**: sysctl.d, netplan/systemd-networkd o una unidad.
- TTL inicial típico: 64 (Linux), 128 (Windows), 255 (equipos de red).

## Si te atascas

- La ruta da `File exists`: ya está; el `-` en `ExecStart=-` hace que no falle la unidad.
- El PC sigue sin llegar: ¿`ip_forward` es 1 de verdad? `sysctl net.ipv4.ip_forward`.
