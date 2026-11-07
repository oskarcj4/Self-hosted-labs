#!/usr/bin/env bash
# Lab 201: el estado de Terraform vive en el repo (terraform.tfstate en git,
# con la contraseña de la base de datos dentro). Hay un backend remoto con
# bloqueo y autenticación listo, y nadie lo usa.
set -e
H=/home/analista
I=$H/infra

# --- Servidor de estado remoto (HTTP con bloqueo y autenticación básica) -----
install -m 0755 /opt/lab/setup/tf-state-server /usr/local/bin/tf-state-server
useradd -r -s /usr/sbin/nologin tfstate
install -d -o tfstate -g tfstate -m 0750 /var/lib/tfstate
CLAVE=$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 20)
install -d -m 0750 /etc/tfstate
printf 'TFSTATE_USER=ci\nTFSTATE_PASSWORD=%s\n' "$CLAVE" > /etc/tfstate/servidor.env
chmod 0600 /etc/tfstate/servidor.env
cat > /etc/systemd/system/tf-state.service <<'U'
[Unit]
Description=Estado remoto de Terraform (backend HTTP con bloqueo y autenticación)
[Service]
User=tfstate
EnvironmentFile=/etc/tfstate/servidor.env
ExecStart=/usr/local/bin/tf-state-server /var/lib/tfstate 8500
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now tf-state
for _ in $(seq 1 20); do curl -s -o /dev/null http://127.0.0.1:8500/state/x && break; sleep 1; done
# Credenciales del analista para el backend (fuera del repo).
install -d -o analista -g analista -m 0700 $H/.config/tfstate
printf 'export TF_HTTP_USERNAME=ci\nexport TF_HTTP_PASSWORD=%s\n' "$CLAVE" > $H/.config/tfstate/credenciales
chown analista:analista $H/.config/tfstate/credenciales; chmod 0600 $H/.config/tfstate/credenciales
cp $H/.config/tfstate/credenciales /opt/lab/.credenciales; chmod 0600 /opt/lab/.credenciales

# --- La infraestructura (ficheros de config de la tienda en /srv/tienda) -----
install -d -o analista -g analista /srv/tienda
mkdir -p $I
cat > $I/main.tf <<'TF'
terraform {
  required_version = ">= 1.6"
  required_providers {
    local = { source = "hashicorp/local", version = "2.5.2" }
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "local_file" "nginx" {
  filename = "/srv/tienda/nginx.conf"
  content  = <<-EOT
    server {
      listen 80;
      location / { proxy_pass http://127.0.0.1:8080; }
    }
  EOT
}

resource "local_file" "app" {
  filename = "/srv/tienda/app.env"
  content  = "PUERTO=8080\nENTORNO=produccion\n"
}

resource "local_sensitive_file" "db" {
  filename        = "/srv/tienda/db.env"
  content         = "DB_USER=tienda\nDB_PASSWORD=${var.db_password}\n"
  file_permission = "0600"
}
TF
echo 'db_password = "Primavera2024!"' > $I/terraform.tfvars
echo "Primavera2024!" > /opt/lab/.clave-vieja; chmod 0600 /opt/lab/.clave-vieja
chown -R analista:analista $I
A(){ runuser -u analista -- env HOME=$H "$@"; }
A git -C $I init -q -b main
A git -C $I config user.name "Analista"; A git -C $I config user.email analista@tienda.local
A terraform -chdir=$I init -input=false >/dev/null
A terraform -chdir=$I apply -input=false -auto-approve >/dev/null
A git -C $I add main.tf terraform.tfvars terraform.tfstate .terraform.lock.hcl
A git -C $I commit -qm "infra de la tienda (con su estado, para que lo tenga todo el equipo)"

cat > $H/TAREA.txt <<'TXT'
TAREA · Estado remoto de Terraform

~/infra gestiona la config de la tienda (/srv/tienda) y su estado está en el
propio repo: terraform.tfstate en git. Cada uno trabaja con su copia, sin
bloqueo, y el estado lleva la contraseña de la base de datos en claro (mira
git show HEAD:terraform.tfstate | grep -i password).

Hay un backend remoto listo: http://127.0.0.1:8500/state/<nombre>
(backend "http" de Terraform, con LOCK/UNLOCK y autenticación básica).
Tus credenciales: ~/.config/tfstate/credenciales (variables TF_HTTP_*).

1. Configura el backend "http" en ~/infra, estado "tienda", con bloqueo
   (lock_address / unlock_address). Las credenciales NO van en el código.
2. Migra el estado actual al backend sin recrear nada: después,
   terraform plan no debe proponer cambios.
3. Fuera el estado del repo: ni terraform.tfstate ni sus copias en git ni
   en ~/infra, y un .gitignore para que no vuelva (*.tfstate, *.tfstate.*,
   .terraform/). Haz commit.
4. La contraseña ha estado en git: rótala. Nueva contraseña fuera del repo
   (por ejemplo TF_VAR_db_password o un .tfvars ignorado) y aplica.
   La variable se sigue llamando db_password.

Cualquier compañero que clone el repo y haga init + plan debe ver el mismo
estado (sin cambios), y si otro está aplicando, esperar al bloqueo.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 201 plantado."
