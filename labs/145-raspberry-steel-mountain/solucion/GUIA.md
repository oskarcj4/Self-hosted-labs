# Resolución guiada · Lab 145

:::piensa Inventario primero
No puedes defender lo que no sabes que existe. Antes de bloquear nada, pinta el
mapa: qué responde en el segmento y con qué MAC. La diferencia con la CMDB es
la alerta.
:::

## Paso 1 · Barre el segmento

:::pista Cómo comprobarlo
```bash
inventario | tee ~/inventario.txt
```
Verás 4 equipos. La CMDB (`/etc/red/activos-aprobados.txt`) sólo aprueba 3.
:::

## Paso 2 · ¿Cuál sobra y de qué es?

**Pregúntate:** ¿qué dice el OUI (3 primeros octetos de la MAC) del equipo que no está en la CMDB?

:::pista Cómo comprobarlo
```bash
ip neigh show | grep 10.145.0.66     # b8:27:eb -> Raspberry Pi Foundation
```
```bash
cat > ~/hallazgos.txt <<'H'
rogue_ip=10.145.0.66
rogue_mac=b8:27:eb:59:05:09
H
```
:::

## Paso 3 · Aísla con nftables

:::pista Cómo hacerlo
```bash
sudo nft add rule inet filter input  ip saddr 10.145.0.66 drop
sudo nft add rule inet filter output ip daddr 10.145.0.66 drop
ping -c1 -W2 10.145.0.66            # ya no responde
```
:::

## Paso 4 · Hazlo persistente

:::pista Cómo hacerlo
Añade las dos reglas dentro de la tabla `inet filter` en `/etc/nftables.conf`
y `sudo systemctl restart nftables`. Comprueba con `sudo nft list ruleset`.
:::

## Cómo actuar en una situación así

- OT y IT no comparten segmento: VLAN dedicada, 802.1X y cortafuegos industrial.
- Un dispositivo no inventariado en OT es un incidente, aunque "no haga nada":
  ya es un punto de entrada.

## Si te atascas

- `ping` sigue respondiendo: ¿bloqueaste `output` (daddr) *y* dejaste la cache
  ARP vieja? El drop en output basta para que el ping falle.
- Tras `restart nftables` desaparecen las reglas: no las guardaste en
  `/etc/nftables.conf`, sólo en caliente.
