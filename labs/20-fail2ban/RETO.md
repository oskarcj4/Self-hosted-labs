# Lab 20 — Protege SSH con fail2ban

## Escenario (tarea de hardening)

`ssh-20` recibe fuerza bruta constante contra SSH. Instala y configura
**fail2ban** para que banee automáticamente a quien falle demasiadas veces, y
banea ya a la IP atacante que aparece en el log (`198.51.100.23`).

## Objetivos

1. **Crea `/etc/fail2ban/jail.local`** con una jail `[sshd]` **habilitada**,
   `maxretry = 3`, leyendo `/var/log/auth.log`.
2. **Arranca el servicio** fail2ban.
3. **Banea la IP atacante** `198.51.100.23` (la verás en el log) y confirma que
   queda en la lista de baneados de la jail `sshd`.

## Comandos que te pueden servir

```bash
grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' | sort | uniq -c
sudo nano /etc/fail2ban/jail.local
sudo fail2ban-client start            # arranca el servidor fail2ban
sudo fail2ban-client reload
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd banip 198.51.100.23
```

Plantilla de `jail.local`:

```ini
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = polling

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
