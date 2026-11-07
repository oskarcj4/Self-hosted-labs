# Resolución guiada · Lab 201

:::piensa ¿Qué es el estado?
Es el mapa entre tu código y lo que existe de verdad, e incluye cada
atributo de cada recurso, también los secretos. Por eso necesita tres cosas
que git no da: una sola copia, bloqueo y acceso restringido.
:::

## Paso 1 · El backend

:::pista Cómo
Un bloque `backend "http"` dentro de `terraform {}` con `address`,
`lock_address` y `unlock_address`, los tres a `.../state/tienda`. Las
credenciales van en el entorno (`TF_HTTP_USERNAME`, `TF_HTTP_PASSWORD`),
nunca en el `.tf`. Haz `source ~/.config/tfstate/credenciales`.
:::

## Paso 2 · Migrar

:::pista Cómo
`terraform init -migrate-state`: detecta el estado local y pregunta si lo
copia al backend nuevo. Di que sí. Después, `terraform plan` debe decir
"No changes". Si propone crear recursos, el estado no se ha copiado.
:::

## Paso 3 · Sacarlo de git

:::pista Cómo
`git rm --cached terraform.tfstate` y bórralo del disco, junto con
`terraform.tfstate.backup`. El `.gitignore` debe cubrir `*.tfstate`,
`*.tfstate.*` y `.terraform/`. Los `*.tfvars` con secretos tampoco van en git.
:::

## Paso 4 · Rotar

:::pista Por qué
Borrar el fichero no borra el historial: la contraseña vieja sigue en
`git log -p`. Hay que tratarla como filtrada. Genera una nueva, pásala con
`TF_VAR_db_password` desde fuera del repo y aplica.
:::

## Cómo actuar en una situación así

- En la nube: S3 con bloqueo (`use_lockfile`), GCS o Azure Blob. Cifrado en reposo y acceso con IAM mínimo.
- Un estado por entorno o componente (`state/tienda-prod`, `state/red`): limita lo que se rompe y quién puede tocarlo.
- Para reescribir el historial: `git filter-repo --path terraform.tfstate --invert-paths`, coordinado con todo el equipo. La rotación hay que hacerla igualmente.
