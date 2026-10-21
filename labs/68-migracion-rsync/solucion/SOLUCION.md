# Solución — Migración de datos con rsync

## 1. Reconocimiento

```bash
ssh migra@old-srv 'ls -lan /srv/media /srv/media/fotos/destacadas'   # UID 1500
id media                     # uid=2001(media)
getent passwd 1500           # auditor   <- ¡otro usuario!
sudo ls -laR /srv/media      # restos: obsoleto/, tmp-copia/, img-003.jpg a medias
```

## 2. Por qué hay que ser root en los dos lados

- **Lado origen:** `docs/privado/` es 0750 `media:media` y la nómina es 0600.
  Como `migra` no puede leerlos, por eso existe `sudo rsync` en old-srv
  (`--rsync-path='sudo rsync'`).
- **Lado destino:** sólo root puede crear ficheros a nombre de otro usuario.
  Sin root, todo acaba siendo tuyo.

## 3. Dry-run primero

```bash
sudo rsync -aHn --delete -i --rsync-path='sudo rsync' \
     migra@old-srv:/srv/media/ /srv/media/
```

En la salida de `-i`, `*deleting obsoleto/borrar.txt` es lo que se va a
borrar. Revísalo antes de quitar la `-n`.

## 4. La copia

```bash
sudo rsync -aH --delete --info=stats1 --rsync-path='sudo rsync' \
     migra@old-srv:/srv/media/ /srv/media/
```

| Opción | Para qué |
|---|---|
| `-a` | recursivo + permisos + dueños/grupos + mtimes + enlaces simbólicos como enlaces + dispositivos |
| `-H` | hardlinks como hardlinks (`-a` **no** lo incluye) |
| `--delete` | borra del destino lo que no existe en el origen (los restos) |
| `/srv/media/` | con barra: copia el **contenido**. Sin barra crearía `/srv/media/media` |
| sin `--numeric-ids` | rsync manda los **nombres** y el destino los traduce a sus UIDs |

Con `--numeric-ids`, los ficheros de `media` (1500 en origen) quedarían a
nombre de `auditor` (1500 aquí). Es un error silencioso y peligroso.
`--numeric-ids` sólo tiene sentido al restaurar un backup en la **misma**
máquina o en un chroot.

## 5. Verificación independiente

```bash
# Una segunda pasada no debería transferir nada:
sudo rsync -aHn --delete -i --rsync-path='sudo rsync' migra@old-srv:/srv/media/ /srv/media/
# Checksums (más lento, pero no se fía de tamaño+mtime):
sudo rsync -aHnc --delete -i --rsync-path='sudo rsync' migra@old-srv:/srv/media/ /srv/media/
ls -li /srv/media/fotos/destacadas/portada.jpg /srv/media/fotos/2026/img-007.jpg   # mismo inodo
```

## Lecciones

- La migración real se hace en dos pasadas: una en caliente (larga) y otra
  corta con el servicio parado, que sólo copia los cambios. Luego se cambia
  el DNS o la IP.
- `-a` no basta: para hardlinks, `-H`; para ACL y xattr, `-A` y `-X` (si los
  usas).
- El UID es lo que guarda el disco; el nombre es lo que ves. Al cambiar de
  máquina, los UIDs no tienen por qué coincidir.
- `--delete` con `-n` primero. Siempre.
