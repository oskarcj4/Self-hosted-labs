# Resolución guiada · Lab 132

:::piensa Antes de tocar nada
ARP traduce IP a MAC y cree a cualquiera que responda. Si otro equipo dice
"la puerta de enlace soy yo", tu tráfico va a él. La pista: la MAC de la
puerta de enlace cambia.
:::

## Paso 1 · ¿La MAC del gateway es estable?

:::pista Cómo comprobarlo
```bash
for i in 1 2 3 4 5; do ip neigh show 10.132.0.1; sleep 2; done
```
Si alterna entre dos MAC, alguien está suplantando.
:::

## Paso 2 · ¿Quién lo anuncia?

:::pista Cómo comprobarlo
```bash
IF=$(cat /opt/lab/.lan-if)
sudo tcpdump -i $IF -nn -e -c 6 arp
sudo arping -c 2 -I $IF 10.132.0.1     # responden dos MAC
sudo arping -c 1 -I $IF 10.132.0.66
```
ARP "gratuito" (`Reply` sin petición) repetido es la firma del ataque.
:::

## Paso 3 · Documenta

En `~/arp.txt`: `ip_suplantada=`, `mac_legitima=`, `mac_atacante=`, `ip_atacante=`.

**Pregúntate:** ¿cómo distingues la MAC legítima? Docker asigna MACs `02:42:` + la IP en hex: `0a:84:00:01` es `10.132.0.1`.

## Paso 4 · Entrada estática persistente

:::pista Cómo hacerlo
```bash
sudo ip neigh replace 10.132.0.1 lladdr 02:42:0a:84:00:01 dev $IF nud permanent
```
Para que sobreviva al reinicio, crea una unidad systemd `Type=oneshot` con ese `ExecStart` y habilítala.
:::

## Paso 5 · Vigilancia

:::pista Cómo hacerlo
```bash
sudo systemctl enable --now arpwatch@$IF
pgrep -af arpwatch
```
arpwatch registra en syslog cada `flip flop` (cambio de MAC de una IP).
:::

## Cómo actuar en una situación así

- **Dynamic ARP Inspection** en el switch es la defensa de red.
- Entradas estáticas sólo para lo crítico (gateway): no escalan.
- TLS en todo: aunque te hagan MITM, no pueden leer ni modificar el contenido.

## Si te atascas

- `ip neigh` muestra `STALE`/`REACHABLE` tras tu cambio: no pusiste `nud permanent`.
- `arpwatch@` no arranca: el nombre de la interfaz va tras la `@`.
