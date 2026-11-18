# Resolución guiada · Lab 213

:::piensa ¿Qué hace falta para que un `git push` acabe en producción?
Una forja que vea el push y lea el workflow, un **runner** que acepte el job,
las **acciones** (`uses:`) accesibles, y un despliegue con credenciales. En este
servidor fallan las cuatro. Ve de una en una y mira `ci-estado` después de cada paso.
:::

## Paso 1 · Enciende Actions

:::pista Cómo hacerlo
```bash
sudo nano /etc/gitea/app.ini      # [actions] ENABLED = true, DEFAULT_ACTIONS_URL = self
sudo systemctl restart gitea
```
`self` significa: `uses: actions/checkout@v4` se busca en
`http://localhost:4213/actions/checkout`, el espejo interno.
:::

## Paso 2 · Actions en el repo

:::piensa ¿Por qué sigue sin aparecer la pestaña Actions en el repo?
Mira `curl -s --netrc-file ~/.netrc localhost:4213/api/v1/repos/analista/web | jq .has_actions`.
:::

:::pista Cómo hacerlo
Web: Ajustes del repo → Avanzado → Actions. O por API:
```bash
curl --netrc-file ~/.netrc -X PATCH -H 'Content-Type: application/json' \
  -d '{"has_actions":true}' http://localhost:4213/api/v1/repos/analista/web
```
:::

## Paso 3 · Registra el runner

:::pista Cómo hacerlo
```bash
sudo useradd --system --create-home --home-dir /var/lib/act_runner act-runner
sudo mkdir -p /etc/act_runner
act_runner generate-config | sudo tee /etc/act_runner/config.yaml
sudo nano /etc/act_runner/config.yaml
#   runner.file: /var/lib/act_runner/.runner
#   runner.labels: ["self-hosted:host"]     <- sin Docker, modo host
TOKEN=$(sudo -u git gitea --config /etc/gitea/app.ini actions generate-runner-token)
sudo -u act-runner act_runner register --no-interactive \
  --config /etc/act_runner/config.yaml --instance http://localhost:4213 --token "$TOKEN"
```
Si pasas `--labels` con `--config`, el aviso `Labels from command will be ignored`
te dice que manda el fichero.
:::

## Paso 4 · El servicio

:::pista Cómo hacerlo
Unidad `/etc/systemd/system/act_runner.service` con `User=act-runner`,
`WorkingDirectory=/var/lib/act_runner` y
`ExecStart=/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml`.
`journalctl -u act_runner` debe decir `declare successfully` con tus etiquetas.
:::

## Paso 5 · El workflow y el secreto

:::pista Cómo hacerlo
Secreto: web (Ajustes → Actions → Secretos) o
`PUT /api/v1/repos/analista/web/actions/secrets/DEPLOY_TOKEN` con `{"data":"..."}`.

```yaml
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      # ...
      - name: Desplegar
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: curl ... -H "Authorization: Bearer $DEPLOY_TOKEN" ...
```
`git push`, y `ci-estado` / `ci-log` hasta verlo en verde.
:::

## Cómo actuar en una situación así

- Monta el CI por capas y verifica cada una: forja → runner → acciones → secretos → despliegue.
- Un token que tocó git está comprometido: rótalo siempre, no basta con borrarlo.
- Los runners en modo host ejecutan código del repo en tu servidor: usuario propio, sin sudo, y sólo repos de confianza.
