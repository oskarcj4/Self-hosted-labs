# Solución — Enrutamiento y TTL

## Qué pasaba

El lab es el router entre `10.130.1.0/24` (`.254`) y `10.130.2.0/24` (`.254`).
`/etc/sysctl.d/90-router.conf` fijaba `ip_forward = 0` y la unidad
`rutas-router.service` no añadía la ruta a `10.130.3.0/24` vía `10.130.2.253`.

## Arreglo

```bash
sudo sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.d/90-router.conf
sudo sysctl --system >/dev/null
sudo sed -i 's|^ExecStart=/bin/true|ExecStart=-/sbin/ip route add 10.130.3.0/24 via 10.130.2.253|' \
  /etc/systemd/system/rutas-router.service
sudo systemctl daemon-reload && sudo systemctl restart rutas-router.service
ip route
T=$(ping -c 1 10.130.3.30 | grep -o 'ttl=[0-9]*' | cut -d= -f2)
traceroute -n 10.130.3.30
printf 'ttl_respuesta=%s\nsaltos_pc=2\n' "$T" > ~/ttl.txt
sleep 12; cat /srv/estado/pc.txt
bash /opt/lab/check.sh
```

Respuestas: `ttl_respuesta=63` (un router entre tú y el PC), `saltos_pc=2`.

## Más allá del lab

- En producción, gestiona rutas con systemd-networkd, netplan o un protocolo (OSPF/BGP).
- Un router que reenvía también necesita reglas `FORWARD` en el firewall.
