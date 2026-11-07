#!/usr/bin/env bash
# Lab 202: un módulo de Terraform que usan todos los servicios, sin una sola
# prueba. Ya hay un bug en producción (los upstream apuntan a 8080 siempre).
set -e
H=/home/analista
I=$H/infra
M=$I/modules/servicio
mkdir -p $M $I/ci /opt/lab/tests

cat > $M/versions.tf <<'TF'
terraform {
  required_version = ">= 1.9"
  required_providers {
    local = { source = "hashicorp/local", version = "2.5.2" }
  }
}
TF
cat > $M/variables.tf <<'TF'
variable "nombre" {
  type        = string
  description = "Nombre del servicio (DNS y ficheros)."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.nombre))
    error_message = "nombre: minúsculas, números y guiones; empieza por letra; 3-31 caracteres."
  }
}

variable "puerto" {
  type        = number
  description = "Primer puerto de las réplicas (réplica i escucha en puerto + i)."
  validation {
    condition     = var.puerto >= 1024 && var.puerto <= 65535
    error_message = "puerto: entre 1024 y 65535."
  }
}

variable "entorno" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.entorno)
    error_message = "entorno: dev, staging o prod."
  }
}

variable "replicas" {
  type    = number
  default = 1
  validation {
    condition     = var.replicas >= 1 && (var.entorno != "prod" || var.replicas >= 2)
    error_message = "replicas: al menos 1, y al menos 2 en prod."
  }
}

variable "directorio" {
  type    = string
  default = "/srv/servicios"
}
TF
cat > $M/main.tf <<'TF'
locals {
  puertos = [for i in range(var.replicas) : 8080 + i]
}

resource "local_file" "nginx" {
  filename = "${var.directorio}/${var.nombre}.conf"
  content = templatefile("${path.module}/nginx.conf.tftpl", {
    nombre  = var.nombre
    puertos = local.puertos
  })
}

resource "local_file" "env" {
  filename = "${var.directorio}/${var.nombre}.env"
  content  = "SERVICIO=${var.nombre}\nENTORNO=${var.entorno}\nPUERTO=${var.puerto}\n"
}

output "nginx_conf" {
  value = local_file.nginx.content
}

output "env" {
  value = local_file.env.content
}
TF
cat > $M/nginx.conf.tftpl <<'T'
upstream ${nombre} {
%{ for p in puertos ~}
  server 127.0.0.1:${p};
%{ endfor ~}
}

server {
  listen 80;
  server_name ${nombre}.tienda.local;
  location / { proxy_pass http://${nombre}; }
}
T
cat > $I/servicios.tf <<'TF'
module "pagos" {
  source   = "./modules/servicio"
  nombre   = "pagos"
  puerto   = 7100
  entorno  = "prod"
  replicas = 3
}

module "catalogo" {
  source   = "./modules/servicio"
  nombre   = "catalogo"
  puerto   = 7200
  entorno  = "prod"
  replicas = 2
}
TF

# --- Para el check: mutantes y pruebas ocultas --------------------------------
cat > /opt/lab/tests/mutantes.py <<'PY'
"""Mutantes del módulo: cada uno es un fallo que una buena batería debe detectar."""
MUTANTES = [
    ("puerto sin validar (acepta 80)", "variables.tf",
     "var.puerto >= 1024 && var.puerto <= 65535", "var.puerto > 0"),
    ("prod con 1 réplica", "variables.tf",
     '(var.entorno != "prod" || var.replicas >= 2)', "true"),
    ("todas las réplicas en el mismo puerto", "main.tf",
     "var.puerto + i", "var.puerto"),
    ("falta ENTORNO en el .env", "main.tf",
     "ENTORNO=${var.entorno}\\n", ""),
    ("nombre acepta mayúsculas", "variables.tf",
     "^[a-z][a-z0-9-]{2,30}$", "^[a-zA-Z][a-zA-Z0-9-]{2,30}$"),
    ("server_name equivocado", "nginx.conf.tftpl",
     "${nombre}.tienda.local", "${nombre}.local"),
]
PY
cat > /opt/lab/tests/oculto.tftest.hcl <<'HCL'
# Especificación del módulo (pruebas del check, no del alumno).
run "upstream_por_replica" {
  command = plan
  variables {
    nombre   = "pagos"
    puerto   = 7000
    entorno  = "prod"
    replicas = 3
  }
  assert {
    condition     = strcontains(output.nginx_conf, "server 127.0.0.1:7000;") && strcontains(output.nginx_conf, "server 127.0.0.1:7001;") && strcontains(output.nginx_conf, "server 127.0.0.1:7002;")
    error_message = "cada réplica i debe escuchar en puerto + i"
  }
  assert {
    condition     = !strcontains(output.nginx_conf, ":8080;")
    error_message = "no debe aparecer 8080 si el puerto es 7000"
  }
  assert {
    condition     = strcontains(output.nginx_conf, "server_name pagos.tienda.local;")
    error_message = "server_name"
  }
  assert {
    condition     = output.env == "SERVICIO=pagos\nENTORNO=prod\nPUERTO=7000\n"
    error_message = "contenido del .env"
  }
}

run "puerto_bajo" {
  command = plan
  variables {
    nombre  = "pagos"
    puerto  = 80
    entorno = "dev"
  }
  expect_failures = [var.puerto]
}

run "prod_una_replica" {
  command = plan
  variables {
    nombre   = "pagos"
    puerto   = 7000
    entorno  = "prod"
    replicas = 1
  }
  expect_failures = [var.replicas]
}
HCL
chmod 0644 /opt/lab/tests/*

cat > $I/README.md <<'MD'
# infra

Módulo `modules/servicio`: genera la config de nginx (un upstream con una
réplica por puerto: `puerto`, `puerto+1`...) y el `.env` de cada servicio.
MD
chown -R analista:analista $I
A(){ runuser -u analista -- env HOME=$H "$@"; }
A git -C $I init -q -b main
A git -C $I config user.name "Analista"; A git -C $I config user.email analista@tienda.local
A git -C $I add -A
A git -C $I commit -qm "módulo servicio (sin pruebas)"
A terraform -chdir=$M init -input=false >/dev/null

cat > $H/TAREA.txt <<'TXT'
TAREA · Pruebas de infraestructura (terraform test)

~/infra/modules/servicio lo usan todos los servicios y no tiene ni una
prueba. Ya ha llegado a producción un bug: los upstream de nginx apuntan
siempre a 8080, 8081... en vez de al puerto del servicio.

1. Arregla el bug (sólo eso: no reestructures el módulo).
2. Escribe pruebas con "terraform test" en
   ~/infra/modules/servicio/tests/*.tftest.hcl (command = plan: no hace
   falta crear ficheros) que cubran el contrato del módulo:
     - cada réplica i escucha en puerto + i, y el server_name es <nombre>.tienda.local
     - el .env lleva SERVICIO, ENTORNO y PUERTO
     - rechaza puertos < 1024 o > 65535 (expect_failures)
     - rechaza prod con menos de 2 réplicas
     - rechaza nombres con mayúsculas o que no empiezan por letra
   El check meterá fallos a propósito en el módulo (mutantes) y tus pruebas
   tienen que detectar cada uno.
3. ~/infra/ci/test.sh: lo que correría el CI. terraform fmt -check,
   init, validate y test del módulo. Debe salir con error si algo falla.
4. Commit en ~/infra.

  cd ~/infra/modules/servicio && terraform test

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 202 plantado."
