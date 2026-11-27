# Resolución guiada · Lab 145

:::piensa Inventario primero
No puedes defender lo que no sabes que existe. Antes de bloquear nada, pinta
el mapa: qué responde en el segmento y con qué MAC. La diferencia entre ese
mapa y la lista de equipos aprobados (la CMDB) es la alerta.
:::

**El plan:** (1) barrer el segmento, (2) identificar el intruso, (3) aislarlo
y (4) hacer el bloqueo persistente.

## Paso 1 · Barre el segmento

:::pista Cómo hacerlo
```bash
inventario | tee ~/inventario.txt
cat /etc/red/activos-aprobados.txt
```
`inventario` es una herramienta del lab que hace un barrido ARP: pregunta
"¿quién tiene esta IP?" a cada dirección del segmento y apunta quién
responde y con qué MAC. `tee` guarda la salida y la enseña a la vez.

**Qué deberías ver:** cuatro equipos; la CMDB sólo aprueba tres.
:::

## Paso 2 · ¿Cuál sobra, y qué es?

**Pregúntate:** ¿qué te dice la MAC del equipo que no está aprobado?

:::pista Cómo hacerlo
```bash
ip neigh show | grep 10.145.0.
```
`ip neigh` es la tabla ARP del sistema: qué MAC corresponde a cada IP vecina.
Los tres primeros bytes de una MAC son el **OUI**, el identificador del
fabricante.

**Qué deberías ver:** `10.145.0.66` con una MAC que empieza por `b8:27:eb`:
el OUI de la Raspberry Pi Foundation. Nada que hacer en una red industrial.
```bash
cat > ~/hallazgos.txt <<'H'
rogue_ip=10.145.0.66
rogue_mac=b8:27:eb:59:05:09
H
```
(Copia la MAC exacta de tu `ip neigh`.)
:::

## Paso 3 · Aíslalo ya

:::pista Cómo hacerlo
```bash
sudo nft list ruleset
sudo nft add rule inet filter input  ip saddr 10.145.0.66 drop
sudo nft add rule inet filter output ip daddr 10.145.0.66 drop
ping -c1 -W2 10.145.0.66
```
- `nft list ruleset` enseña las reglas actuales: una tabla `inet filter` con
  tres cadenas que aceptan todo.
- `nft add rule <familia> <tabla> <cadena> <condición> <acción>` añade una
  regla al final de la cadena. `input` filtra lo que llega a esta máquina;
  `output`, lo que sale de ella. `ip saddr` es la IP de origen; `ip daddr`, la
  de destino.

**Qué deberías ver:** el `ping` falla (`100% packet loss`). Pero estas reglas
viven en memoria: al reiniciar `nftables` se pierden.
:::

## Paso 4 · Que sea permanente

:::pista Cómo hacerlo
`nftables.service` carga `/etc/nftables.conf` al arrancar. Añade las dos
reglas dentro de sus cadenas:
```bash
sudo nano /etc/nftables.conf
```
```
table inet filter {
	chain input   { type filter hook input   priority 0; policy accept; ip saddr 10.145.0.66 drop; }
	chain forward { type filter hook forward priority 0; policy accept; }
	chain output  { type filter hook output  priority 0; policy accept; ip daddr 10.145.0.66 drop; }
}
```
```bash
sudo nft -c -f /etc/nftables.conf
sudo systemctl restart nftables
sudo nft list ruleset | grep 10.145.0.66
bash /opt/lab/check.sh
```
`nft -c -f` comprueba el fichero sin aplicarlo. Tras el `restart`, las reglas
siguen ahí porque ahora salen del fichero.
:::

## Cómo actuar en una situación así

- En OT, IT y OT no comparten segmento: VLAN dedicada, 802.1X en los puertos
  del switch y cortafuegos industrial.
- Un bloqueo por IP se evade cambiando de IP; el aislamiento real se hace por
  puerto del switch.
- Un dispositivo no inventariado en OT es un incidente aunque "no haga nada":
  ya es un punto de entrada. Busca quién lo conectó y cuándo.

## Si te atascas

- **El `ping` sigue respondiendo:** falta la regla de `output` (la de `input`
  sólo filtra lo que llega).
- **Tras `restart nftables` desaparecen las reglas:** no las guardaste en
  `/etc/nftables.conf`.
- **`nft -c` da error:** cada regla dentro de las llaves termina en `;`.
