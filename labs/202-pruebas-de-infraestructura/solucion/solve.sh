#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/infra
M=modules/servicio

# 1. El bug: las réplicas deben escuchar en puerto + i, no en 8080 + i.
sed -i 's/: 8080 + i\]/: var.puerto + i]/' $M/main.tf

# 2. Pruebas del contrato del módulo.
mkdir -p $M/tests
cat > $M/tests/contrato.tftest.hcl <<'HCL'
# Contrato del módulo servicio. command = plan: no se escribe nada en disco.

variables {
  nombre  = "pagos"
  puerto  = 7000
  entorno = "dev"
}

run "una_replica_por_puerto" {
  command = plan
  variables {
    entorno  = "prod"
    replicas = 3
  }
  assert {
    condition     = strcontains(output.nginx_conf, "server 127.0.0.1:7000;")
    error_message = "la réplica 0 debe escuchar en el puerto base"
  }
  assert {
    condition     = strcontains(output.nginx_conf, "server 127.0.0.1:7001;") && strcontains(output.nginx_conf, "server 127.0.0.1:7002;")
    error_message = "la réplica i debe escuchar en puerto + i"
  }
  assert {
    condition     = length(regexall("server 127", output.nginx_conf)) == 3
    error_message = "un server por réplica"
  }
  assert {
    condition     = strcontains(output.nginx_conf, "server_name pagos.tienda.local;")
    error_message = "server_name debe ser <nombre>.tienda.local"
  }
}

run "fichero_env" {
  command = plan
  assert {
    condition     = output.env == "SERVICIO=pagos\nENTORNO=dev\nPUERTO=7000\n"
    error_message = "el .env debe llevar SERVICIO, ENTORNO y PUERTO"
  }
}

run "rechaza_puerto_privilegiado" {
  command = plan
  variables {
    puerto = 80
  }
  expect_failures = [var.puerto]
}

run "rechaza_puerto_fuera_de_rango" {
  command = plan
  variables {
    puerto = 70000
  }
  expect_failures = [var.puerto]
}

run "acepta_limites_de_puerto" {
  command = plan
  variables {
    puerto = 1024
  }
}

run "prod_exige_dos_replicas" {
  command = plan
  variables {
    entorno  = "prod"
    replicas = 1
  }
  expect_failures = [var.replicas]
}

run "dev_admite_una_replica" {
  command = plan
  variables {
    replicas = 1
  }
}

run "rechaza_mayusculas" {
  command = plan
  variables {
    nombre = "Pagos"
  }
  expect_failures = [var.nombre]
}

run "rechaza_nombre_que_empieza_por_numero" {
  command = plan
  variables {
    nombre = "1pagos"
  }
  expect_failures = [var.nombre]
}
HCL

# 3. Lo que corre el CI.
mkdir -p ci
cat > ci/test.sh <<'SH'
#!/usr/bin/env bash
# CI de la infra: formato, validación y pruebas del módulo. Falla al primer error.
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive
terraform -chdir=modules/servicio init -input=false -backend=false >/dev/null
terraform -chdir=modules/servicio validate
terraform -chdir=modules/servicio test
SH
chmod +x ci/test.sh

printf '.terraform/\n*.tfstate\n*.tfstate.*\n' > .gitignore
terraform fmt -recursive
bash ci/test.sh
git add -A
git commit -qm "servicio: réplicas en puerto+i; pruebas del contrato con terraform test; ci/test.sh"
echo "solve.sh completado."
