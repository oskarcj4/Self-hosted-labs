# El 5/9: llaves destruidas

> Mr. Robot · continuidad · restic · restauración · 3-2-1 · inmutabilidad

## Escenario

05:09. Igual que en el 5/9 de E Corp, un ransomware barrió `/srv/datos`: las
llaves maestras y los índices cifrados. Sólo queda una nota de fsociety. La
buena noticia: anoche corrió una copia **restic**. La mala: si la copia fuera
borrable, el siguiente ataque también se la lleva.

- **restic** hace copias deduplicadas y cifradas. `restic restore latest`
  recupera la última instantánea; `restic snapshots` las lista.
- **3-2-1**: 3 copias de los datos, en 2 medios distintos, 1 de ellas fuera de
  sitio. Es lo que convierte "nos borraron todo" en "restauramos en minutos".
- **Inmutabilidad**: una copia que no se puede modificar ni borrar aguanta al
  ransomware. Aquí, `chattr +i` sobre un volumen que lo soporta; en la nube,
  Object Lock (WORM) de S3/MinIO.

## Objetivos

1. Restaura `/srv/datos` desde la última instantánea restic. Verifica que
   `master.key` y `claves.gpg` vuelven intactos, y borra la nota del ataque.
2. Crea una copia del repositorio en `/srv/offsite` y hazla **inmutable**
   (`chattr +i`), de forma que un segundo ataque no pueda tocarla.
3. `~/plan-321.txt`: describe tus 3 copias, 2 medios y 1 fuera de sitio.

## Comandos que te pueden servir

```bash
export RESTIC_REPOSITORY=/srv/backup/restic
export RESTIC_PASSWORD_FILE=/etc/restic/pass
restic snapshots
restic restore latest --target /          # restaura /srv/datos en su sitio
sha256sum /srv/datos/master.key
sudo cp -a /srv/backup/restic /srv/offsite/restic
sudo chattr -R +i /srv/offsite/restic     # inmutable
lsattr -d /srv/offsite/restic
sudo chattr -R -i /srv/offsite/restic     # (para poder actualizarla después)
```

> La copia que nunca se prueba no es una copia: es una esperanza. Mide tu RTO
> (cuánto tardas en restaurar) y tu RPO (cuánto dato pierdes entre copias).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
