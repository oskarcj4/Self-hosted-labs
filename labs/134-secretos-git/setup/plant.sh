#!/usr/bin/env bash
# Lab 134: un repositorio con credenciales en su historial (y una todavía en
# el código actual). Las credenciales se generan al azar en cada lab.
set -e
R=/srv/repos/pagos
B=/var/lib/boveda
mkdir -p $R $B
read -r AKID ASEC GHP SKL <<<"$(python3 - <<'PY'
import secrets, string
U = string.ascii_uppercase + string.digits
A = string.ascii_letters + string.digits
r = lambda al, n: "".join(secrets.choice(al) for _ in range(n))
print("AKIA" + r(U, 16), r(A + "/+", 40), "ghp_" + r(A, 36), "sk_" + "live_" + r(A, 24))
PY
)"
# La "bóveda" sólo guarda huellas de las credenciales emitidas.
for s in "$AKID" "$GHP" "$SKL"; do printf '%s' "$s" | sha256sum | cut -d' ' -f1; done > $B/emitidas
: > $B/revocadas
chown -R analista:analista $B
cat > /usr/local/bin/rotar-secreto <<'X'
#!/bin/bash
# Revoca una credencial filtrada en el proveedor y emite una nueva.
# Uso: rotar-secreto <valor de la credencial filtrada>
B=/var/lib/boveda
[ -n "$1" ] || { echo "Uso: rotar-secreto <credencial>"; exit 2; }
h=$(printf '%s' "$1" | sha256sum | cut -d' ' -f1)
grep -qx "$h" $B/emitidas || { echo "✗ Esa credencial no existe en ningún proveedor."; exit 1; }
grep -qx "$h" $B/revocadas && { echo "Ya estaba revocada."; exit 0; }
echo "$h" >> $B/revocadas
echo "✓ Revocada. Nueva credencial emitida y guardada en el gestor de secretos (no en el repo)."
X
chmod 755 /usr/local/bin/rotar-secreto

g(){ sudo -u analista env GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git -C $R "${@:2}"; }
chown analista:analista $R
sudo -u analista git -C $R init -q -b main
sudo -u analista git -C $R config user.name "Dev Pagos"
sudo -u analista git -C $R config user.email "dev@empresa.lab"
w(){ mkdir -p "$(dirname "$R/$1")"; cat > "$R/$1"; chown -R analista:analista $R; }

printf '# Servicio de pagos\n' | w README.md
printf 'import os\nfrom config import settings\nprint("pagos arriba")\n' | w app.py
printf 'DB_URL = "postgresql://pagos@db/pagos"\n' | w config/settings.py
g "2024-02-01T10:00:00" add -A; g "2024-02-01T10:00:00" commit -qm "Estructura inicial"

printf 'AWS_ACCESS_KEY_ID = "%s"\nAWS_SECRET_ACCESS_KEY = "%s"\nBUCKET = "pagos-recibos"\n' "$AKID" "$ASEC" | w config/aws.py
g "2024-03-10T12:30:00" add -A; g "2024-03-10T12:30:00" commit -qm "Subida de recibos a S3"
C_AWS=$(sudo -u analista git -C $R rev-parse HEAD)

printf 'import os\nAWS_ACCESS_KEY_ID = os.environ["AWS_ACCESS_KEY_ID"]\nAWS_SECRET_ACCESS_KEY = os.environ["AWS_SECRET_ACCESS_KEY"]\nBUCKET = "pagos-recibos"\n' | w config/aws.py
g "2024-03-11T09:00:00" add -A; g "2024-03-11T09:00:00" commit -qm "Quitar credenciales de AWS del código"

printf '#!/bin/bash\n# Despliegue: descarga la última release\nGITHUB_TOKEN=%s\ncurl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/empresa/pagos/releases/latest\n' "$GHP" | w deploy.sh
g "2024-05-02T17:45:00" add -A; g "2024-05-02T17:45:00" commit -qm "Script de despliegue"
C_GHP=$(sudo -u analista git -C $R rev-parse HEAD)

printf 'STRIPE_KEY=%s\nDEBUG=false\n' "$SKL" | w .env
printf 'Tests de integración con la pasarela.\n' | w tests/README.md
g "2024-06-15T11:20:00" add -A; g "2024-06-15T11:20:00" commit -qm "Integración con la pasarela de pagos"
C_SK=$(sudo -u analista git -C $R rev-parse HEAD)

sudo -u analista git -C $R rm -q --cached .env
printf '.env\n' | w .gitignore
g "2024-06-16T08:10:00" add -A; g "2024-06-16T08:10:00" commit -qm "Ignorar .env"
rm -f $R/.env

printf '%s\n' "$C_AWS" "$C_GHP" "$C_SK" > /opt/lab/.ref-commits
chmod 600 /opt/lab/.ref-commits

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-134.txt <<'TXT'
SEC-134 · dev-134 · repositorio /srv/repos/pagos
Este repositorio se va a publicar. Alguien dice que "hace tiempo" se
subieron credenciales "pero ya se borraron". Comprueba el historial completo.
1. Escanea con gitleaks (y si quieres, trufflehog) y guarda el informe en ~/gitleaks.json.
2. En ~/secretos.txt, para cada credencial: tipo y commit donde se introdujo.
3. Rota cada credencial filtrada con: rotar-secreto <valor>
4. Que el código actual no tenga ninguna credencial y que un hook pre-commit
   con gitleaks impida volver a commitear una.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 134 plantado."
