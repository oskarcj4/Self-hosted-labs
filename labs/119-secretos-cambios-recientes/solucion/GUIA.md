# Resolución guiada · Lab 119

:::piensa Antes de tocar nada
Dos preguntas distintas: qué secretos están en claro (aunque nadie haya entrado)
y qué ha cambiado hace poco (por si alguien ya entró). Las dos se responden con
`grep` y `find`.
:::

## Paso 1 · Secretos en claro

**Pregúntate:** ¿qué palabras suelen acompañar a un secreto en un fichero de configuración o código?

:::pista Cómo comprobarlo
```bash
cd /srv/app
grep -rnEi "password|passw|api_key|secret|token|AKIA" . > ~/secretos.txt
cat ~/secretos.txt
```
Cuando encuentres una contraseña, búscala literalmente: suele repetirse en otros sitios.
:::

## Paso 2 · ¿Qué cambió hace poco?

**Pregúntate:** ¿cómo listas ficheros modificados en las últimas 24 horas?

:::pista Cómo comprobarlo
```bash
find /srv/app -type f -mtime -1 > ~/recientes.txt
grep -v -E 'nologin|/bin/false' /etc/passwd
```
Una cuenta nueva con shell válida y un fichero de notas oculto son mala señal.
:::

## Paso 3 · Saca los secretos del código

**Pregúntate:** ¿dónde deben vivir los secretos para que el código pueda leerlos sin contenerlos?

:::pista Cómo hacerlo
```bash
sudo nano /srv/app/.env        # DB_PASSWORD=..., API_KEY=..., AWS_...
sudo chown app:app /srv/app/.env; sudo chmod 600 /srv/app/.env
```
Cambia cada fichero para leer la variable de entorno (`os.environ["API_KEY"]`,
`ENV["DB_PASSWORD"]`) y borra las líneas `export AWS_...` de `deploy.sh`.
:::

## Paso 4 · La cuenta intrusa

:::pista Cómo hacerlo
```bash
sudo usermod -L -s /usr/sbin/nologin soporte2
sudo rm -f /srv/app/.cache/notas.txt
```
:::

## Cómo actuar en una situación así

- **Mover un secreto no lo arregla si ya se filtró**: rótalo.
- `.env` fuera del control de versiones (`.gitignore`) y con permisos `600`.
- Mejor aún: un gestor de secretos (Vault, SOPS, el del proveedor cloud).

## Si te atascas

- `grep` da demasiado ruido: excluye `node_modules` y binarios con `-I --exclude-dir`.
- El check sigue encontrando la contraseña: búscala con `grep -rn 'Tienda#Prod2024' /srv/app`.
