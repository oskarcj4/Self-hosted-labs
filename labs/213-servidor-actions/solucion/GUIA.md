# Resolución guiada · Lab 213

:::piensa ¿Qué hace falta para que un `git push` acabe en producción?
Cuatro piezas, y en este servidor fallan las cuatro: una **forja** que vea el
push y lea el workflow, un **runner** que acepte el trabajo y lo ejecute, las
**acciones** (`uses:`) descargables sin Internet, y un despliegue con
**credenciales** que no estén en el repo. Ve de una en una y mira `ci-estado`
después de cada paso.
:::

**El plan:** (1) encender Actions en Gitea, (2) activarlo en el repo,
(3) registrar el runner, (4) convertirlo en servicio, (5) guardar el token como
secreto y (6) reescribir el workflow y subirlo.

## Paso 1 · Enciende Actions en Gitea

**Objetivo:** que Gitea ejecute workflows y busque las acciones en el espejo
interno.

:::pista Cómo hacerlo
```bash
sudo nano /etc/gitea/app.ini
```
En la sección `[actions]`:
```ini
[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = self
```
- `ENABLED = true` activa Gitea Actions en el servidor.
- `DEFAULT_ACTIONS_URL` dice dónde buscar `uses: actions/checkout@v4`. Con
  `github` iría a github.com, y aquí no hay Internet. Con `self` la busca en
  esta misma forja: `http://localhost:4213/actions/checkout`, el espejo interno.

```bash
sudo systemctl restart gitea
```
:::

## Paso 2 · Actions en el repo

**Objetivo:** que el repo `analista/web` tenga la pestaña Actions.

**Pregúntate:** el servidor ya tiene Actions. ¿Por qué el repo no?

:::pista Cómo hacerlo
Porque el repo se creó cuando Actions estaba apagado, y cada repo guarda qué
"unidades" tiene activadas. Compruébalo y actívalo con la API de Gitea:
```bash
curl -s --netrc-file ~/.netrc http://localhost:4213/api/v1/repos/analista/web | jq .has_actions
curl -s --netrc-file ~/.netrc -X PATCH -H 'Content-Type: application/json' \
  -d '{"has_actions":true}' http://localhost:4213/api/v1/repos/analista/web | jq .has_actions
```
- `--netrc-file ~/.netrc` toma usuario y contraseña de ese fichero (ya
  preparado), para no escribirlos en el comando.
- `-X PATCH` modifica sólo los campos que envías.
- `jq .has_actions` saca ese campo del JSON de respuesta.

**Qué deberías ver:** `false` y después `true`. (En la web: ajustes del repo →
Avanzado → Actions.)
:::

## Paso 3 · Registra el runner

**Objetivo:** un runner, con usuario propio y sin Docker, dado de alta en la
forja.

**Pregúntate:** el runner ejecuta código del repo en esta máquina. ¿Con qué
usuario debería hacerlo?

:::pista Cómo hacerlo
Con uno propio, sin privilegios: si un workflow hace algo malo, no lo hace
como root.
```bash
sudo useradd --system --create-home --home-dir /var/lib/act_runner --shell /usr/sbin/nologin act-runner
sudo mkdir -p /etc/act_runner
act_runner generate-config | sudo tee /etc/act_runner/config.yaml >/dev/null
sudo nano /etc/act_runner/config.yaml
```
`useradd --system` crea una cuenta de servicio; `--shell /usr/sbin/nologin`
impide entrar con ella. `generate-config` escribe la configuración por
defecto. Cambia dos cosas en `runner:`:
```yaml
runner:
  file: /var/lib/act_runner/.runner
  labels:
    - "self-hosted:host"
```
- `file`: dónde guarda el runner su identidad tras registrarse; tiene que
  poder escribirlo el usuario `act-runner`.
- `labels`: las etiquetas que anuncia. Cada una es `nombre:cómo`. Las de
  fábrica (`ubuntu-latest:docker://…`) ejecutan dentro de contenedores
  Docker, y aquí no hay Docker. `self-hosted:host` significa: "acepto trabajos
  con `runs-on: self-hosted` y los ejecuto directamente en la máquina".

Pide un token de registro a Gitea y registra:
```bash
TOKEN=$(sudo -u git gitea --config /etc/gitea/app.ini actions generate-runner-token 2>/dev/null | tail -1)
echo "$TOKEN"
sudo -u act-runner act_runner register --no-interactive \
  --config /etc/act_runner/config.yaml --instance http://localhost:4213 --token "$TOKEN"
```
- `sudo -u git gitea …` ejecuta la herramienta de Gitea como su usuario.
- `2>/dev/null | tail -1`: el comando puede escribir avisos antes del token;
  así te quedas sólo con la última línea, que es el token.
