#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
JURL=http://localhost:8080
GURL=http://localhost:4218
A="admin:Jenkins-218"
CJ=$(mktemp)
crumb(){ curl -fs -u "$A" -b "$CJ" -c "$CJ" $JURL/crumbIssuer/api/json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])'; }

# 1. Token de Gitea de sólo lectura para Jenkins, como credencial vía JCasC.
TOKG=$(curl -fs -u analista:analista123 -H 'Content-Type: application/json' \
  -d "{\"name\":\"jenkins-$RANDOM\",\"scopes\":[\"read:repository\"]}" $GURL/api/v1/users/analista/tokens \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha1"])')
printf '%s' "$TOKG" | sudo tee /etc/jenkins/secrets/gitea > /dev/null
sudo chown root:jenkins /etc/jenkins/secrets/gitea && sudo chmod 640 /etc/jenkins/secrets/gitea
sudo tee -a /etc/jenkins/casc.yaml > /dev/null <<'YML'
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: gitea
              username: analista
              password: "${readFile:/etc/jenkins/secrets/gitea}"
              description: "Token de Gitea (read:repository) para clonar"
YML
curl -fs -u "$A" -b "$CJ" -c "$CJ" -H "$(crumb)" -X POST $JURL/configuration-as-code/reload -o /dev/null

# 2. El job lee el Jenkinsfile de Gitea (rama main) con esa credencial.
cat > /tmp/tienda-job.xml <<'XML'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Tienda: Jenkinsfile en el repo, lanzado por webhook de Gitea.</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>http://localhost:4218/analista/tienda.git</url>
          <credentialsId>gitea</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches><hudson.plugins.git.BranchSpec><name>*/main</name></hudson.plugins.git.BranchSpec></branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <disabled>false</disabled>
</flow-definition>
XML
curl -fs -u "$A" -b "$CJ" -c "$CJ" -H "$(crumb)" -H 'Content-Type: application/xml' \
  --data-binary @/tmp/tienda-job.xml $JURL/job/tienda/config.xml
rm -f /tmp/tienda-job.xml

# 3. API token de Jenkins y webhook de Gitea -> /job/tienda/build (con token no hace falta crumb).
TOKJ=$(curl -fs -u "$A" -b "$CJ" -c "$CJ" -H "$(crumb)" -X POST \
  "$JURL/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=gitea-webhook" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["tokenValue"])')
AUTH="Basic $(printf 'admin:%s' "$TOKJ" | base64 -w0)"
curl -fs -u analista:analista123 -H 'Content-Type: application/json' -o /dev/null \
  -d "{\"type\":\"gitea\",\"active\":true,\"events\":[\"push\"],\"branch_filter\":\"main\",
       \"authorization_header\":\"$AUTH\",
       \"config\":{\"url\":\"http://localhost:8080/job/tienda/build\",\"content_type\":\"json\"}}" \
  $GURL/api/v1/repos/analista/tienda/hooks
rm -f "$CJ"

# 4. Jenkinsfile + arreglo del bug, y push (lo lanza el webhook).
cd ~/tienda
git pull -q
sed -i 's#return redondea(subtotal(items) \* (descuento / 100));#return redondea(subtotal(items) * (1 - descuento / 100));#' src/carrito.js
cat > Jenkinsfile <<'G'
pipeline {
    agent { label 'linux' }
    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }
    stages {
        stage('Verificar') {
            parallel {
                stage('Tests') {
                    steps {
                        sh 'mkdir -p informes && node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=junit --test-reporter-destination=informes/junit.xml'
                    }
                    post { always { junit 'informes/junit.xml' } }
                }
                stage('Frontend') {
                    steps { sh 'npm run build' }
                }
            }
        }
        stage('Desplegar') {
            when { expression { env.GIT_BRANCH == 'origin/main' } }
            steps { sh 'sudo /usr/local/bin/desplegar-tienda "$PWD" "$GIT_COMMIT"' }
        }
    }
}
G
git add -A
git commit -qm "ci: Jenkinsfile con tests en paralelo, JUnit y despliegue; fix descuento"
git push -q origin main
SHA=$(git rev-parse HEAD)
echo "Esperando a que el webhook lance Jenkins y despliegue ${SHA:0:8}..."
for _ in $(seq 1 120); do
  curl -fs http://127.0.0.1:9080/api/version | grep -q "$SHA" && break; sleep 2
done
curl -fs http://127.0.0.1:9080/api/version; echo
echo "solve.sh completado."
