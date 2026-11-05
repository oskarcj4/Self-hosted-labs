#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
export RESTIC_REPOSITORY=/srv/backup/restic
export RESTIC_PASSWORD_FILE=/etc/restic/pass

# 1) Restaurar desde la última instantánea
restic snapshots
restic restore latest --target / >/dev/null
ls -l /srv/datos
rm -f /srv/datos/LEEME.txt

# 2) Copia inmutable fuera de sitio (3-2-1)
install -d -m 0755 /srv/offsite
cp -a /srv/backup/restic /srv/offsite/restic
chattr -R +i /srv/offsite/restic
lsattr -d /srv/offsite/restic

# 3) Plan
cat > $H/plan-321.txt <<'P'
Regla 3-2-1 aplicada a las llaves de E Corp:
- 3 copias: los datos vivos en /srv/datos, el repositorio restic en /srv/backup
  y la copia fuera de sitio en /srv/offsite.
- 2 medios: disco local del servidor y volumen ext4 independiente (offsite).
- 1 fuera de sitio e INMUTABLE: /srv/offsite/restic con chattr +i, de modo que
  un segundo ataque de ransomware no pueda cifrarla ni borrarla.
Verificación periódica: restic check + restauración de prueba (mide RTO/RPO).
P
chown analista:analista $H/plan-321.txt
echo "solve.sh completado."
