#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
G=http://localhost:4213

# 1. Actions activado y acciones del espejo interno.
sudo sed -i 's/^ENABLED *=.*/ENABLED = true/; s/^DEFAULT_ACTIONS_URL *=.*/DEFAULT_ACTIONS_URL = self/' /etc/gitea/app.ini
sudo systemctl restart gitea
for _ in $(seq 1 60); do curl -fs $G/api/healthz >/dev/null && break; sleep 1; done

# 2. Usuario propio, config, registro y servicio del runner (modo host).
id act-runner >/dev/null 2>&1 || sudo useradd --system --create-home --home-dir /var/lib/act_runner --shell /usr/sbin/nologin act-runner
sudo mkdir -p /etc/act_runner
# Ojo: con config, act_runner IGNORA --labels y usa runner.labels del fichero,
# que por defecto son imágenes Docker (aquí no hay Docker). Etiqueta host:
act_runner generate-config | python3 -c '
import sys, yaml
c = yaml.safe_load(sys.stdin)
c["runner"]["file"] = "/var/lib/act_runner/.runner"
c["runner"]["labels"] = ["self-hosted:host"]
c["cache"]["enabled"] = False
print(yaml.safe_dump(c, sort_keys=False))' | sudo tee /etc/act_runner/config.yaml > /dev/null
RTOKEN=$(sudo -u git gitea --config /etc/gitea/app.ini actions generate-runner-token | tail -1)
sudo -u act-runner act_runner register --no-interactive --config /etc/act_runner/config.yaml \
  --instance $G --token "$RTOKEN" --name runner-1
sudo tee /etc/systemd/system/act_runner.service > /dev/null <<'U'
[Unit]
Description=Gitea act_runner
After=gitea.service
Wants=gitea.service

[Service]
User=act-runner
Group=act-runner
WorkingDirectory=/var/lib/act_runner
ExecStart=/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload
sudo systemctl enable --now act_runner

# 3. El repo se creó con Actions apagado: no tiene la unidad Actions. Actívala.
curl -fsS --netrc-file ~/.netrc -X PATCH -H 'Content-Type: application/json'   -d '{"has_actions": true}' $G/api/v1/repos/analista/web > /dev/null

# 4. El token válido como secreto del repo (API de Gitea).
sudo cat /etc/deployer/token | python3 -c 'import json,sys;print(json.dumps({"data":sys.stdin.read().strip()}))' \
  | curl -fsS --netrc-file ~/.netrc -X PUT -H 'Content-Type: application/json' -d @- \
      $G/api/v1/repos/analista/web/actions/secrets/DEPLOY_TOKEN

# 5. Workflow: runner propio, sólo main, token desde el secreto.
cd ~/web
git pull -q
cat > .github/workflows/deploy.yml <<'YML'
name: deploy
on:
  push:
    branches: [main]
  workflow_dispatch:

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
YML
git commit -qam "ci: runner propio, sólo main y token en un secreto"
git push -q origin main

echo "Esperando al pipeline..."
SHA=$(git rev-parse HEAD)
for _ in $(seq 1 120); do
  [ "$(curl -fs http://127.0.0.1:8080/VERSION | tr -d '[:space:]')" = "$SHA" ] && break; sleep 2
done
ci-estado
echo "solve.sh completado."
