# Resolución guiada · Lab 211

:::piensa Acceso ≠ datos
LUKS no cifra los datos con tu contraseña. Cifra con una **clave maestra**
aleatoria, y cada contraseña o fichero de clave es una "llave" guardada en un
*keyslot* que desbloquea esa clave maestra. Por eso cambiar quién puede abrir
la bóveda es barato (añadir o quitar keyslots) y no hace falta recifrar nada.
Y por eso mismo, si se daña la cabecera donde viven los keyslots, **no hay
forma** de recuperar los datos aunque sepas la contraseña.
:::

**El plan:** (1) ver los keyslots, (2) abrir y montar, (3) añadir la llave
nueva, (4) revocar la filtrada, (5) respaldar la cabecera y (6) automatizar la
apertura.

## Paso 1 · ¿Qué keyslots hay?

:::pista Cómo hacerlo
```bash
sudo cryptsetup luksDump /srv/disks/tc211-boveda.img
```
`luksDump` enseña la cabecera LUKS: versión, algoritmo de cifrado y la lista
de keyslots ocupados.

**Qué deberías ver:** en `Keyslots:`, dos entradas (`0: luks2`, `1: luks2`):
la contraseña filtrada y el keyfile del sobre. No te dice cuál es cuál: eso
lo averiguas probando.
:::

## Paso 2 · Abre y monta

:::pista Cómo hacerlo
```bash
sudo cryptsetup open /srv/disks/tc211-boveda.img boveda --key-file /root/sobre/boveda.key
sudo mkdir -p /boveda
sudo mount /dev/mapper/boveda /boveda
ls /boveda
```
- `cryptsetup open IMG boveda` desbloquea el contenedor y crea
  `/dev/mapper/boveda`, un dispositivo que se lee ya descifrado.
- `--key-file` usa el contenido de un fichero como clave, en vez de pedirla
  por teclado.
:::

## Paso 3 · La llave nueva del equipo

**Pregúntate:** ¿quién debe poder leer el fichero de clave? ¿Con qué permisos?

:::pista Cómo hacerlo
Sólo root, y sólo lectura:
```bash
sudo mkdir -p /etc/luks
sudo sh -c 'head -c 64 /dev/urandom > /etc/luks/boveda.key && chmod 400 /etc/luks/boveda.key'
sudo cryptsetup luksAddKey /srv/disks/tc211-boveda.img /etc/luks/boveda.key \
  --key-file /root/sobre/boveda.key
```
- `head -c 64 /dev/urandom` son 64 bytes aleatorios: mucho más fuerte que
  cualquier contraseña.
- `sudo sh -c '…'` ejecuta toda la línea como root, redirección incluida (con
  `sudo head … > fichero`, la redirección la haría tu shell sin privilegios).
- `luksAddKey IMG <nueva>` añade un keyslot con la llave nueva; para
  autorizarlo hay que demostrar que ya tienes una válida (`--key-file` del
  sobre).

Si falla con `Not enough available memory`, añade `--pbkdf pbkdf2`: el
algoritmo por defecto (argon2) pide mucha memoria para frenar ataques de
fuerza bruta.

Comprueba que la llave nueva abre **antes** de quitar nada:
```bash
sudo cryptsetup open --test-passphrase --key-file /etc/luks/boveda.key /srv/disks/tc211-boveda.img && echo "la nueva abre"
```
`--test-passphrase` comprueba la clave sin abrir nada.
:::

## Paso 4 · Revoca la clave filtrada

:::pista Cómo hacerlo
```bash
printf %s 'Verano2023' | sudo cryptsetup luksRemoveKey /srv/disks/tc211-boveda.img --key-file -
printf %s 'Verano2023' | sudo cryptsetup open --test-passphrase --key-file - /srv/disks/tc211-boveda.img || echo "revocada"
```
- `luksRemoveKey` borra el keyslot que abre **esa** clave.
- `--key-file -` lee la clave de la entrada (`-`). `printf %s` la envía sin
  salto de línea final; con `echo`, el salto formaría parte de la clave y no
  coincidiría.

**Qué deberías ver:** `No key available with this passphrase` y `revocada`.
`luksDump` enseña ahora dos keyslots: el del sobre y el nuevo.
:::

## Paso 5 · Respalda la cabecera

:::pista Cómo hacerlo
```bash
sudo cryptsetup luksHeaderBackup /srv/disks/tc211-boveda.img --header-backup-file ~/boveda.header
sudo chown analista: ~/boveda.header
chmod 600 ~/boveda.header
```
La copia contiene los keyslots: con ella y cualquier clave que estuviera viva
**en el momento de la copia** se puede descifrar. Por eso se hace después de
revocar la filtrada, y se guarda cifrada y lejos del disco.
:::

## Paso 6 · Apertura automática

:::pista Cómo hacerlo
```bash
echo 'boveda  /srv/disks/tc211-boveda.img  /etc/luks/boveda.key  luks,nofail' | sudo tee -a /etc/crypttab
echo '/dev/mapper/boveda  /boveda  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
bash /opt/lab/check.sh
```
- `/etc/crypttab` dice qué contenedores abrir al arrancar: nombre, dispositivo,
  fichero de clave y opciones.
- `/etc/fstab` dice dónde montar el dispositivo ya abierto.
- `nofail` en los dos: si la bóveda no está, la máquina arranca igual.
:::

## Cómo actuar en una situación así

- Rotar es **añadir → probar → revocar**. Nunca al revés.
- La copia de la cabecera, fuera del servidor y cifrada. Se restaura con
  `cryptsetup luksHeaderRestore`.
- Un keyfile en el mismo equipo que la bóveda sólo protege si el disco sale
  solo de la máquina. En producción se usan TPM, KMS o `clevis`/`tang`.

## Si te atascas

- **`No key available with this passphrase` con una clave buena:** se coló un
  salto de línea. Usa `printf %s` y `--key-file -`.
- **`Not enough available memory`:** `--pbkdf pbkdf2` en `luksAddKey`.
- **`mount: wrong fs type`:** montaste la imagen, no `/dev/mapper/boveda`.
