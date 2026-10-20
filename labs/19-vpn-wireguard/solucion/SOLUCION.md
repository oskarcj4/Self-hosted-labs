# Solución — Lab 19

## Opción A: con `wg set` (paso a paso)

```bash
umask 077
wg genkey | sudo tee /etc/wireguard/lab.key | wg pubkey | sudo tee /etc/wireguard/lab.pub
sudo cp /etc/wireguard/lab.pub /shared/lab.pub      # publícala para serverB

sudo ip link add wg0 type wireguard
sudo ip addr add 10.8.0.1/24 dev wg0
sudo wg set wg0 private-key /etc/wireguard/lab.key \
     peer "$(cat /shared/peer.pub)" endpoint peer:51820 \
     allowed-ips 10.8.0.2/32 persistent-keepalive 15
sudo ip link set wg0 up

ping -c 3 10.8.0.2
sudo wg show wg0        # debe mostrar el peer y un 'latest handshake'
```

## Opción B: con `wg-quick`

```bash
umask 077
wg genkey | sudo tee /etc/wireguard/lab.key | wg pubkey | sudo tee /etc/wireguard/lab.pub
sudo cp /etc/wireguard/lab.pub /shared/lab.pub
sudo cp /opt/lab/wg0.conf.example /etc/wireguard/wg0.conf
# rellena PrivateKey con el contenido de /etc/wireguard/lab.key
# y PublicKey con el de /shared/peer.pub, luego:
sudo wg-quick up wg0
ping -c 3 10.8.0.2
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- WireGuard = claves asimétricas: cada lado tiene su privada y conoce la pública
  del otro. La privada nunca sale de su máquina.
- `AllowedIPs` define qué tráfico entra al túnel y qué origen se acepta del peer.
- `Endpoint` lo necesita quien inicia; con `PersistentKeepalive` el túnel
  sobrevive a NAT/firewall. En producción, abre sólo el puerto UDP de WireGuard.
