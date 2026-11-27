# Resolución guiada · Lab 218

:::piensa ¿Qué gana el pipeline al vivir en el repo?
Hoy el pipeline está pegado en la web de Jenkins: nadie ve sus cambios, no
pasa por revisión y, si Jenkins se pierde, se pierde con él. En un
`Jenkinsfile` dentro del repo, el pipeline se versiona con el código: cada
cambio es un commit revisable. Y si además Gitea avisa a Jenkins en cada push,
nadie tiene que "acordarse" de lanzarlo.
:::

**El plan:** (1) una credencial de sólo lectura para clonar, (2) el job lee el
`Jenkinsfile` del repo, (3) escribir el `Jenkinsfile` y arreglar el bug,
(4) el webhook y (5) subirlo y comprobar.

Dentro del lab, Jenkins escucha en `http://localhost:8080`, Gitea en
`http://localhost:4218` y la tienda en `http://localhost:9080`. Desde tu
navegador, Jenkins es `localhost:8218` y la tienda `localhost:9218`.

## Paso 1 · Una credencial de sólo lectura para clonar

**Objetivo:** que Jenkins clone con un token que sólo sirve para leer, no con
la contraseña de `analista` escrita en claro.

**Pregúntate:** si alguien roba lo que usa Jenkins para clonar, ¿qué puede
hacer con una contraseña? ¿Y con un token de sólo lectura?

:::pista Cómo hacerlo
Crea el token en Gitea con su API:
```bash
curl -s -u analista:analista123 -H 'Content-Type: application/json' \
  -d '{"name":"jenkins","scopes":["read:repository"]}' \
  http://localhost:4218/api/v1/users/analista/tokens
```
- `-u usuario:clave` se autentica en la API; `-d '…'` envía el JSON por `POST`.
- `scopes: ["read:repository"]` limita el token a **leer** repositorios: no
  sirve para empujar código ni para tocar la cuenta.

**Qué deberías ver:** un JSON con `"sha1":"…"`. Ese valor es el token; Gitea no
lo vuelve a enseñar. Guárdalo donde Jenkins lo lee:
```bash
printf '%s' 'PEGA_AQUI_EL_SHA1' | sudo tee /etc/jenkins/secrets/gitea >/dev/null
sudo chown root:jenkins /etc/jenkins/secrets/gitea
sudo chmod 640 /etc/jenkins/secrets/gitea
```
`printf '%s'` escribe el token sin salto de línea final. `640` y grupo
`jenkins`: lo leen root y Jenkins, nadie más.

Ahora decláralo como credencial en la configuración de Jenkins. Jenkins se
configura con **JCasC** (*Configuration as Code*): un YAML que describe el
servidor. Añade al **final** de `/etc/jenkins/casc.yaml`, sin sangría:
```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: gitea
              username: analista
              password: "${readFile:/etc/jenkins/secrets/gitea}"
```
`${readFile:…}` hace que Jenkins lea el valor del fichero al cargar la
configuración: el secreto no queda escrito en el YAML. `id: gitea` es el nombre
con el que lo usará el job.

Aplica: en Jenkins (`admin` / `Jenkins-218`), *Manage Jenkins → Configuration
as Code → Reload existing configuration*. En *Manage Jenkins → Credentials*
debe aparecer `gitea`.
:::

## Paso 2 · El job lee el `Jenkinsfile` del repo

**Objetivo:** que el job `tienda` deje de tener el pipeline pegado y lo lea de
Gitea.

:::pista Cómo hacerlo
En Jenkins: job `tienda` → *Configure* → sección *Pipeline*:

| Campo | Valor |
|---|---|
| Definition | *Pipeline script from SCM* (en vez de *Pipeline script*) |
| SCM | Git |
| Repository URL | `http://localhost:4218/analista/tienda.git` |
| Credentials | `analista/****` (la `gitea` del paso 1) |
| Branch Specifier | `*/main` |
| Script Path | `Jenkinsfile` |

*SCM* (*Source Code Management*) es el control de versiones: Jenkins clona el
repo y ejecuta el fichero indicado en *Script Path*. Guarda.
:::

## Paso 3 · El `Jenkinsfile` y el bug

**Objetivo:** un pipeline versionado que pase los tests y construya el
frontend en paralelo, publique el informe y sólo despliegue si todo pasa.

:::pista Cómo hacerlo
Primero el bug. El test dice que `20x2` con un 10 % de descuento da `5`:
```bash
cd ~/tienda && git pull
grep -n 'descuento / 100' src/carrito.js
```
`subtotal * (descuento / 100)` calcula **el descuento** (el 10 % de 50 = 5),
no el total con descuento. Cámbialo a:
```js
  return redondea(subtotal(items) * (1 - descuento / 100));
```
(`1 - 0.10 = 0.90`: pagas el 90 %.)

