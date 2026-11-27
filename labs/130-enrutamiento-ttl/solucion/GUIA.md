# Resolución guiada · Lab 130

:::piensa Dos cosas para ser un router
Un equipo Linux hace de router si cumple dos condiciones: **reenvía**
paquetes que no son para él (por defecto no lo hace: `ip_forward = 0`) y
**sabe por dónde** mandar cada red de destino (la tabla de rutas). Aquí
fallan las dos. Y lo que arregles tiene que sobrevivir a un reinicio.
:::

```
pc-oficina ──► router-130 (tú) ──► r2-dmz ──► srv-dmz
10.130.1.20    .1.254 | .2.254     .2.253 | .3.253   10.130.3.30
```

**El plan:** (1) ver qué redes conoces, (2) activar el reenvío, (3) añadir la
ruta que falta y (4) leer el TTL.

## Paso 1 · ¿Qué redes conoces?

:::pista Cómo hacerlo
```bash
ip -br addr
ip route
ip route get 10.130.3.30
sysctl net.ipv4.ip_forward
```
- `ip -br addr` lista las interfaces y sus IP en formato breve (`-br`).
- `ip route` es la tabla de rutas: para cada red, por qué interfaz o por qué
  router se llega.
- `ip route get <IP>` dice qué ruta usaría el sistema para ese destino.

**Qué deberías ver:** estás en `10.130.1.0/24` (la de los PC) y en
`10.130.2.0/24` (la que te une a `r2-dmz`). No hay ruta hacia
`10.130.3.0/24`, la red del servidor, que está detrás de `10.130.2.253`. Y
`ip_forward = 0`.
:::

## Paso 2 · Activa el reenvío, persistente

**Pregúntate:** `sysctl -w` se pierde al reiniciar. ¿Qué fichero lo está
fijando a 0?

:::pista Cómo hacerlo
```bash
grep -r ip_forward /etc/sysctl.conf /etc/sysctl.d/
sudo sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.d/90-router.conf
sudo sysctl --system
sysctl net.ipv4.ip_forward
```
- `/etc/sysctl.d/*.conf` se aplican al arrancar; `sysctl --system` los vuelve a
  aplicar todos ahora.
- Cambiarlo con `sysctl -w` funcionaría hasta el próximo reinicio, y el
  fichero lo volvería a poner a 0.

**Qué deberías ver:** `net.ipv4.ip_forward = 1`.
:::

## Paso 3 · La ruta que falta, persistente

:::pista Cómo hacerlo
```bash
systemctl cat rutas-router.service
sudo nano /etc/systemd/system/rutas-router.service
```
Sustituye la línea `ExecStart=/bin/true` por:
```ini
ExecStart=-/sbin/ip route add 10.130.3.0/24 via 10.130.2.253
```
- `ip route add <red> via <router>`: "para llegar a esta red, envía al
  router `10.130.2.253`".
- El `-` delante del comando: si falla (por ejemplo, `File exists` porque la
  ruta ya está), la unidad no se marca como fallida.

```bash
sudo systemctl daemon-reload
sudo systemctl restart rutas-router.service
ip route get 10.130.3.30
```
**Qué deberías ver:** `10.130.3.30 via 10.130.2.253 dev …`.
:::

## Paso 4 · TTL y saltos

**Pregúntate:** Linux envía los paquetes con TTL 64 y cada router resta 1.
Si la respuesta llega con 63, ¿cuántos routers cruzó?

:::pista Cómo hacerlo
```bash
ping -c 1 10.130.3.30
traceroute -n 10.130.3.30
cat /srv/estado/pc.txt
```
- En la salida de `ping`, `ttl=` es el TTL con el que **llegó** la respuesta.
- `traceroute` envía paquetes con TTL 1, 2, 3…; cada router que lo deja a 0
  responde, y así se descubre el camino (`-n`: sin resolver nombres).

**Qué deberías ver:** `ttl=63` (64 menos `r2-dmz`), dos saltos en
`traceroute` y `/srv/estado/pc.txt` diciendo que el PC ya llega. Entre el PC y
el servidor hay **dos** routers: tú y `r2-dmz`.
```bash
printf 'ttl_respuesta=63\nsaltos_pc=2\n' > ~/ttl.txt
bash /opt/lab/check.sh
```
(Usa el TTL que te haya dado `ping`.)
:::

## Cómo actuar en una situación así

- Comprueba ida **y** vuelta: si falta la ruta de regreso en el otro router,
  la conexión falla igual.
- Todo cambio de red, persistente: `sysctl.d`, netplan/systemd-networkd o una
  unidad.
- TTL inicial típico: 64 en Linux, 128 en Windows, 255 en equipos de red. El
  TTL de una respuesta te da una pista del sistema y la distancia.

## Si te atascas

- **`RTNETLINK answers: File exists`:** la ruta ya está. No es un error.
- **El PC sigue sin llegar:** comprueba `sysctl net.ipv4.ip_forward`; y con
  `sudo tcpdump -ni any icmp` mira si los paquetes del PC entran y no salen.
