# Resolución guiada · Lab 156

:::piensa Dos capas: disco y mapper
El loop es el disco cifrado (ruido). El mapper es la vista descifrada. Formateas
y montas el mapper; el loop nunca se monta directo.
:::

## Paso 1 · Loop y cifrado

:::pista Cómo hacerlo
```bash
LOOP=$(sudo losetup -fP --show /srv/secure/vault.img)
sudo cryptsetup luksFormat --type luks2 "$LOOP" /etc/allsafe/luks.key
```
`luksFormat` escribe la cabecera LUKS y cifra el dispositivo con una clave
maestra nueva, protegida por la del fichero. **Borra** lo que hubiera: por
eso pide confirmar con `YES` en mayúsculas (o `--batch-mode`, que no pregunta).
:::

## Paso 2 · Abrir el volumen

:::pista Cómo hacerlo
```bash
sudo cryptsetup luksOpen "$LOOP" vault --key-file /etc/allsafe/luks.key
ls -l /dev/mapper/vault
```
`luksOpen` desbloquea el volumen y crea `/dev/mapper/vault`: un dispositivo
que se lee y escribe ya descifrado (`dm-crypt` cifra y descifra al vuelo).
`vault` es el nombre del mapper; elígelo tú.
:::

## Paso 3 · Formatear y montar el mapper

**Pregúntate:** ¿formateo `$LOOP` o `/dev/mapper/vault`? El mapper. Formatear el
loop machacaría la cabecera LUKS.

:::pista Cómo hacerlo
```bash
sudo mkfs.ext4 /dev/mapper/vault
sudo mkdir -p /mnt/vault && sudo mount /dev/mapper/vault /mnt/vault
echo "clientes" | sudo tee /mnt/vault/datos.txt
```
Compruébalo:
```bash
sudo cryptsetup isLuks "$LOOP" && echo "es LUKS"
sudo strings "$LOOP" | grep -c clientes
bash /opt/lab/check.sh
```
**Qué deberías ver:** `es LUKS` y `0`: en el disco físico no aparece el texto
en claro; sólo existe dentro del mapper.
:::

## Cómo actuar en una situación así

- Cifrado en reposo protege contra robo del disco, no contra un atacante con el
  volumen ya abierto. Cierra (`luksClose`) lo que no uses.
- La frase en fichero es solo para el lab; en producción usa TPM o prompt.

## Si te atascas

- `isLuks` falla: formateaste el dispositivo equivocado, o no corriste
  `luksFormat`.
- `mkfs` sobre `$LOOP` en vez del mapper: rehaz desde `luksFormat`.
- `No key available`: la clave no coincide; revisa `/etc/allsafe/luks.key`.
