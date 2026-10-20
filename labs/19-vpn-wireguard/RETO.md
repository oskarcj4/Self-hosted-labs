# Lab 19 — Conecta dos servidores por VPN (WireGuard)

## Escenario (tarea de redes)

Tienes dos servidores: `serverA` (esta máquina, será `10.8.0.1`) y `serverB`
(el host `peer`, ya configurado como `10.8.0.2`). Necesitas un túnel **WireGuard**
cifrado entre ambos para que se hablen por su IP privada sin exponer nada a la
red pública. `serverB` ya está escuchando y publicó su clave pública; falta
configurar **este** lado.

## Cómo funciona el intercambio de claves

Ambos contenedores comparten el directorio `/shared`:
- `serverB` ya dejó su clave pública en `/shared/peer.pub`.
- Tú debes dejar la tuya en `/shared/lab.pub` para que `serverB` te acepte.

## Objetivos

1. **Genera tu par de claves** WireGuard.
2. **Publica tu clave pública** en `/shared/lab.pub`.
3. **Configura la interfaz `wg0`** en `10.8.0.1/24` con `serverB` como peer
   (su clave pública está en `/shared/peer.pub`, su endpoint es `peer:51820`,
   `AllowedIPs = 10.8.0.2/32`) y **levanta el túnel**.
4. **Verifica** que haces `ping 10.8.0.2` por el túnel.

## Comandos que te pueden servir

```bash
wg genkey | sudo tee /etc/wireguard/lab.key | wg pubkey | sudo tee /etc/wireguard/lab.pub
sudo cp /etc/wireguard/lab.pub /shared/lab.pub
cat /shared/peer.pub                      # la clave pública de serverB
sudo ip link add wg0 type wireguard
sudo ip addr add 10.8.0.1/24 dev wg0
sudo wg set wg0 private-key /etc/wireguard/lab.key \
     peer "$(cat /shared/peer.pub)" endpoint peer:51820 \
     allowed-ips 10.8.0.2/32 persistent-keepalive 15
sudo ip link set wg0 up
ping -c 3 10.8.0.2
```

> Hay un ejemplo de configuración en `/opt/lab/wg0.conf.example` por si prefieres
> `wg-quick`. Nota: este lab necesita el módulo WireGuard en el kernel del host.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
