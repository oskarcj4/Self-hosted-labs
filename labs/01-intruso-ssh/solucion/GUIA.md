# Resolución guiada · Lab 01

:::piensa Antes de tocar nada
Un intruso que "sigue volviendo" después de cambiar la contraseña no está usando la contraseña. Tiene **otra puerta**. Tu trabajo no es echarlo una vez: es encontrar *cada* forma que tiene de volver y cerrarlas todas. Piensa como él: ¿qué dejarías tú para volver a entrar?
:::

Método para todo el lab: **observar → entender → erradicar → bloquear → verificar**. No borres nada hasta saber qué es.

## Paso 1 · ¿Quién entró y desde dónde?

**Pregúntate:** ¿dónde deja rastro un login SSH? Todo acceso (fallido o no) pasa por el servicio de autenticación, y eso se registra.

**Por qué importa:** la IP es tu primer indicador de compromiso (IoC). La necesitas para bloquear y para buscar más actividad del mismo origen.

:::pista Cómo comprobarlo
```bash
cat /var/log/auth.log
grep -E 'Accepted|Failed' /var/log/auth.log
```
Busca líneas `Accepted ... for analista from <IP>`. Fíjate también en **el método**: `password` o `publickey`. Si entró con `publickey`, ya sabes por qué cambiar la contraseña no sirvió.
:::

## Paso 2 · ¿Cómo vuelve a entrar sin contraseña?

**Pregúntate:** si el login fue por clave pública, ¿dónde guarda SSH las claves que aceptan para esta cuenta?

**Por qué importa:** `~/.ssh/authorized_keys` es la puerta trasera más simple y más común. Una línea basta para tener acceso permanente.

:::pista Cómo comprobarlo
```bash
cat ~/.ssh/authorized_keys
```
Cada línea es una clave. El último campo es un comentario (normalmente `usuario@máquina`). Compara: ¿cuál reconoces como tuya y cuál no encaja con el equipo?

Borra **sólo** la línea sospechosa (no el fichero entero: dejarías fuera a los usuarios legítimos):
```bash
sed -i '/<comentario-de-la-clave-intrusa>/d' ~/.ssh/authorized_keys
```
:::

## Paso 3 · ¿Qué se ejecuta solo cuando abres una shell?

**Pregúntate:** ¿qué ficheros lee bash al arrancar? Cualquier cosa ahí se ejecuta cada vez que alguien (tú incluido) abre una terminal.

**Por qué importa:** es persistencia "silenciosa": no hay proceso extraño corriendo, sólo una línea que se activa al iniciar sesión.

:::pista Cómo comprobarlo
```bash
tail -20 ~/.bashrc
grep -nE 'source|\. /|curl|wget|/dev/shm|/tmp' ~/.bashrc ~/.profile ~/.bash_profile /etc/bash.bashrc 2>/dev/null
ls -la /dev/shm
```
Busca un `source` o `.` que cargue un fichero de una ruta rara (`/dev/shm`, `/tmp`). Mira qué contiene ese fichero **antes** de borrarlo: es evidencia.

Quita las líneas de la trampa del `.bashrc` y después borra el payload.
:::

:::ojo Orden
Quita primero la línea que carga el payload y después el payload. Si lo haces al revés no pasa nada grave aquí, pero acostúmbrate: **primero el mecanismo, después el artefacto**.
:::

## Paso 4 · Cierra la puerta al origen

**Pregúntate:** aunque ya no tenga llave ni trampa, ¿puede seguir *intentándolo* desde la misma IP?

**Por qué importa:** bloquear el origen compra tiempo mientras terminas la investigación.

:::pista Cómo hacerlo
TCP wrappers usan `/etc/hosts.deny` con el formato `servicio: IP`:
```bash
echo "sshd: <IP-del-paso-1>" | sudo tee -a /etc/hosts.deny
```
:::

## Paso 5 · Verifica

```bash
bash /opt/lab/check.sh
```
Si falla algo, el validador te dice qué objetivo. Vuelve a ese paso.

## Cómo actuar en una situación así

- **Cambiar la contraseña no expulsa a nadie.** Revisa siempre: claves SSH, dotfiles, cron, servicios systemd y cuentas nuevas.
- **Busca en todos los sitios del mismo tipo**, no sólo en el primero que encuentres: `.bashrc`, `.profile`, `.bash_profile`, `/etc/bash.bashrc`, `/etc/profile.d/`.
- **Guarda evidencia antes de borrar** (copia el payload a una carpeta de root): sirve para entender qué hacía y buscarlo en otras máquinas.
- `/dev/shm` y `/tmp` son escribibles por todos: los primeros sitios donde mirar.

## Si te atascas

- No encuentras la IP: filtra con `grep Accepted /var/log/auth.log`.
- No ves la trampa: el `tail` del `.bashrc` suele bastar; la trampa se añade al final.
- El validador sigue fallando en el objetivo 3: comprueba que no queda **ninguna** línea que mencione el payload (`grep -n shm ~/.bashrc`).
