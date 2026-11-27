# Resolución guiada · Lab 120

:::piensa Abierto no es lo mismo que roto
Nada está "hackeado", y por eso nadie lo arregla. Pero una llave privada que
cualquiera lee es una llave de todos; un `.env` legible por todos, una
contraseña publicada; y un script que cron ejecuta como root y que cualquiera
puede editar es root para cualquiera. El `umask` es lo que hace que los
ficheros nuevos salgan así cada día.
:::

**El plan:** (1) ver los permisos, (2) cerrar los ficheros sensibles,
(3) barrer lo escribible por todos y (4) arreglar el umask.

## Paso 1 · ¿Qué está mal?

:::pista Cómo hacerlo
```bash
sudo stat -c '%a %U:%G %n' /home/deploy/.ssh /home/deploy/.ssh/* /srv/app/.env
```
`stat -c` imprime con formato: `%a` los permisos en número, `%U:%G` dueño y
grupo, `%n` el nombre.

Los permisos en número son tres cifras (dueño, grupo, otros), y cada una
suma: 4 = leer, 2 = escribir, 1 = ejecutar. `600` = el dueño lee y escribe;
nadie más nada. `644` = todos leen. `666` o `777` = todos escriben.

**Qué deberías ver:** `.ssh` y la llave privada abiertos a otros, y `.env`
legible por todos.
:::

## Paso 2 · Cierra lo sensible

**Pregúntate:** ¿quién necesita leer cada fichero? ¿Quién escribir?

:::pista Cómo hacerlo
```bash
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/id_ed25519 /home/deploy/.ssh/authorized_keys
sudo chown app /srv/app/.env
sudo chmod 600 /srv/app/.env
```
SSH, además, **se niega** a usar una llave privada o un `authorized_keys`
accesibles por otros: no es sólo buena práctica, es un requisito.
:::

## Paso 3 · Lo que cualquiera puede escribir

:::pista Cómo hacerlo
```bash
sudo find / -xdev -type f -perm -0002 2>/dev/null
sudo find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null
```

| Opción | Qué busca |
|---|---|
| `-xdev` | Sin salir del sistema de ficheros raíz (no entra en `/proc`, `/sys`…). |
| `-type f -perm -0002` | Ficheros con el bit de escritura para "otros". El `-` delante significa "al menos ese bit". |
| `-type d -perm -0002 ! -perm -1000` | Directorios escribibles por todos **sin** *sticky bit* (`1000`). Con sticky bit, como `/tmp`, cada uno sólo puede borrar lo suyo: están bien. |

**Qué deberías ver:** entre otros, `/usr/local/bin/backup.sh`, que cron
ejecuta como root. Quítale la escritura a "otros" a todos:
```bash
sudo find / -xdev -type f -perm -0002 -exec chmod o-w {} + 2>/dev/null
ls -l /usr/local/bin/backup.sh
```
`-exec chmod o-w {} +` aplica `chmod o-w` (quitar escritura a otros) a todos
los encontrados. Así no cambias nada más: `backup.sh` sigue siendo ejecutable
y cron lo sigue lanzando.
:::

## Paso 4 · El umask

**Pregúntate:** el umask decide los permisos de los ficheros **nuevos**. ¿De
dónde sale el `000`?

:::pista Cómo hacerlo
```bash
umask; sudo su - deploy -c umask
sudo grep -rn umask /etc/profile /etc/profile.d/ /etc/bash.bashrc /home/deploy/.profile /home/deploy/.bashrc
```
El **umask** son los bits que se **quitan** al crear un fichero: con `022`,
un fichero nuevo sale `644`; con `027`, `640`; con `000`, `666`, escribible
por todos. Se fija al iniciar sesión, en los ficheros que lee la shell.

**Qué deberías ver:** un `umask 000` en un fichero de `/etc/profile.d/`
(afecta a todos) y otro en `/home/deploy/.profile`. Arréglalos:
```bash
sudo rm /etc/profile.d/99-umask-compat.sh
sudo sed -i 's/^umask 000.*/umask 027/' /home/deploy/.profile
sudo su - deploy -c umask
bash /opt/lab/check.sh
```
(Usa los nombres que te haya dado el `grep`.) **Qué deberías ver:** `0027`.
:::

## Cómo actuar en una situación así

- Busca periódicamente ficheros escribibles por todos fuera de `/tmp`.
- Un script que ejecuta root debe ser de root, con `755` como mucho, y su
  directorio también: si alguien puede escribir en el directorio, puede
  sustituir el script.
- `umask 027` en servidores: el grupo lee, el resto nada.

## Si te atascas

- **SSH sigue rechazando la llave:** el directorio home de `deploy` tampoco
  puede ser escribible por otros (`chmod 755 /home/deploy`).
- **`su - deploy -c umask` sigue en `0000`:** queda otra línea; el `grep` del
  paso 4 enseña todas.