Crea `~/tienda/Jenkinsfile`:
```groovy
pipeline {
    agent { label 'linux' }
    options {
        disableConcurrentBuilds()
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
```

| Pieza | Qué hace |
|---|---|
| `agent { label 'linux' }` | Ejecuta en un agente con esa etiqueta (`agente-linux`, definido en `casc.yaml`). El servidor de Jenkins no ejecuta builds (`numExecutors: 0`). |
| `disableConcurrentBuilds()` | Dos pushes seguidos no despliegan a la vez: el segundo espera. |
| `parallel { … }` | Las etapas de dentro corren a la vez. Si una falla, la etapa `Verificar` falla. |
| `node --test --test-reporter=…` | El ejecutor de tests de Node. Cada `--test-reporter` va con su `--test-reporter-destination`: uno legible en la consola (`spec` → `stdout`) y otro JUnit en un fichero. |
| `post { always { junit … } }` | Publica el informe en Jenkins **siempre**, también cuando los tests fallan, que es cuando más lo necesitas. |
| `when { expression { … } }` | La etapa sólo se ejecuta si la condición es cierta. `GIT_BRANCH` lo rellena el plugin de Git (`origin/main`). |
| `$GIT_COMMIT` | El commit exacto que se ha construido: el despliegue lo usa como versión. |

Las etapas van en orden: si `Verificar` falla, `Desplegar` no se ejecuta.
:::

## Paso 4 · El webhook

**Objetivo:** que cada push a `main` lance el job, sin intervención.

:::piensa ¿Cómo se autentica Gitea ante Jenkins?
Para lanzar un build hay que llamar a `POST /job/tienda/build` como un usuario
con permiso. Con usuario y **contraseña**, Jenkins exige además un *crumb*
(una protección anti-CSRF que una llamada automática no tiene). Con un
**API token** de Jenkins, no. Gitea manda la cabecera
`Authorization: Basic base64(usuario:token)`.
:::

:::pista Cómo hacerlo
1. En Jenkins: menú de `admin` (arriba a la derecha) → *Security* → *API
   Token* → *Add new Token* → *Generate*. Copia el token.
2. Genera la cabecera en la terminal:
   ```bash
   printf 'admin:%s' 'PEGA_AQUI_EL_TOKEN_DE_JENKINS' | base64 -w0; echo
   ```
   `base64 -w0` codifica sin cortar en líneas.
3. En Gitea (`analista` / `analista123`): repo `tienda` → *Settings* →
   *Webhooks* → *Add webhook* → *Gitea*:
   - URL: `http://localhost:8080/job/tienda/build`
   - Trigger: *Push events*, rama `main`
   - Authorization header: `Basic <lo que imprimió base64>`

Gitea sólo puede llamar a `localhost` porque `/etc/gitea/app.ini` lo permite
(`ALLOWED_HOST_LIST = loopback`). En el webhook pulsa *Test delivery*.

**Qué deberías ver:** respuesta `201` y un build nuevo en Jenkins.
:::

## Paso 5 · Súbelo y comprueba

```bash
cd ~/tienda
git add Jenkinsfile src/carrito.js
git commit -m "ci: Jenkinsfile con tests en paralelo y JUnit; fix descuento"
git push origin main
```
El push dispara el webhook, que lanza el job, que lee el `Jenkinsfile` que
acabas de subir. **Qué deberías ver** en Jenkins: un build en verde, con
*Test Result* de 6 tests. Y en producción:
```bash
curl -s 'http://localhost:9080/api/total?items=20x2,10x1&descuento=10'
bash /opt/lab/check.sh
```
**Qué deberías ver:** `"total":45` (20×2 + 10×1 = 50, menos el 10 %).

## Cómo actuar en una situación así

- **Token de sólo lectura** para clonar: si Jenkins se ve comprometido, no
  sirve para empujar código.
- El siguiente paso natural es un job *Multibranch Pipeline*: un job por rama o
  pull request, con `when { branch 'main' }`.
- Mantén las credenciales en JCasC con `${readFile:…}` o un gestor de secretos,
  nunca en el YAML.

## Si te atascas

- **El build falla al clonar con `Authentication failed`:** la credencial
  `gitea` no existe (¿recargaste JCasC?) o el token tiene saltos de línea.
- **`No such DSL method 'pipeline'` o errores de sintaxis:** revisa las llaves
  del `Jenkinsfile`.
- **El webhook da `403`:** la cabecera no es `Basic …` de `admin:TOKEN` en
  base64, o usaste la contraseña en vez del API token.
- **Verde pero sin informe de tests:** falta el `junit` en `post`, o la ruta del
  XML no coincide con `--test-reporter-destination`.
- **No hay build nuevo tras el push:** el webhook no está en la rama `main` o no
  hiciste `git push`.
