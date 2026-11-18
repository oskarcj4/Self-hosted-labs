#!/usr/bin/env bash
# Lab 217: Jenkins local "instalado deprisa":
#  - corre como root, sin seguridad (cualquiera es admin, también sin login);
#  - configuración hecha a clics (nada versionado), sin JCasC;
#  - los builds corren en el nodo controlador (2 ejecutores) y no hay agente;
#  - el job "humo" pide label 'linux' y lleva horas en cola;
#  - el job "despliegue-legacy" lleva la contraseña de despliegue en claro.
set -e
export HOME=/root
J=/var/lib/jenkins

# --- Receptor de "publicaciones" (lo que llama despliegue-legacy) ----------------
mkdir -p /etc/publicador
printf 'Deploy-Legacy-2026' > /etc/publicador/pass
chmod 600 /etc/publicador/pass
cat > /usr/local/bin/publicador.py <<'PY'
#!/usr/bin/env python3
"""Recibe publicaciones: POST /publicar con Basic deploy:<pass>. Log en /var/log/publicador.log."""
import base64, http.server, json, time
PASS = open("/etc/publicador/pass").read().strip()
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        ok = self.headers.get("Authorization", "") == "Basic " + base64.b64encode(f"deploy:{PASS}".encode()).decode()
        with open("/var/log/publicador.log", "a") as f:
            f.write(json.dumps({"ts": time.time(), "ok": ok, "ruta": self.path}) + "\n")
        self.send_response(200 if ok and self.path == "/publicar" else 401)
        self.end_headers()
        self.wfile.write(b"publicado\n" if ok else b"no autorizado\n")
    def log_message(self, *a):
        pass
http.server.ThreadingHTTPServer(("127.0.0.1", 9000), H).serve_forever()
PY
cat > /etc/systemd/system/publicador.service <<'U'
[Unit]
Description=Receptor de publicaciones
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/publicador.py
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Jenkins como root y sin seguridad ----------------------------------------
mkdir -p $J/plugins $J/jobs/humo $J/jobs/despliegue-legacy /var/cache/jenkins
cp -r /opt/jenkins/plugins/. $J/plugins/
cat > $J/config.xml <<'XML'
<?xml version='1.1' encoding='UTF-8'?>
<hudson>
  <version>2.580.2</version>
  <installStateName>RUNNING</installStateName>
  <numExecutors>2</numExecutors>
  <mode>NORMAL</mode>
  <useSecurity>false</useSecurity>
  <authorizationStrategy class="hudson.security.AuthorizationStrategy$Unsecured"/>
  <securityRealm class="hudson.security.SecurityRealm$None"/>
  <systemMessage>Jenkins de la empresa. (Configurado a mano por el becario en 2024.)</systemMessage>
</hudson>
XML
echo 2.580.2 > $J/jenkins.install.UpgradeWizard.state
echo 2.580.2 > $J/jenkins.install.InstallUtil.lastExecVersion
job_xml() {  # job_xml DESCRIPCIÓN FICHERO_GROOVY
  cat <<XML
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>$1</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$2")</script>
    <sandbox>true</sandbox>
  </definition>
  <disabled>false</disabled>
</flow-definition>
XML
}
cat > /tmp/humo.groovy <<'G'
pipeline {
    agent { label 'linux' }
    options { timeout(time: 5, unit: 'MINUTES') }
    stages {
        stage('Humo') {
            steps {
                sh 'echo "nodo: $NODE_NAME"; hostname; id -un; java -version 2>&1 | head -1'
            }
        }
    }
}
G
cat > /tmp/legacy.groovy <<'G'
pipeline {
    agent { label 'linux' }
    stages {
        stage('Publicar') {
            steps {
                sh 'curl -fsS -X POST -u deploy:Deploy-Legacy-2026 http://127.0.0.1:9000/publicar'
            }
        }
    }
}
G
job_xml "Prueba de humo: comprueba que hay un agente Linux." /tmp/humo.groovy > $J/jobs/humo/config.xml
job_xml "Publica la web. NO TOCAR (funciona)." /tmp/legacy.groovy > $J/jobs/despliegue-legacy/config.xml
rm -f /tmp/humo.groovy /tmp/legacy.groovy
cat > /etc/systemd/system/jenkins.service <<'U'
[Unit]
Description=Jenkins
After=network.target
[Service]
Environment=JENKINS_HOME=/var/lib/jenkins
ExecStart=/usr/local/bin/java -Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -jar /opt/jenkins/jenkins.war --httpPort=8080 --webroot=/var/cache/jenkins/war
Restart=on-failure
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now publicador jenkins
for _ in $(seq 1 180); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/json)" = 200 ] && break; sleep 2
done
# Encola "humo" (se quedará esperando un agente 'linux').
CJ=$(mktemp)
CRUMB=$(curl -fs -c "$CJ" http://localhost:8080/crumbIssuer/api/json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
curl -fs -b "$CJ" -H "$CRUMB" -X POST http://localhost:8080/job/humo/build -o /dev/null
rm -f "$CJ"

# Ayuda: agent.jar a mano (también se descarga de /jnlpJars/agent.jar).
install -m 0644 /opt/jenkins/agent.jar /usr/local/share/agent.jar

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Jenkins local bien montado

Jenkins (http://localhost:8080 en el servidor; http://localhost:8217 desde tu
navegador) se instaló deprisa y se nota:

  1. Corre como root (systemctl cat jenkins).
  2. No tiene seguridad: cualquiera, sin login, es administrador.
  3. Todo se configuró a clics: si el disco muere, nadie sabe cómo estaba.
     Queremos Configuration as Code (el plugin JCasC ya está instalado):
     /etc/jenkins/casc.yaml y CASC_JENKINS_CONFIG.
  4. Los builds corren en el controlador. Debe tener 0 ejecutores y los
     builds ir a un agente: "agente-linux", label "linux", conectado por
     WebSocket, como servicio y con un usuario propio (no root).
     El agente: /usr/local/share/agent.jar (java -jar agent.jar -help).
  5. El job "despliegue-legacy" lleva la contraseña en claro. Pásala a una
     credencial de Jenkins con id "deploy-pass" (usuario deploy) y úsala
     con withCredentials. Luego ejecútalo y que publique bien.

Al terminar, el job "humo" (en cola desde hace horas) debe acabar en verde en
agente-linux. Contraseñas en ficheros, nunca en casc.yaml: ${readFile:/ruta}.

Comprueba: bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
printf '# Sin DNS externo: servidor aislado.\nnameserver 127.0.0.1\noptions timeout:1 attempts:1\n' > /etc/resolv.conf
echo "Lab 217 plantado."
