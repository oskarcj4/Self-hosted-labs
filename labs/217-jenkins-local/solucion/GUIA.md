# Resolución guiada · Lab 217

:::piensa ¿Por qué un Jenkins sin seguridad es tan grave?
Cualquier usuario anónimo tiene permiso Administer, y eso incluye la consola
de scripts (`/script`): Groovy arbitrario en el servidor. Si además corre
como root, quien llegue al puerto 8080 es root en la máquina.
:::

## Paso 1 · Secretos en ficheros

:::pista Cómo hacerlo
```bash
sudo mkdir -p /etc/jenkins/secrets
openssl rand -base64 18 | sudo tee /etc/jenkins/secrets/admin
sudo cp /etc/publicador/pass /etc/jenkins/secrets/deploy-pass
```
Permisos: dueño root, grupo del usuario de Jenkins, `640`.
:::

## Paso 2 · El YAML de JCasC

:::pista Cómo hacerlo
`/etc/jenkins/casc.yaml` con:
- `jenkins.securityRealm.local.users` (contraseña `"${readFile:/etc/jenkins/secrets/admin}"`)
- `authorizationStrategy.loggedInUsersCanDoAnything.allowAnonymousRead: false`
- `numExecutors: 0`
- `nodes: - permanent: {name: agente-linux, labelString: linux, remoteFS: ..., launcher: {inbound: {webSocket: true}}}`
- `credentials.system.domainCredentials[].credentials[].usernamePassword` con `id: deploy-pass`.
:::

## Paso 3 · Usuario propio y JCasC en el servicio

:::pista Cómo hacerlo
```bash
sudo useradd -r -d /var/lib/jenkins -s /usr/sbin/nologin jenkins
sudo systemctl stop jenkins
sudo chown -R jenkins: /var/lib/jenkins /var/cache/jenkins
sudo systemctl edit jenkins   # User=jenkins, Environment=CASC_JENKINS_CONFIG=/etc/jenkins/casc.yaml
sudo systemctl start jenkins
```
:::

## Paso 4 · El agente

:::piensa ¿WebSocket o puerto TCP de agentes?
El agente inbound clásico abre un puerto TCP aparte (50000). Con
`-webSocket` el agente entra por el mismo HTTP(S) de Jenkins: un puerto menos
abierto, y atraviesa proxies inversos.
:::

:::pista Cómo hacerlo
El secreto del nodo: `curl -u admin:... localhost:8080/computer/agente-linux/jenkins-agent.jnlp`
(primer `<argument>`). Guárdalo en un fichero y crea un servicio con otro usuario:
```
java -jar /usr/local/share/agent.jar -url http://localhost:8080/ -name agente-linux \
     -secret @/etc/jenkins-agent/secret -webSocket -workDir /var/lib/jenkins-agent
```
:::

## Paso 5 · La credencial en el pipeline

:::pista Cómo hacerlo
```groovy
withCredentials([usernamePassword(credentialsId: 'deploy-pass',
                 usernameVariable: 'DEPLOY_USER', passwordVariable: 'DEPLOY_PASS')]) {
    sh 'curl -fsS -X POST -u "$DEPLOY_USER:$DEPLOY_PASS" http://127.0.0.1:9000/publicar'
}
```
Comillas **simples** en `sh`: la variable la expande el shell, no Groovy, y
Jenkins la enmascara en el log.
:::

## Cómo actuar en una situación así

- El controlador orquesta, los agentes trabajan: 0 ejecutores en el controlador.
- Configuración como código y versionada; los secretos, fuera del YAML.
- Una contraseña que estuvo en un Jenkinsfile o en un log, rótala.
