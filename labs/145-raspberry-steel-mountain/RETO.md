# La Raspberry Pi de Steel Mountain

> Mr. Robot · OT/IT · inventario de red · ARP/MAC · segmentación con nftables

## Escenario

En Steel Mountain "el aire acondicionado hace cosas raras". La sospecha: hay
un equipo conectado al segmento que **nadie dio de alta** y que habla con el
controlador HVAC. En la serie es una Raspberry Pi; en la vida real, cualquier
dispositivo no inventariado en una red OT es una puerta abierta.

- El **inventario** es la base de todo: no puedes proteger lo que no sabes que
  existe. Un barrido ARP del segmento revela qué responde y con qué MAC.
- El **OUI** (los 3 primeros octetos de la MAC) identifica al fabricante.
  `b8:27:eb` pertenece a la Raspberry Pi Foundation: nada que hacer en una red
  industrial de respaldo.
- La **segmentación** evita que IT y OT se mezclen. Aquí, lo mínimo: aislar el
  dispositivo no aprobado para que no alcance el HVAC.

## Objetivos

1. Inventaria el segmento `10.145.0.0/24` (herramienta `inventario`) y guarda
   la salida en `~/inventario.txt`.
2. Compárala con la CMDB (`/etc/red/activos-aprobados.txt`). Identifica el
   intruso por su OUI y apunta en `~/hallazgos.txt`:

   ```
   rogue_ip=<IP>
   rogue_mac=<MAC completa>
   ```

3. Aísla el dispositivo con **nftables**: ni entra ni sale del segmento. Haz
   la regla persistente (`/etc/nftables.conf`).

## Comandos que te pueden servir

```bash
inventario | tee ~/inventario.txt
cat /etc/red/activos-aprobados.txt
ip neigh show | grep 10.145.0.
sudo nft add rule inet filter input  ip saddr 10.145.0.66 drop
sudo nft add rule inet filter output ip daddr 10.145.0.66 drop
sudo nft list ruleset
sudo nano /etc/nftables.conf     # añade las reglas aquí para que persistan
sudo systemctl restart nftables && sudo nft list ruleset
ping -c1 -W2 10.145.0.66         # tras el bloqueo, debe fallar
```

> Un bloqueo por IP se evade cambiando de IP; por eso en OT real se segmenta por
> VLAN/puerto de switch y se usa 802.1X. Aquí practicas el reflejo: inventariar,
> detectar lo no aprobado y aislarlo ya.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
