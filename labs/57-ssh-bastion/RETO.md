# Conectar dos máquinas por SSH (con bastión)

> Operaciones · SSH · claves · ProxyJump · 3 servidores

## Escenario

El pipeline de despliegue corre en `dev-01` (donde estás) y tiene que ejecutar
comandos en `app-02`. Pero `app-02` vive en la red interna: **sólo se llega a
través del `bastion`**. Lee `~/ticket/TAREA-118.txt`.

```
dev-01 ──ssh──▶ bastion ──ssh──▶ app-02
10.76.57.10     10.76.57.5        10.77.57.20
                10.77.57.5
```

Las contraseñas del ticket son provisionales: sirven para instalar tu clave
una vez y nada más. Un pipeline no puede escribir contraseñas.

## Objetivos

1. Crea una clave **ed25519** para `analista` en `~/.ssh/id_ed25519`. Esta
   cuenta es de automatización, así que la clave no lleva passphrase.
2. Instala tu clave pública en `deploy@bastion` y en `deploy@app-02`.
3. Escribe `~/.ssh/config` con dos alias:
   - `bastion` → `deploy@10.76.57.5`
   - `app-02` → `deploy@10.77.57.20`, saliendo **por el bastión** (`ProxyJump`).
4. `ssh app-02 hostname` funciona **sin pedir nada**.
5. En `app-02`, quita la clave `old-laptop` de `authorized_keys`: es de alguien
   que ya no está en la empresa.

> Si la clave está instalada y aun así `app-02` te pide contraseña, el
> problema no es la clave. Mira qué opina `sshd` de los permisos.

## Comandos que te pueden servir

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@10.76.57.5
ssh -J deploy@10.76.57.5 deploy@10.77.57.20       # salto puntual
ssh -v app-02                                     # qué claves prueba y por qué falla
ssh -G app-02 | grep -i proxyjump                 # config efectiva
ls -ld ~ ~/.ssh ; ls -l ~/.ssh                    # (en app-02)
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
