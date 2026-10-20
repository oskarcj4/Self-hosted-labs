# Solución — Lab 01

## 1. ¿Desde dónde entró?

```bash
cat /var/log/auth.log
```

Verás un `Accepted publickey for analista from 185.220.101.47`. Esa es la IP del
intruso. Apúntala para el objetivo 4.

## 2. Eliminar la llave del atacante

```bash
cat ~/.ssh/authorized_keys
```

Hay dos llaves: una con comentario `analista@prod-web-01` (legítima) y otra con
`mallory@evil` (el atacante). Borra **sólo** la del atacante:

```bash
sed -i '/mallory@evil/d' ~/.ssh/authorized_keys
```

> Cambiar la contraseña no sirve de nada si el atacante dejó su llave pública:
> entra sin contraseña. Por eso `authorized_keys` es lo primero que se revisa.

## 3. Neutralizar la trampa en el .bashrc

```bash
tail ~/.bashrc
```

Al final hay un bloque "actualizacion automatica del sistema" con:
`[ -f /dev/shm/.update ] && source /dev/shm/.update`. Cada vez que abres una
shell nueva, eso ejecutaría el payload del atacante. Quítalo y borra el payload:

```bash
# quita las líneas de la trampa
sed -i '/actualizacion automatica del sistema/,/^# ----/d' ~/.bashrc
sed -i '\#source /dev/shm/.update#d' ~/.bashrc
# borra el payload
rm -f /dev/shm/.update
```

(Revisa también `/etc/bash.bashrc`, `~/.bash_profile` y `~/.profile`: son los
otros sitios clásicos de persistencia por dotfiles.)

## 4. Bloquear la IP

```bash
echo "sshd: 185.220.101.47" | sudo tee -a /etc/hosts.deny
```

En un servidor real complementarías con el firewall:
`sudo ufw deny from 185.220.101.47` o
`sudo iptables -A INPUT -s 185.220.101.47 -j DROP`.

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- La persistencia sobrevive al cambio de contraseña: revisa **llaves**, **dotfiles**, cron y servicios.
- `/dev/shm` y `/tmp` son escondites favoritos porque son escribibles por todos.
- Erradicar ≠ matar la sesión: hay que quitar **todas** las puertas traseras antes de reabrir el acceso.
