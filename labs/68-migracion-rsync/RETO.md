# Migración de datos con rsync

> Operaciones · rsync · SSH · dueños y UIDs · hardlinks

## Escenario

`old-srv` se apaga el viernes y hay que llevar `/srv/media` a `new-srv` (este
servidor). Alguien lo intentó la semana pasada y la copia se cortó: el destino
tiene restos. Lee `~/ticket/MIG-6808.txt`.

## Objetivos

Que `/srv/media` en `new-srv` sea **idéntico** al de `old-srv`:

1. Mismo contenido, permisos y fechas de modificación.
2. Dueños y grupos **por nombre**. `media` no tiene el mismo UID en los dos
   servidores.
3. Los hardlinks siguen siendo hardlinks; los enlaces simbólicos, enlaces.
4. Ni más ni menos: lo que no está en el origen, fuera.
5. `old-srv` no se modifica.

## Comandos que te pueden servir

```bash
ssh migra@old-srv 'sudo rsync --version | head -1; ls -la /srv/media'
id media ; getent passwd 1500
man rsync        # -a -H --delete -n (--dry-run) -i (--itemize-changes) --numeric-ids --rsync-path
sudo rsync -aHn --delete -i --rsync-path='sudo rsync' migra@old-srv:/srv/media/ /srv/media/
ls -li /srv/media/fotos/destacadas /srv/media/fotos/2026/img-007.jpg
```

> Ensaya siempre con `-n` (`--dry-run`) y mira qué haría antes de hacerlo.
> Y cuidado con la barra final del origen: `/srv/media/` no es lo mismo que
> `/srv/media`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
