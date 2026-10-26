# Resolución guiada · Migración de datos con rsync

:::piensa Antes de tocar nada
Objetivo: `/srv/media` en new-srv **idéntico** al de old-srv. Tres trampas
clásicas: `-a` **no** copia hardlinks (hace falta `-H`); los UIDs no coinciden
entre máquinas (copia por **nombre**, nunca `--numeric-ids`); y la barra final
del origen cambia todo. Y siempre ensaya con `-n` antes de borrar nada con
`--delete`.
:::

## Paso 1 · Reconocimiento

**Pregúntate:** ¿coinciden los UIDs? ¿qué restos dejó el intento anterior?

:::pista Cómo verlo
```bash
ssh migra@old-srv 'ls -lan /srv/media/fotos/destacadas'   # media = UID 1500 allí
id media                     # uid=2001 aquí  -> NO coincide
getent passwd 1500           # auditor  -> ese UID es otro usuario aquí
sudo ls -laR /srv/media      # restos: obsoleto/, tmp-copia/, ficheros a medias
```
:::

## Paso 2 · Por qué root en los dos lados

- **Origen**: `docs/privado/` es 0750 y la nómina 0600; `migra` no los lee, por
  eso `--rsync-path='sudo rsync'`.
- **Destino**: sólo root crea ficheros a nombre de otro usuario; sin root, todo
  queda tuyo.

## Paso 3 · Dry-run primero

**Pregúntate:** ¿qué va a tocar y a borrar antes de hacerlo?

:::pista Cómo hacerlo
```bash
sudo rsync -aHn --delete -i --rsync-path='sudo rsync' \
     migra@old-srv:/srv/media/ /srv/media/
```
En la salida `-i`, las líneas `*deleting ...` son los restos que quitará.
Revísalos antes de quitar la `-n`.
:::

## Paso 4 · La copia

:::pista El comando y por qué cada opción
```bash
sudo rsync -aH --delete --info=stats1 --rsync-path='sudo rsync' \
     migra@old-srv:/srv/media/ /srv/media/
```
| Opción | Para qué |
|---|---|
| `-a` | recursivo + permisos + dueños/grupos + mtimes + symlinks como symlinks |
| `-H` | hardlinks como hardlinks (**`-a` no lo hace**) |
| `--delete` | borra del destino lo que no está en el origen (restos) |
| `/srv/media/` | con barra copia el **contenido**; sin barra crearía `/srv/media/media` |
| sin `--numeric-ids` | rsync manda **nombres** y el destino los traduce a sus UIDs |

Con `--numeric-ids`, los ficheros de `media` (1500 allí) quedarían a nombre de
`auditor` (1500 aquí): error silencioso y peligroso. `--numeric-ids` sólo vale
restaurando en la **misma** máquina o en un chroot.
:::

## Paso 5 · Verificación independiente

```bash
# Segunda pasada: no debería transferir nada
sudo rsync -aHn --delete -i --rsync-path='sudo rsync' migra@old-srv:/srv/media/ /srv/media/
# Con checksums (no se fía de tamaño+mtime)
sudo rsync -aHnc --delete -i --rsync-path='sudo rsync' migra@old-srv:/srv/media/ /srv/media/
ls -li /srv/media/fotos/destacadas/portada.jpg /srv/media/fotos/2026/img-007.jpg  # mismo inodo
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Migración real en dos pasadas**: una en caliente (larga) y otra corta con
  el servicio parado; luego cambias DNS/IP.
- **`-a` no basta**: hardlinks `-H`; ACL/xattr `-A`/`-X` si los usas.
- **UID = lo que guarda el disco; nombre = lo que ves.** Entre máquinas no tienen
  por qué coincidir.
- **`--delete` con `-n` primero. Siempre.**

## Si te atascas

- Ficheros con dueño equivocado → usaste `--numeric-ids`; quítalo y repite.
- Apareció `/srv/media/media` → te sobró/faltó la barra; usa `/srv/media/` en
  origen.
- Los hardlinks se duplicaron → faltó `-H`.
