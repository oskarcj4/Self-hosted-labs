# Resolución guiada · Lab 148

:::piensa La verdad la tiene RRHH
Tú no decides quién debe tener acceso: lo dice `altas-bajas.txt`. Tu trabajo
es que el sistema coincida con esa lista. Y quitar el acceso a alguien no es
sólo borrar su cuenta: puede seguir entrando con una **llave SSH** puesta en
otra cuenta, o conservar **sudo** por una regla olvidada. Hay que barrer las
tres vías.
:::

**El plan:** (1) cruzar cuentas, (2) cruzar llaves, (3) cruzar sudo y
(4) documentar.

## Paso 1 · Cruza las cuentas

:::pista Cómo hacerlo
```bash
cat /etc/iam/altas-bajas.txt
cut -d: -f1,7 /etc/passwd | grep -vE 'nologin|/false'
sudo passwd -S tyrell
```
- `/etc/passwd` tiene una línea por cuenta con campos separados por `:`;
  `cut -d: -f1,7` saca el nombre (campo 1) y la shell (campo 7). Las cuentas
  con `nologin` o `/bin/false` no pueden abrir sesión; las demás, sí.
- `passwd -S` da el estado de la contraseña: `P` usable, `L` bloqueada.

**Qué deberías ver:** `tyrell` y `scripted` están de BAJA en RRHH, pero tienen
shell y contraseña usable. Bloquéalos:
```bash
sudo passwd -l tyrell scripted
sudo passwd -S tyrell
```
`passwd -l` bloquea la contraseña sin borrar la cuenta ni sus ficheros
(conviene conservarlos por si hay que investigar). `userdel -r` la borraría
del todo, con su carpeta personal.
:::

## Paso 2 · Cruza las llaves SSH

**Pregúntate:** bloquear la contraseña de una cuenta, ¿impide entrar con una
llave SSH?

:::pista Cómo hacerlo
No: SSH con llave no usa la contraseña. Y una llave del que se fue puede estar
en **otra** cuenta.
```bash
cat /etc/iam/llaves-aprobadas.txt
sudo find /home /root -name authorized_keys -exec grep -H '' {} +
```
`find … -exec grep -H '' {} +` imprime cada línea de cada `authorized_keys`
con el nombre del fichero delante (`-H`). El último campo de cada llave es un
comentario que identifica a su dueño.

**Qué deberías ver:** la llave `darkarmy@exfil`, que no está aprobada, en la
cuenta de `deploy` (activa) y en la de `tyrell`. Quítala de todas:
```bash
sudo sed -i '/darkarmy@exfil/d' /home/*/.ssh/authorized_keys
sudo grep -rl 'darkarmy@exfil' /home /root || echo "ya no está"
```
`sed -i '/patrón/d'` borra las líneas que contienen el patrón. La aprobada,
`ops@allsafe`, se queda.
:::

## Paso 3 · Cruza sudo

:::pista Cómo hacerlo
```bash
sudo ls -l /etc/sudoers.d/
sudo cat /etc/sudoers.d/tyrell
sudo rm /etc/sudoers.d/tyrell
sudo visudo -c
```
Cada fichero de `/etc/sudoers.d/` añade reglas de sudo. `visudo -c` comprueba
que la configuración de sudo sigue siendo válida: un sudoers roto puede dejar
a **todos** sin sudo.
:::

## Paso 4 · Documenta

:::pista Cómo hacerlo
```bash
cat > ~/revocados.txt <<'R'
cuenta tyrell: bloqueada (BAJA)
cuenta scripted: bloqueada (BAJA, contratista)
llave SSH darkarmy@exfil: eliminada de /home/deploy y /home/tyrell
sudoers.d/tyrell: eliminado
R
bash /opt/lab/check.sh
```
El informe es parte del control: demuestra qué se revocó y cuándo.
:::

## Cómo actuar en una situación así

- Revocar = cuenta + llaves + sudo + grupos + tokens de API. Olvidar una vía es
  dejar la puerta entornada.
- Lo barato es automatizarlo: la baja en RRHH dispara la revocación en todos
  los sistemas (*joiner/mover/leaver* contra LDAP o el SSO).
- Revisa periódicamente los `authorized_keys`: es donde se esconden los
  accesos que nadie recuerda.

## Si te atascas

- **El check sigue viendo la llave:** quedan copias en algún `authorized_keys`;
  repite el `find`.
- **No borres `deploy`:** es una cuenta de servicio de ALTA; sólo sobraba la
  llave que le pusieron.
- **`visudo -c` da error:** no edites `sudoers.d` a mano sin `visudo`.
