# Solución — Lab 20

## 1. Configurar la jail

```bash
sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = polling

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
EOF
```

## 2. Arrancar fail2ban

```bash
sudo fail2ban-client start      # o: sudo fail2ban-client reload si ya corría
sudo fail2ban-client ping       # -> Server replied: pong
sudo fail2ban-client status sshd
```

## 3. Banear la IP atacante

```bash
grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' | sort | uniq -c
# 12  from 198.51.100.23
sudo fail2ban-client set sshd banip 198.51.100.23
sudo fail2ban-client status sshd      # aparece en 'Banned IP list'
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- fail2ban lee los logs, cuenta fallos por IP dentro de `findtime` y, al superar
  `maxretry`, aplica una acción (por defecto, regla de iptables) durante `bantime`.
- Es defensa en profundidad sobre el hardening de SSH (lab 17): aunque alguien
  insista, se queda fuera tras unos intentos.
- Ajusta `ignoreip` para no banearte a ti mismo ni a redes de confianza.
