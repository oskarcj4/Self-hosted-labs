# Solución — SSH con bastión

## 1. Clave

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C 'analista@dev-01 pipeline'
ls -l ~/.ssh/          # id_ed25519 (600) e id_ed25519.pub (644)
```

## 2. Configuración del cliente

```bash
cat > ~/.ssh/config <<'EOF'
Host bastion
    HostName 10.76.57.5
    User deploy
    IdentityFile ~/.ssh/id_ed25519

Host app-02
    HostName 10.77.57.20
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump bastion
EOF
chmod 600 ~/.ssh/config
```

Con `ProxyJump`, tu `ssh` abre un túnel **a través** del bastión y negocia la
sesión con `app-02` de extremo a extremo. Tu clave privada no sale de
`dev-01`. Es más seguro que copiar la clave al bastión o usar `ssh -A`
(agent forwarding): con agent forwarding, cualquiera que sea root en el
bastión puede usar tu agente mientras estás conectado.

## 3. Instalar la clave

```bash
ssh-copy-id bastion            # contraseña: Bastion-2026
ssh-copy-id app-02             # el salto ya va con clave; pide App02-2026
ssh bastion hostname           # bastion, sin contraseña
ssh app-02 hostname            # ¡sigue pidiendo contraseña!
```

## 4. ¿Por qué app-02 ignora la clave?

```bash
ssh -v app-02 2>&1 | grep -iE 'offering|authentications that can continue'
# Offering public key: /home/analista/.ssh/id_ed25519 ED25519 ...
# Authentications that can continue: publickey,password   <- la rechazó
```

El servidor no le dice al cliente por qué la rechaza. En su log (al que aquí
no tienes acceso) aparecería:

```
Authentication refused: bad ownership or modes for directory /home/deploy
```

Lo puedes ver tú mismo entrando con contraseña:

```bash
ssh app-02 'ls -ld ~ ~/.ssh ~/.ssh/authorized_keys'
# drwxrwxrwx ... /home/deploy
# drwxrwxrwx ... /home/deploy/.ssh
# -rw-rw-rw- ... /home/deploy/.ssh/authorized_keys
```

Con `StrictModes yes` (la opción por defecto), `sshd` ignora
`authorized_keys` si el home, `~/.ssh` o el propio fichero los puede
modificar otro usuario. Si cualquiera puede escribir ahí, cualquiera puede
añadir su clave.

```bash
ssh app-02        # con contraseña, por última vez
chmod 755 ~ ; chmod 700 ~/.ssh ; chmod 600 ~/.ssh/authorized_keys
sed -i '/old-laptop/d' ~/.ssh/authorized_keys
cat ~/.ssh/authorized_keys      # sólo tu clave
exit
ssh app-02 hostname             # app-02, sin preguntar
```

## Lecciones

- Un alias en `~/.ssh/config` vale más que un script con 10 flags. Todo
  (`scp`, `rsync`, `git`, Ansible) lo usa.
- `ProxyJump` (`-J`) en vez de copiar claves al bastión o usar `ssh -A`.
- Si la clave "no funciona", revisa en este orden: `ssh -v`, el log de `sshd`
  del servidor y los permisos (`~` y `~/.ssh` sin escritura para grupo ni otros).
- `authorized_keys` hay que revisarlo cada cierto tiempo: las claves de gente
  que ya se fue son accesos que siguen abiertos.
