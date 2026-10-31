# Solución — SSH: fail2ban y sólo llaves

## Qué pasaba

Un bot prueba contraseñas contra SSH sin parar. SSH aceptaba contraseñas y root
podía entrar; no había fail2ban activo.

## Arreglo

```bash
N=$(sudo grep -c "Failed password" /var/log/auth.log.1)
TOP=$(sudo grep "Failed password" /var/log/auth.log.1 | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
printf 'intentos=%s\ntop=%s\n' "$N" "$TOP" > ~/respuestas.txt

sudo tee /etc/fail2ban/jail.local <<'J'
[sshd]
enabled  = true
backend  = auto
logpath  = /var/log/auth.log
maxretry = 3
findtime = 10m
bantime  = 1h
J
sudo systemctl enable fail2ban && sudo systemctl restart fail2ban
sudo fail2ban-client status sshd        # espera a ver la IP del bot

ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

sudo tee /etc/ssh/sshd_config.d/10-solo-llave.conf <<'C'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
C
sudo sshd -t && sudo systemctl reload ssh
bash /opt/lab/check.sh
```

## Más allá del lab

- `backend = systemd` es lo normal en hosts con journald; aquí se lee el fichero.
- Añade `AllowUsers` / `AllowGroups` y, en servidores expuestos, MFA o un bastion.
- Llaves con passphrase y, mejor aún, certificados SSH firmados por una CA.
