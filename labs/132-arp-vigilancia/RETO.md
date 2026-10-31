# ARP: ¿quién es de verdad la puerta de enlace?

> Redes · ip neigh · arping · tcpdump arp · arpwatch

## Escenario

Los pagos de `caja-132` fallan a ratos y el banco ha visto conexiones que no
salen del router de la tienda (`~/ticket/NET-132.txt`, que dice también
cuál es tu interfaz de LAN). Puerta de enlace oficial: `10.132.0.1`.

ARP traduce IP → MAC dentro de la red local, y **no tiene autenticación**:
cualquier equipo puede anunciar "10.132.0.1 soy yo, mi MAC es ésta" y los
demás le creerán. Así se pone en medio de todo el tráfico (ARP spoofing /
man-in-the-middle).

## Objetivos

1. Observa la tabla de vecinos y el tráfico ARP: localiza la IP suplantada,
   la MAC legítima del gateway, la MAC del atacante y la IP propia del
   atacante. Anótalo en `~/arp.txt` (formato en el ticket).
2. Protege la caja con una entrada ARP **estática** (`PERMANENT`) para el
   gateway con su MAC legítima, que se aplique también al arrancar.
3. Deja `arpwatch` vigilando la interfaz de la LAN y habilitado al arranque
   (en Debian: `arpwatch@<interfaz>`).

## Comandos que te pueden servir

```bash
ip neigh show ; watch -n1 ip neigh show 10.132.0.1
sudo tcpdump -i <if> -nn -e arp           # -e muestra las MAC
sudo arping -c 3 -I <if> 10.132.0.1         # ¿cuántas MAC contestan?
sudo ip neigh replace 10.132.0.1 lladdr <mac> dev <if> nud permanent
sudo systemctl enable --now arpwatch@<if>
sudo journalctl -u arpwatch@<if>           # "flip flop", "changed ethernet address"
```

> Una entrada estática protege a **este** equipo. La protección de toda la
> red va en el switch: Dynamic ARP Inspection (DAI) apoyada en DHCP snooping.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
