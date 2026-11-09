# Bóveda LUKS: rotar claves y no perder la cabecera

> LUKS2 · keyslots · luksAddKey · luksRemoveKey · luksHeaderBackup · crypttab

## Escenario

La bóveda de nóminas (`/srv/disks/tc211-boveda.img`) es un contenedor LUKS2.
Un exempleado la abría con la clave `Verano2023`, que acabó pegada en un chat.
Existe además un keyfile de emergencia en `/root/sobre/boveda.key`.

LUKS no cifra con "la contraseña": cifra con una **clave maestra** y cada
contraseña/keyfile es un *keyslot* que la desbloquea. Por eso puedes añadir y
revocar acceso sin recifrar los datos. Y por eso, si se daña la cabecera,
**todo se pierde** aunque sepas la contraseña: hay que respaldarla.

> El lab 156 enseña a cifrar un disco desde cero. Aquí se **opera** uno existente.

## Objetivos

1. Abre la bóveda con el keyfile del sobre (mapper `boveda`) y móntala en `/boveda`.
2. Crea `/etc/luks/boveda.key` (root, `0400`, 64 bytes aleatorios) y añádelo como keyslot.
3. Revoca la clave filtrada: `Verano2023` ya no debe abrir nada.
4. Copia la cabecera a `~/boveda.header` (modo `0600`).
5. Apertura automática: línea en `/etc/crypttab` (con el keyfile) y en `/etc/fstab`, ambas con `nofail`.

## Comandos que te pueden servir

```bash
sudo cryptsetup luksDump /srv/disks/tc211-boveda.img
sudo cryptsetup open IMG boveda --key-file /root/sobre/boveda.key
sudo cryptsetup luksAddKey IMG /etc/luks/boveda.key --key-file /root/sobre/boveda.key
sudo cryptsetup luksRemoveKey IMG            # pide la clave a eliminar
sudo cryptsetup luksHeaderBackup IMG --header-backup-file ~/boveda.header
# crypttab:  <nombre> <dispositivo> <keyfile> <opciones>
```

> Si `luksAddKey` falla por falta de memoria (argon2), añade `--pbkdf pbkdf2`.
> Nunca guardes la copia de la cabecera junto al disco: quien tenga cabecera +
> una contraseña vieja puede descifrar. Guárdala cifrada y fuera del equipo.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
