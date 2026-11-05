# Disco cifrado con LUKS

> Almacenamiento · cifrado en reposo · cryptsetup · LUKS2 · dm-crypt

## Escenario

Los datos sensibles de Allsafe deben ir **cifrados en reposo**: si alguien roba
el disco, no debe poder leer nada. Llega un disco sin cifrar en
`/srv/secure/vault.img` (320 MiB). La frase de cifrado te la dieron en
`/etc/allsafe/luks.key`.

**LUKS** (Linux Unified Key Setup) cifra a nivel de bloque con `dm-crypt`. El
flujo: cifras el dispositivo (`luksFormat`), lo abres con la clave (`luksOpen`,
crea un `/dev/mapper/...`), y trabajas sobre ese mapper descifrado. En el disco
físico solo hay ruido; los datos en claro solo existen mientras el volumen está
abierto.

## Objetivos

1. Conecta la imagen como loop: `sudo losetup -fP --show /srv/secure/vault.img`.
2. Cífrala: `sudo cryptsetup luksFormat --type luks2 /dev/loopN /etc/allsafe/luks.key`.
3. Ábrela: `sudo cryptsetup luksOpen /dev/loopN vault --key-file /etc/allsafe/luks.key`
   → aparece `/dev/mapper/vault`.
4. Formatea y monta el **mapper** (no el loop) en `/mnt/vault`, en ext4.
5. Escribe datos sensibles dentro.

## Pistas

```bash
LOOP=$(sudo losetup -fP --show /srv/secure/vault.img)
sudo cryptsetup luksFormat --type luks2 "$LOOP" /etc/allsafe/luks.key
sudo cryptsetup luksOpen "$LOOP" vault --key-file /etc/allsafe/luks.key
sudo mkfs.ext4 /dev/mapper/vault
sudo mkdir -p /mnt/vault && sudo mount /dev/mapper/vault /mnt/vault
sudo cryptsetup isLuks "$LOOP" && echo "es LUKS"
sudo cryptsetup luksDump "$LOOP" | head
```

> Montas el **mapper** descifrado, nunca el `/dev/loopN` directamente: ese solo
> contiene datos cifrados. Al cerrar con `cryptsetup luksClose vault`, los datos
> en claro desaparecen.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
