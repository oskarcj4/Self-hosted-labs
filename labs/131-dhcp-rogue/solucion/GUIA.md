# Resolución guiada · Lab 131

:::piensa Antes de tocar nada
DHCP no tiene autenticación: el cliente acepta la primera oferta que le llega.
Quien responda antes decide tu IP, tu puerta de enlace y tu DNS.
:::

## Paso 1 · Captura el DORA

**Pregúntate:** ¿qué puertos usa DHCP? Servidor 67, cliente 68.

:::pista Cómo hacerlo
```bash
IF=$(cat /opt/lab/.lan-if)
sudo tcpdump -i $IF -nn -e -w ~/dora.pcap 'port 67 or port 68' &
sudo timeout 20 dhclient -v -1 $IF
sudo kill %1
```
Discover → Offer → Request → Ack.
:::

## Paso 2 · ¿Cuántos ofrecen?

:::pista Cómo comprobarlo
```bash
tshark -r ~/dora.pcap -T fields -e eth.src -e ip.src -e dhcp.option.dhcp -e dhcp.option.router
```
`dhcp.option.dhcp == 2` es un OFFER. Si hay dos IPs de origen distintas, uno sobra.
El falso da como puerta de enlace su propia IP: así ve todo tu tráfico.
:::

## Paso 3 · Identifícalo

Escribe en `~/dhcp.txt`: `servidor_legitimo=`, `servidor_falso=`, `mac_falso=`.

## Paso 4 · Rechaza al falso

**Pregúntate:** ¿cómo le dices a dhclient que ignore ofertas de una IP concreta?

:::pista Cómo hacerlo
```bash
sudo dhclient -r $IF
echo 'reject 10.131.0.66;' | sudo tee -a /etc/dhcp/dhclient.conf
sudo timeout 30 dhclient -v -1 $IF
ip -4 addr show dev $IF; ip route
```
La puerta de enlace debe ser la legítima.
:::

## Cómo actuar en una situación así

- La defensa real está en el switch: **DHCP snooping** sólo permite ofertas desde puertos de confianza.
- Localiza el equipo por su MAC en la tabla del switch y desconéctalo.
- `reject` en el cliente es un parche local mientras tanto.

## Si te atascas

- Sólo ves un OFFER: el falso es más rápido y el legítimo tarda 2 s; captura más tiempo.
- dhclient se queda la misma IP: libera antes con `dhclient -r`.
