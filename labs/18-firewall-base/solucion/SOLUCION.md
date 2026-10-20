# Solución — Lab 18

## Reglas

```bash
# 1) abre primero lo necesario (para no cortarte el acceso)
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22  -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80  -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# 2) y AHORA cierra por defecto
sudo iptables -P INPUT DROP
```

Comprobar:

```bash
sudo iptables -S INPUT
bash /opt/lab/check.sh
```

## Lecciones

- *Default-deny*: bloquea todo y abre sólo lo necesario. Es lo contrario de
  "acepta todo y bloquea lo malo", que nunca termina.
- Acepta loopback y conexiones establecidas primero; si no, rompes el tráfico de
  respuesta y hasta tu propia sesión SSH.
- En producción, persiste las reglas (`iptables-save` / `netfilter-persistent`) o
  usa `ufw`/`nftables`; y aplica lo mismo a IPv6 (`ip6tables`).