- `--no-interactive` registra sin preguntar nada.

**Qué deberías ver:** `Runner registered successfully`. Si añades `--labels`,
verás `Labels from command will be ignored`: con `--config`, mandan las del
fichero.
:::

## Paso 4 · El runner como servicio

**Objetivo:** que el runner arranque solo, como `act-runner`.

:::pista Cómo hacerlo
```bash
sudo tee /etc/systemd/system/act_runner.service >/dev/null <<'EOF'
[Unit]
Description=Gitea act_runner
After=gitea.service

[Service]
User=act-runner
Group=act-runner
WorkingDirectory=/var/lib/act_runner
ExecStart=/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now act_runner
journalctl -u act_runner -n 20 --no-pager
```
`act_runner daemon` se queda conectado a la forja esperando trabajos.

**Qué deberías ver:** `declare successfully` con la etiqueta `self-hosted`.
:::

## Paso 5 · El token, como secreto del repo

**Objetivo:** que el token de despliegue viva en Gitea, no en el repo.

:::pista Cómo hacerlo
El token válido está en `/etc/deployer/token` (el del workflow ya está
revocado). Guárdalo como secreto `DEPLOY_TOKEN` con la API:
```bash
sudo cat /etc/deployer/token | jq -Rs '{data: (. | rtrimstr("\n"))}' \
  | curl -s --netrc-file ~/.netrc -X PUT -H 'Content-Type: application/json' -d @- \
    http://localhost:4213/api/v1/repos/analista/web/actions/secrets/DEPLOY_TOKEN
```
- `jq -Rs` lee la entrada como un único texto (`-R` crudo, `-s` todo junto) y
  construye `{"data": "<token>"}`, quitando el salto de línea final.
- `-d @-` envía como cuerpo lo que llega por la tubería. El token no aparece
  en el comando ni en el historial de la shell.

(En la web: ajustes del repo → Actions → Secretos.)
:::

## Paso 6 · El workflow, y súbelo

**Objetivo:** que corra en tu runner, sólo desde `main`, con el token del
secreto.

:::pista Cómo hacerlo
```bash
cd ~/web && git pull
nano .github/workflows/deploy.yml
```
Déjalo así:
```yaml
name: deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Pruebas
        run: ./tests/check-html.sh

      - name: Construir
        run: |
          mkdir -p dist
          cp -r site/* dist/
          echo "${{ github.sha }}" > dist/VERSION

      - name: Desplegar
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          tar -C dist -czf site.tgz .
          curl -fsS -X POST \
            -H "Authorization: Bearer $DEPLOY_TOKEN" \
            -H "X-Commit: ${{ github.sha }}" \
            --data-binary @site.tgz http://127.0.0.1:9000/deploy
```

| Cambio | Por qué |
|---|---|
| `on: push: branches: [main]` | Antes era `on: push`: cualquier rama desplegaba. |
| `runs-on: self-hosted` | Antes `ubuntu-latest`, una etiqueta que ningún runner de aquí ofrece: el trabajo se quedaba esperando para siempre. |
| `env: DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}` | Gitea pone el secreto en una variable de entorno sólo para ese paso, y lo oculta en los logs. |
| `"Bearer $DEPLOY_TOKEN"` | La shell sustituye la variable al ejecutar: el token no queda escrito en el fichero. |

```bash
git commit -am "ci: runner propio, sólo main y token en un secreto"
git push origin main
ci-estado
```
`ci-estado` y `ci-log` son comandos del lab: listan las ejecuciones y
enseñan el log de la última.

**Qué deberías ver:** la ejecución en verde. Y producción sirviendo tu commit:
```bash
curl -s http://localhost:8080/VERSION; git rev-parse HEAD
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- Monta el CI por capas y verifica cada una: forja → runner → acciones →
  secretos → despliegue.
- Un token que llegó a git está comprometido aunque lo borres: sigue en el
  historial. **Rótalo** (aquí ya estaba revocado).
- Un runner en modo host ejecuta código del repo en tu servidor: usuario
  propio, sin sudo general, y sólo para repos de confianza.

## Si te atascas

- **La ejecución se queda en "esperando":** ningún runner tiene una etiqueta
  que case con `runs-on`. Mira `journalctl -u act_runner` (qué etiquetas
  declaró) y el `runs-on` del workflow.
- **`register` falla con token inválido:** el `TOKEN` lleva texto de más.
  Haz `echo "$TOKEN"`; debe ser una sola cadena.
- **Falla `uses: actions/checkout@v4`:** `DEFAULT_ACTIONS_URL` no es `self`, o
  no reiniciaste Gitea.
- **El despliegue da 401:** el secreto no existe o tiene el token viejo.
