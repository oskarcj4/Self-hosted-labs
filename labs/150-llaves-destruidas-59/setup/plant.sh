#!/usr/bin/env bash
# Lab 150 (Mr. Robot M9): el 5/9, las llaves destruidas.
# De madrugada, un ransomware borró /srv/datos (las "llaves" de E Corp). Por
# suerte existía una copia restic de la noche anterior. El alumno restaura,
# mide RTO/RPO y crea una copia INMUTABLE (3-2-1) para que no vuelva a pasar.
set -e
export HOME=/root
H=/home/analista
export RESTIC_REPOSITORY=/srv/backup/restic
export RESTIC_PASSWORD_FILE=/etc/restic/pass

install -d -m 0755 /srv/datos /srv/backup
install -d -m 0700 /etc/restic
echo 'fsociety-5-9' > /etc/restic/pass
chmod 0600 /etc/restic/pass

# --- datos críticos ("las llaves") -------------------------------------------
cat > /srv/datos/master.key <<'K'
-----BEGIN E-CORP MASTER KEY-----
MIIBVwIBADANBgkqhkiG9w0BAQEFAASC-ESTO-ES-CRITICO-NO-SE-PUEDE-PERDER
-----END E-CORP MASTER KEY-----
K
cat > /srv/datos/claves.gpg <<'G'
clientes.db: cifrado con master.key
nominas.db:  cifrado con master.key
G
# Huella esperada para el validador.
sha256sum /srv/datos/master.key | cut -d' ' -f1 > /etc/restic/.gt_masterkey

# --- copia restic de "anoche" (antes del ataque) ------------------------------
restic init >/dev/null 2>&1
restic backup /srv/datos >/dev/null 2>&1

# --- 5/9: el ransomware destruye los datos ------------------------------------
rm -rf /srv/datos
install -d -m 0755 /srv/datos
echo 'TODOS TUS FICHEROS HAN SIDO BORRADOS. -fsociety' > /srv/datos/LEEME.txt
touch -d "$(date +%Y-%m-%d) 05:09:00" /srv/datos/LEEME.txt

chown -R analista:analista /srv/offsite 2>/dev/null || true

# Al apagar el lab, quitar la inmutabilidad de /srv/offsite para que el volumen
# se pueda limpiar (si no, 'docker compose down -v' deja el volumen huérfano).
cat > /etc/systemd/system/offsite-unlock.service <<'U'
[Unit]
Description=Libera la inmutabilidad de /srv/offsite al apagar (limpieza del lab)
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/sh -c 'chattr -R -i /srv/offsite 2>/dev/null || true'
[Install]
WantedBy=multi-user.target
U
systemctl enable --now offsite-unlock.service

mkdir -p $H/ticket
cat > $H/ticket/DR-150.txt <<'TXT'
DR-150 · ecorp-150 · 05:09 — "nos borraron todo"
/srv/datos quedó vacío (sólo un LEEME de fsociety). Existe una copia restic de
anoche. Recupera y refuerza para la próxima.

Repo restic:   /srv/backup/restic
Contraseña:    /etc/restic/pass   (export RESTIC_PASSWORD_FILE=/etc/restic/pass)
  export RESTIC_REPOSITORY=/srv/backup/restic

1. Restaura /srv/datos desde la última instantánea restic. Verifica que
   master.key y claves.gpg vuelven intactos.
2. Aplica 3-2-1: crea una copia del repositorio en /srv/offsite y hazla
   INMUTABLE (chattr +i), de modo que un segundo ataque no pueda borrarla.
3. ~/plan-321.txt: explica tus 3 copias, 2 medios y 1 fuera de sitio.
TXT
chown -R analista:analista $H/ticket
echo "Lab 150 plantado."
