# Solución — Disco cifrado con LUKS

## Pasos

```bash
IMG=/srv/secure/vault.img
KEY=/etc/allsafe/luks.key

# 1) Dispositivo de bloque
LOOP=$(sudo losetup -fP --show "$IMG")

# 2) Cifrar con LUKS2 (--batch-mode no pregunta "YES"; destruye lo anterior)
sudo cryptsetup luksFormat --type luks2 --batch-mode "$LOOP" "$KEY"

# 3) Abrir -> /dev/mapper/vault
sudo cryptsetup luksOpen "$LOOP" vault --key-file "$KEY"

# 4) Formatear y montar el MAPPER (no el loop)
sudo mkfs.ext4 /dev/mapper/vault
sudo mkdir -p /mnt/vault && sudo mount /dev/mapper/vault /mnt/vault

# 5) Datos
echo "clientes" | sudo tee /mnt/vault/datos.txt
```

## Qué está pasando por debajo

- `luksFormat` escribe la **cabecera LUKS** en el dispositivo: metadatos +
  ranuras de claves. La clave maestra que cifra los datos está envuelta por tu
  frase; cambiar la frase no recifra el disco (solo reenvuelve la maestra).
- `luksOpen` deriva la clave, abre un dispositivo `dm-crypt` en
  `/dev/mapper/vault`. Leer/escribir ahí se cifra/descifra al vuelo.
- El disco físico (`$LOOP`) solo contiene ruido. `sudo head -c 64 "$LOOP" | xxd`
  no muestra tus datos.

## Cerrar y persistir

```bash
sudo umount /mnt/vault
sudo cryptsetup luksClose vault      # desaparece el mapper; datos en claro fuera
```

Para montar al arranque: `/etc/crypttab` (abre el volumen) + `/etc/fstab`
(monta `/dev/mapper/vault`). En servidores reales la clave no va en un fichero
plano: se usa TPM, un token, o se pide la frase en el arranque.

## Más allá del lab

- `cryptsetup luksDump "$LOOP"`: inspecciona cabecera y ranuras de claves.
- `cryptsetup luksAddKey` / `luksKillSlot`: rotación de frases sin recifrar.
- LUKS2 soporta argon2id (resistente a fuerza bruta por hardware).
