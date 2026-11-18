#!/usr/bin/env bash
# Solución automática (corre como analista, con sudo).
set -e
J=/var/lib/jenkins
URL=http://localhost:8080

# 1. Usuarios de servicio y secretos en ficheros (no en el YAML).
sudo useradd -r -d $J -s /usr/sbin/nologin jenkins 2>/dev/null || true
sudo useradd -r -m -d /var/lib/jenkins-agent -s /usr/sbin/nologin jenkins-agent 2>/dev/null || true
sudo mkdir -p /etc/jenkins/secrets
ADMIN_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
printf '%s' "$ADMIN_PASS" | sudo tee /etc/jenkins/secrets/admin > /dev/null
sudo cat /etc/publicador/pass | sudo tee /etc/jenkins/secrets/deploy-pass > /dev/null
sudo chown -R root:jenkins /etc/jenkins/secrets
sudo chmod 640 /etc/jenkins/secrets/admin /etc/jenkins/secrets/deploy-pass; sudo chmod 750 /etc/jenkins/secrets

# 2. JCasC: seguridad, 0 ejecutores, nodo agente-linux por WebSocket, credencial.
sudo tee /etc/jenkins/casc.yaml > /dev/null <<'YML'
jenkins:
  systemMessage: "Jenkins de la empresa. Configuración en /etc/jenkins/casc.yaml (no tocar a clics)."
  numExecutors: 0
  mode: EXCLUSIVE
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: "${readFile:/etc/jenkins/secrets/admin}"
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
  nodes:
    - permanent:
        name: agente-linux
        labelString: linux
        numExecutors: 2
        remoteFS: /var/lib/jenkins-agent
        launcher:
          inbound:
            webSocket: true
        retentionStrategy: always
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: deploy-pass
              username: deploy
              password: "${readFile:/etc/jenkins/secrets/deploy-pass}"
              description: "Publicador (antes en claro en despliegue-legacy)"
YML
sudo chmod 644 /etc/jenkins/casc.yaml

# 3. Servicio como usuario jenkins y con CASC_JENKINS_CONFIG.
sudo systemctl stop jenkins
sudo chown -R jenkins:jenkins $J /var/cache/jenkins
sudo mkdir -p /etc/systemd/system/jenkins.service.d
sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null <<'U'
[Service]
User=jenkins
Group=jenkins
Environment=CASC_JENKINS_CONFIG=/etc/jenkins/casc.yaml
U
sudo systemctl daemon-reload
sudo systemctl start jenkins
for _ in $(seq 1 120); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASS" $URL/api/json)" = 200 ] && break; sleep 2
done

# 4. Secreto del agente (lo da el controlador) y agente como servicio.
SECRET=$(curl -fs -u "admin:$ADMIN_PASS" $URL/computer/agente-linux/jenkins-agent.jnlp \
         | sed -n 's:.*<argument>\([0-9a-f]\{64\}\)</argument>.*:\1:p' | head -1)
sudo mkdir -p /etc/jenkins-agent
printf '%s' "$SECRET" | sudo tee /etc/jenkins-agent/secret > /dev/null
sudo chown -R jenkins-agent: /etc/jenkins-agent; sudo chmod 600 /etc/jenkins-agent/secret
sudo tee /etc/systemd/system/jenkins-agent.service > /dev/null <<'U'
[Unit]
Description=Agente Jenkins agente-linux (WebSocket)
After=jenkins.service
[Service]
User=jenkins-agent
WorkingDirectory=/var/lib/jenkins-agent
ExecStart=/usr/local/bin/java -jar /usr/local/share/agent.jar -url http://localhost:8080/ -name agente-linux -secret @/etc/jenkins-agent/secret -webSocket -workDir /var/lib/jenkins-agent
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins-agent

# 5. despliegue-legacy con la credencial.
CJ=$(mktemp)
api(){ curl -fs -b "$CJ" -c "$CJ" -u "admin:$ADMIN_PASS" "$@"; }
CRUMB=$(api $URL/crumbIssuer/api/json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
api $URL/job/despliegue-legacy/config.xml > /tmp/legacy.xml
python3 - /tmp/legacy.xml <<'PY'
import sys, re, html
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
nuevo = """pipeline {
    agent { label 'linux' }
    stages {
        stage('Publicar') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'deploy-pass',
                                 usernameVariable: 'DEPLOY_USER', passwordVariable: 'DEPLOY_PASS')]) {
                    sh 'curl -fsS -X POST -u "$DEPLOY_USER:$DEPLOY_PASS" http://127.0.0.1:9000/publicar'
                }
            }
        }
    }
}"""
s = re.sub(r"<script>.*?</script>", lambda m: "<script>" + html.escape(nuevo, quote=False) + "</script>", s, flags=re.S)
open(p, "w", encoding="utf-8").write(s)
PY
api -H "$CRUMB" -H 'Content-Type: application/xml' --data-binary @/tmp/legacy.xml $URL/job/despliegue-legacy/config.xml
rm -f /tmp/legacy.xml

# 6. Esperar al agente y lanzar los jobs.
for _ in $(seq 1 60); do
  api $URL/computer/agente-linux/api/json | grep -q '"offline":false' && break; sleep 2
done
for j in humo despliegue-legacy; do api -H "$CRUMB" -X POST $URL/job/$j/build -o /dev/null; done
for _ in $(seq 1 90); do
  R1=$(api $URL/job/humo/lastBuild/api/json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("result"))' 2>/dev/null || true)
  R2=$(api $URL/job/despliegue-legacy/lastBuild/api/json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("result"))' 2>/dev/null || true)
  [ "$R1" = SUCCESS ] && [ "$R2" = SUCCESS ] && break; sleep 2
done
rm -f "$CJ"
echo "humo: $R1 · despliegue-legacy: $R2"
echo "Admin: admin / (en /etc/jenkins/secrets/admin)"
echo "solve.sh completado."
