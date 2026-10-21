#!/usr/bin/env bash
# Lab 68 (new-srv): destino de la migración. 'media' tiene otro UID que en
# old-srv, y el UID 1500 aquí es de otro usuario. Quedan restos de un intento
# de copia anterior que se cortó.
set -e
install -m 0755 /opt/lab/setup/manifest.py /usr/local/lib/tclab-manifest.py
groupadd -g 2001 media
useradd -u 2001 -g 2001 -M -s /usr/sbin/nologin media
useradd -u 1500 -M -s /usr/sbin/nologin auditor
M=/srv/media
mkdir -p $M/fotos/2026 $M/obsoleto $M/tmp-copia
head -c 4096 /dev/urandom > $M/fotos/2026/img-003.jpg      # copia cortada a medias
echo "prueba de copia del 3 de octubre, borrar" > $M/obsoleto/borrar.txt
head -c 9000 /dev/urandom > $M/tmp-copia/.img-004.jpg.Xr2a1  # temporal de rsync
chown -R root:root $M

for _ in $(seq 1 60); do curl -fs --max-time 2 http://old-srv:9100/manifest | grep -q 'releases' && break; sleep 1; done

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/MIG-6808.txt <<'EOF'
MIG-6808 · migración de /srv/media: old-srv -> new-srv (este servidor)
- old-srv se apaga el viernes. Copia old-srv:/srv/media a /srv/media aquí.
- Acceso:  ssh migra@old-srv   (contraseña: Migra-2026)
  migra puede ejecutar 'sudo rsync' sin contraseña en old-srv (y nada más).
- Requisitos:
  * Mismo contenido, permisos y fechas de modificación.
  * Dueños y grupos POR NOMBRE: 'media' es el UID 1500 en old-srv y el 2001
    aquí (aquí el 1500 es 'auditor').
  * Los hardlinks de fotos/destacadas siguen siendo hardlinks (no dupliques).
  * Los enlaces simbólicos se copian como enlaces, no como copias.
  * El destino tiene restos de un intento anterior que se cortó: al terminar,
    /srv/media debe ser IDÉNTICO al origen (ni más ni menos).
  * old-srv no se toca: es la fuente de verdad hasta el viernes.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 68 plantado."
