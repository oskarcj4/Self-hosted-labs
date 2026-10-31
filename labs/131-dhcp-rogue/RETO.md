# DHCP: DORA y el servidor que no debería estar

> Redes · dhclient · tcpdump port 67/68 · tshark · DHCP falso

## Escenario

Varios portátiles reciben por DHCP una puerta de enlace "rara" y navegan
mal (`~/ticket/NET-131.txt`, que también dice cuál es tu interfaz de LAN).
El DHCP oficial reparte 10.131.0.100-150.

DHCP en cuatro mensajes (**DORA**), casi todos por broadcast:

| | Mensaje | Quién | Qué dice |
|---|---|---|---|
| D | Discover | cliente | "¿hay algún servidor DHCP?" |
| O | Offer | servidor(es) | "te ofrezco esta IP, este gateway, este DNS" |
| R | Request | cliente | "me quedo con la oferta de *ese* servidor" |
| A | ACK | servidor elegido | "concedida" |

El cliente se queda con la **primera** oferta que llega. Cualquiera que
conecte un router doméstico a la red puede contestar antes que el oficial
y convertirse en tu puerta de enlace: un intermediario perfecto.

## Objetivos

1. Captura en `~/dora.pcap` un intercambio DHCP completo mientras pides IP
   con `dhclient` en la interfaz de la LAN.
2. Identifica los dos servidores y la MAC del falso (con ella, en una red
   real, el switch te dice en qué puerto está). Anótalo en `~/dhcp.txt`.
3. Configura `dhclient` para que ignore al servidor falso, libera la
   concesión y vuelve a pedir: tu IP y tu ruta tienen que venir del oficial.

## Comandos que te pueden servir

```bash
ip -br addr
sudo tcpdump -i <if> -nn -e -w ~/dora.pcap 'port 67 or port 68'     # en otra terminal o con &
sudo dhclient -v -1 <if>
sudo dhclient -r <if>                                             # liberar
tshark -r ~/dora.pcap -T fields -e eth.src -e ip.src -e dhcp.option.dhcp -e dhcp.option.router
man dhclient.conf      # busca "reject"
sudo cat /var/lib/dhcp/dhclient*.leases
```

> La defensa real va en el switch: **DHCP snooping** sólo deja contestar a
> DHCP a los puertos marcados como de confianza.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
