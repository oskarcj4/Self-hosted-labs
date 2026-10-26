# Resolución guiada · SSH con bastión

:::piensa Antes de tocar nada
Un pipeline no teclea contraseñas: autentica con **clave**. Y `app-02` no se
alcanza directo, sólo a través del `bastion` → eso es `ProxyJump`, no copiar
la clave al bastión. Las contraseñas del ticket son de un solo uso: instalar
la clave y nunca más.
:::

## Paso 1 · Crea la clave de automatización

**Pregúntate:** ¿passphrase? No: es una cuenta de automatización, nadie estará
delante para teclearla.

:::pista Cómo hacerlo
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C 'analista@dev-01 pipeline'
ls -l ~/.ssh/      # id_ed25519 (600), id_ed25519.pub (644)
```
:::

## Paso 2 · Configura el cliente (el salto, una vez)

**Pregúntate:** ¿cómo digo "a app-02 se entra por el bastión" sin repetir flags
en cada comando? Con alias y `ProxyJump` en `~/.ssh/config`.

:::pista Cómo hacerlo
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
`ProxyJump` abre un túnel **a través** del bastión y negocia la sesión con
app-02 de extremo a extremo; tu clave privada no sale de dev-01. Más seguro que
copiar la clave al bastión o usar `ssh -A` (con agent forwarding, un root del
bastión puede usar tu agente).
:::

## Paso 3 · Instala la pública en ambos

```bash
ssh-copy-id bastion     # contraseña del ticket (una vez)
ssh-copy-id app-02      # el salto ya va con clave; pide la de app-02
ssh bastion hostname    # bastion, sin contraseña
ssh app-02 hostname     # ¡sigue pidiendo contraseña!  -> paso 4
```

## Paso 4 · La clave está puesta y aun así pide contraseña

**Pregúntate:** si la clave se ofrece y la rechaza, el problema no es la clave.
`sshd` con `StrictModes yes` (por defecto) **ignora** `authorized_keys` si el
home, `~/.ssh` o el fichero son escribibles por grupo/otros.

:::pista Cómo verlo y arreglarlo
```bash
ssh -v app-02 2>&1 | grep -iE 'offering|authentications that can continue'
# Offering public key ...  /  Authentications that can continue: publickey,password  (la rechazó)

ssh app-02 'ls -ld ~ ~/.ssh ~/.ssh/authorized_keys'
# drwxrwxrwx ... permisos demasiado abiertos

ssh app-02        # con contraseña, por última vez
chmod 755 ~ ; chmod 700 ~/.ssh ; chmod 600 ~/.ssh/authorized_keys
sed -i '/old-laptop/d' ~/.ssh/authorized_keys   # quita la clave del ex-empleado
cat ~/.ssh/authorized_keys                       # sólo tu clave
exit
ssh app-02 hostname                              # sin preguntar
```
Si cualquiera puede escribir en `~/.ssh`, cualquiera puede añadir su clave: por
eso `sshd` desconfía.
:::

## Paso 5 · Verifica

```bash
ssh -G app-02 | grep -i proxyjump      # proxyjump bastion
ssh app-02 hostname                    # app-02, sin contraseña
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Un alias en `~/.ssh/config`** vale más que un script con 10 flags: lo usan
  `scp`, `rsync`, `git`, Ansible.
- **`ProxyJump` (`-J`)** en vez de copiar claves al bastión o usar `ssh -A`.
- **Si la clave "no funciona"**, mira en este orden: `ssh -v`, el log de `sshd`
  del servidor, y los permisos (`~` y `~/.ssh` sin escritura para grupo/otros).
- **Revisa `authorized_keys` periódicamente**: la clave de quien ya se fue es
  un acceso abierto.

## Si te atascas

- Pide contraseña con la clave puesta → permisos: `chmod 755 ~`, `700 ~/.ssh`,
  `600 authorized_keys`.
- `ssh app-02` no salta por el bastión → falta `ProxyJump bastion` o el bloque
  `Host app-02` no coincide con el alias que usas.
