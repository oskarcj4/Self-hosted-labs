# Resolución guiada · Lab 211

:::piensa Acceso ≠ datos
Cambiar quién puede abrir la bóveda es barato (keyslots). Recifrar los datos es
caro. Revocar una clave filtrada es **añadir la nueva, comprobar que funciona y
sólo entonces quitar la vieja**.
:::

## Paso 1 · Mira los keyslots

:::pista Cómo hacerlo
```bash
sudo cryptsetup luksDump /srv/disks/tc211-boveda.img
```
Verás dos keyslots activos (la clave filtrada y el keyfile del sobre).
:::

## Paso 2 · Abre y monta

:::pista Cómo hacerlo
```bash
sudo cryptsetup open /srv/disks/tc211-boveda.img boveda --key-file /root/sobre/boveda.key
sudo mkdir -p /boveda && sudo mount /dev/mapper/boveda /boveda
```
:::

## Paso 3 · Llave nueva del equipo

**Pregúntate:** ¿quién debe poder leer este fichero? ¿Qué modo le das?

:::pista Cómo hacerlo
```bash
sudo mkdir -p /etc/luks
sudo sh -c 'head -c 64 /dev/urandom > /etc/luks/boveda.key && chmod 400 /etc/luks/boveda.key'
sudo cryptsetup luksAddKey /srv/disks/tc211-boveda.img /etc/luks/boveda.key --key-file /root/sobre/boveda.key
```
:::

## Paso 4 · Revoca la filtrada

:::pista Cómo hacerlo
```bash
sudo cryptsetup luksRemoveKey /srv/disks/tc211-boveda.img
# escribe: Verano2023
printf %s Verano2023 | sudo cryptsetup open --test-passphrase --key-file - /srv/disks/tc211-boveda.img || echo revocada
```
Prueba **antes** que el keyfile nuevo abre; si no, te quedas fuera.
:::

## Paso 5 · Cabecera y automatización

:::pista Cómo hacerlo
```bash
sudo cryptsetup luksHeaderBackup /srv/disks/tc211-boveda.img --header-backup-file ~/boveda.header
sudo chown analista: ~/boveda.header; chmod 600 ~/boveda.header
echo 'boveda  /srv/disks/tc211-boveda.img  /etc/luks/boveda.key  luks,nofail' | sudo tee -a /etc/crypttab
echo '/dev/mapper/boveda  /boveda  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
```
:::

## Cómo actuar en una situación así

- Rotación: añade → prueba → revoca. Nunca al revés.
- Copia de cabecera fuera del servidor y cifrada. Restaurar: `cryptsetup luksHeaderRestore`.
- Un keyfile en el mismo disco que la bóveda anula el cifrado en reposo: en producción, TPM/KMS/clevis.

## Si te atascas

- "No key available with this passphrase": usaste texto con salto de línea; con `--key-file -` y `printf %s`.
- "Not enough available memory": `--pbkdf pbkdf2`.
