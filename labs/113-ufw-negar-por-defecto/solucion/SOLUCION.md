# Solución — Firewall con ufw: negar por defecto

## Qué pasaba

El servidor exponía, además de 22/80/443, servicios internos (base de datos,
paneles, puertos de depuración) en todas las interfaces y sin firewall. El
escáner externo los veía todos.

## Arreglo

```bash
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH        # primero SSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose
sleep 20; cat /srv/escaneo/ultimo.txt   # siguiente pasada del escáner
bash /opt/lab/check.sh
```

## Más allá del lab

- Limita SSH por origen: `ufw allow from 10.0.0.0/8 to any port 22`.
- `ufw limit OpenSSH` añade un rate limit básico contra fuerza bruta.
- Además del firewall, configura los servicios internos para escuchar en
  `127.0.0.1`: si alguien desactiva ufw, siguen sin estar expuestos.
- Docker publica puertos con sus propias reglas de iptables y puede saltarse
  ufw: revisa `DOCKER-USER`.
