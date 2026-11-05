# Solución — El 5/9: llaves destruidas

## Qué pasaba

Un ransomware vació `/srv/datos` (master.key, claves.gpg) a las 05:09 y dejó
una nota de fsociety. Existía una copia restic de la noche anterior en
`/srv/backup/restic` (contraseña en `/etc/restic/pass`). Faltaba una copia
inmutable fuera de sitio.

## Arreglo

```bash
export RESTIC_REPOSITORY=/srv/backup/restic
export RESTIC_PASSWORD_FILE=/etc/restic/pass

# 1) Restaurar y verificar
restic snapshots
restic restore latest --target /
sha256sum /srv/datos/master.key          # intacto
rm -f /srv/datos/LEEME.txt               # fuera la nota del ataque

# 2) Copia inmutable fuera de sitio (3-2-1)
sudo cp -a /srv/backup/restic /srv/offsite/restic
sudo chattr -R +i /srv/offsite/restic
lsattr -d /srv/offsite/restic            # ----i---------

# 3) Documentar el plan
cat > ~/plan-321.txt <<'P'
3 copias: datos vivos (/srv/datos), repo restic (/srv/backup), copia offsite (/srv/offsite)
2 medios: disco del servidor + volumen ext4 independiente
1 fuera de sitio e inmutable: /srv/offsite/restic con chattr +i
Verificación: restic check + restauración de prueba (RTO/RPO medidos)
P
bash /opt/lab/check.sh
```

## Más allá del lab

- **Inmutabilidad real**: en S3/MinIO, Object Lock (modo COMPLIANCE/WORM) y
  retención; restic sobre un backend append-only. `chattr +i` es el equivalente
  local para este lab.
- Para actualizar la copia inmutable hay que levantar el `+i` primero
  (`chattr -i`), copiar, y volver a fijarlo: eso obliga a un proceso controlado.
- Mide y prueba: una restauración no ensayada es un RTO desconocido. La regla
  3-2-1 sin pruebas periódicas es papel mojado.
