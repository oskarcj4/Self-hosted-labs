# Resolución guiada · Lab 132

:::piensa ARP se cree a cualquiera
Dentro de una red local, los equipos se encuentran por **MAC**, no por IP.
ARP es el protocolo que traduce "¿quién tiene la IP 10.132.0.1?" a una MAC, y
no tiene autenticación: si otro equipo anuncia "10.132.0.1 soy yo", los demás
le creen y le mandan el tráfico. Así se pone en medio (*man-in-the-middle*).
La pista: la MAC de la puerta de enlace cambia.
:::

**El plan:** (1) ver si la MAC del gateway es estable, (2) ver quién la
anuncia, (3) documentar, (4) fijar la MAC buena y (5) dejar vigilancia.

## Paso 1 · ¿La MAC del gateway es estable?

:::pista Cómo hacerlo
```bash
cat ~/ticket/NET-132.txt
IF=$(cat /opt/lab/.lan-if); echo "$IF"
for i in 1 2 3 4 5; do ip neigh show 10.132.0.1; sleep 2; done
```
`ip neigh` es la caché ARP del sistema: qué MAC tiene apuntada para cada IP
vecina.

**Qué deberías ver:** la MAC de `10.132.0.1` alternando entre dos valores.
:::

## Paso 2 · ¿Quién la anuncia?

:::pista Cómo hacerlo
```bash
sudo tcpdump -i $IF -nn -e -c 6 arp
sudo arping -c 2 -I $IF 10.132.0.1
```
- `tcpdump … arp` captura sólo paquetes ARP; `-e` enseña las MAC de origen y
  destino; `-c 6` para tras 6 paquetes.
- `arping` hace una pregunta ARP a mano: si contestan dos MAC distintas para
  la misma IP, una miente.

**Qué deberías ver:** respuestas ARP (`Reply`) que nadie ha pedido, repetidas
desde una MAC `…:00:66`: es la firma del ataque. Para saber qué IP propia
tiene el atacante:
```bash
ip neigh show | grep -i 00:66
```
:::

## Paso 3 · Documenta

**Pregúntate:** de las dos MAC, ¿cuál es la legítima?

:::pista Cómo hacerlo
En este lab, Docker asigna las MAC como `02:42:` + la IP en hexadecimal:
`10.132.0.1` → `0a:84:00:01`. La legítima es `02:42:0a:84:00:01`; la otra no
corresponde a esa IP.
```bash
cat > ~/arp.txt <<'T'
ip_suplantada=10.132.0.1
mac_legitima=02:42:0a:84:00:01
mac_atacante=<la otra MAC>
ip_atacante=<la IP del atacante>
T
```
En una red real, la MAC legítima se saca del propio router o del inventario,
nunca de la caché ARP de un equipo atacado.
:::

## Paso 4 · Fija la MAC buena, también al arrancar

:::pista Cómo hacerlo
```bash
sudo ip neigh replace 10.132.0.1 lladdr 02:42:0a:84:00:01 dev $IF nud permanent
ip neigh show 10.132.0.1
```
`nud permanent` crea una entrada **estática**: ninguna respuesta ARP la
sustituye. **Qué deberías ver:** `… PERMANENT`.

Para que se aplique al arrancar, una unidad de systemd:
```bash
sudo tee /etc/systemd/system/arp-estatico.service >/dev/null <<U
[Unit]
Description=Entrada ARP estática de la puerta de enlace
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip neigh replace 10.132.0.1 lladdr 02:42:0a:84:00:01 dev $IF nud permanent
[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload
sudo systemctl enable --now arp-estatico.service
```
- `<<U` sin comillas: la shell sustituye `$IF` por el nombre de tu interfaz al
  escribir el fichero.
- `Type=oneshot` + `RemainAfterExit=yes`: una tarea que se ejecuta una vez y
  queda como "activa".
:::

## Paso 5 · Vigilancia

:::pista Cómo hacerlo
```bash
sudo systemctl enable --now arpwatch@$IF
pgrep -af arpwatch
bash /opt/lab/check.sh
```
**arpwatch** vigila las parejas IP-MAC de la red y avisa en el log cuando una
cambia (`flip flop`, `changed ethernet address`). `arpwatch@<interfaz>` es una
unidad *plantilla*: lo que va después de `@` es la interfaz que vigila.
:::

## Cómo actuar en una situación así

- La entrada estática protege a **este** equipo. La protección de toda la red
  va en el switch: Dynamic ARP Inspection, apoyada en DHCP snooping.
- Entradas estáticas sólo para lo crítico (el gateway): no escalan.
- TLS en todo: aunque haya alguien en medio, no puede leer ni modificar el
  contenido.

## Si te atascas

- **`ip neigh` muestra `REACHABLE` o `STALE`:** faltó `nud permanent`.
- **`arpwatch@` no arranca:** el nombre de la interfaz va tras la `@`, sin
  espacios.
