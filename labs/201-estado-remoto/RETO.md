# Estado remoto de Terraform

> Terraform · backend remoto · bloqueo · `init -migrate-state` · secretos en el estado

## Escenario

`~/infra` gestiona con Terraform la configuración de la tienda (`/srv/tienda`).
El estado, `terraform.tfstate`, está **commiteado en git** "para que lo
tenga todo el equipo":

- Dos personas aplican a la vez desde sus copias y cada una pisa el estado de la otra. No hay bloqueo.
- Quien hace `git pull` de un estado viejo y aplica, deshace el trabajo ajeno.
- El estado guarda los valores en claro, también los `sensitive`: la contraseña de la base de datos está en el historial de git.

Hay un backend remoto listo (`http://127.0.0.1:8500/state/<nombre>`, el
backend `http` de Terraform con LOCK/UNLOCK y autenticación básica). Nadie
lo usa.

## Objetivos

1. Backend `http` en `~/infra` (estado `tienda`) con bloqueo y sin credenciales en el código.
2. Estado migrado sin recrear nada: `terraform plan` sin cambios.
3. Ningún `.tfstate` en git ni en disco, con un `.gitignore` que lo impida.
4. Contraseña rotada, con la nueva fuera del repo (la variable sigue siendo `db_password`).

Un compañero que clone el repo debe ver el mismo estado y esperar si otro tiene el bloqueo.

## Pistas

```bash
cat ~/.config/tfstate/credenciales
terraform init -migrate-state
git show HEAD:terraform.tfstate | grep -i password
terraform plan -detailed-exitcode     # 0 = sin cambios
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
