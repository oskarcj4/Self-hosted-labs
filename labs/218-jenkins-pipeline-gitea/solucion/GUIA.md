# Resolución guiada · Lab 218

:::piensa ¿Qué gana el pipeline al vivir en el repo?
Se versiona con el código: cada cambio del pipeline pasa por un commit (y por
revisión), una rama puede probar un pipeline distinto y, si Jenkins muere, el
pipeline no se pierde.
:::

## Paso 1 · Credencial para clonar

:::pista Cómo hacerlo
Crea un token de Gitea con alcance `read:repository`
(Ajustes > Aplicaciones, o `POST /api/v1/users/analista/tokens`). Guárdalo en
`/etc/jenkins/secrets/gitea` y añade a `casc.yaml`:
```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              id: gitea
              username: analista
              password: "${readFile:/etc/jenkins/secrets/gitea}"
```
Recarga JCasC: *Manage Jenkins > Configuration as Code > Reload*.
:::

## Paso 2 · El job lee el Jenkinsfile

:::pista Cómo hacerlo
Job `tienda` > Configure > Pipeline: *Pipeline script from SCM*, Git,
`http://localhost:4218/analista/tienda.git`, credencial `gitea`, rama
`*/main`, *Script Path* `Jenkinsfile`.
:::

## Paso 3 · El Jenkinsfile

:::pista Cómo hacerlo
```groovy
stage('Verificar') {
    parallel {
        stage('Tests') {
            steps { sh 'mkdir -p informes && node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=junit --test-reporter-destination=informes/junit.xml' }
            post { always { junit 'informes/junit.xml' } }
        }
        stage('Frontend') { steps { sh 'npm run build' } }
    }
}
stage('Desplegar') {
    when { expression { env.GIT_BRANCH == 'origin/main' } }
    steps { sh 'sudo /usr/local/bin/desplegar-tienda "$PWD" "$GIT_COMMIT"' }
}
```
`post { always { junit ... } }` publica el informe también cuando los tests fallan.
:::

## Paso 4 · El webhook

:::piensa ¿Cómo se autentica Gitea ante Jenkins?
`POST /job/tienda/build` exige usuario con permiso Build. Con usuario y
contraseña haría falta *crumb* (CSRF). Con un **API token** de Jenkins, no:
Gitea manda la cabecera `Authorization: Basic base64(usuario:token)`.
:::

:::pista Cómo hacerlo
Jenkins: tu usuario > Security > API Token > Add new token. Gitea: repo >
Ajustes > Webhooks > Gitea: URL `http://localhost:8080/job/tienda/build`,
evento push, rama `main`, *Authorization Header* `Basic <base64 de admin:TOKEN>`.
Pulsa "Probar entrega": debe dar 201.
:::

## Paso 5 · El bug

:::pista Cómo hacerlo
Jenkins mostrará `total con 10% de descuento` en rojo. En `src/carrito.js`
el total es `subtotal * (1 - descuento / 100)`.
:::
