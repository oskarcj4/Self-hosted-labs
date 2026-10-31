# Higiene de permisos

> Defensa del host · chmod · find -perm · umask

## Escenario

Auditoría de permisos en `app-120` (`~/ticket/AUDIT-120.txt`). Nada está
"hackeado", pero está todo abierto: una llave privada que cualquiera lee, un
`.env` con la contraseña de la base de datos legible por todos y un script
que cron ejecuta **como root** y que cualquier usuario puede editar (eso es
root para cualquiera). Y un `umask` que fabrica más ficheros abiertos cada día.

## Objetivos

1. `~deploy/.ssh` en 700; `id_ed25519` y `authorized_keys` en 600, de deploy.
2. `/srv/app/.env` en 600, dueño `app`.
3. Ningún fichero world-writable en el sistema. Ojo: no rompas lo que cron
   necesita ejecutar. (Directorios compartidos con sticky bit, como
   `/tmp`, están bien.)
4. Corrige el umask: el global sin escritura para grupo/otros, y el de
   `deploy` en 027 (o 077).

## Comandos que te pueden servir

```bash
stat -c '%a %U:%G %n' ~deploy/.ssh ~deploy/.ssh/* /srv/app/.env
sudo find / -xdev -type f -perm -0002 2>/dev/null
sudo find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null
sudo chmod 600 <fichero> ; sudo chmod o-w <fichero>
umask ; sudo su - deploy -c umask
sudo grep -rn umask /etc/profile /etc/profile.d/ /etc/bash.bashrc ~deploy/.profile ~deploy/.bashrc
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
