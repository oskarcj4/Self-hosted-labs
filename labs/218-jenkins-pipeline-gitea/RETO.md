# Pipeline de Jenkins desde Gitea

> DevOps · CI/CD · Jenkins · Jenkinsfile · webhooks · JUnit · credenciales · Node 20

## Escenario

Jenkins ya está bien montado (JCasC, seguridad, agente `agente-linux`), pero
el job `tienda` es un pipeline **pegado en la web de Jenkins**:

- clona el repo con la contraseña de Gitea **en claro**;
- no hay `Jenkinsfile` en el repo: el pipeline no se versiona ni se revisa;
- nadie lo lanza: se ejecuta **a mano** "cuando alguien se acuerda";
- no pasa los tests, y producción calcula mal los descuentos (`20x2` con 10% da `5`).

| Servicio | URL | Acceso |
|----------|-----|--------|
| Jenkins | <http://localhost:8218> | `admin` / `Jenkins-218` |
| Gitea | <http://localhost:4218> | `analista` / `analista123` |
| Tienda (producción) | <http://localhost:9218> | |

## Objetivos

1. El pipeline vive en un `Jenkinsfile` del repo; el job `tienda` lo lee de Gitea (*Pipeline script from SCM*, rama `main`).
2. Jenkins clona con una **credencial** propia (mejor un token de Gitea de sólo lectura), sin contraseñas en claro.
3. Un **webhook** de Gitea lanza el job en cada push.
4. Tests y build del frontend **en paralelo**; informe **JUnit** publicado en Jenkins; sólo se despliega si todo pasa.
5. Bug arreglado y producción corriendo el último commit de `main`.

## Pistas

```bash
cat ~/TAREA.txt; cat /usr/local/bin/desplegar-tienda; cat /etc/jenkins/casc.yaml
node --test --test-reporter=junit --test-reporter-destination=informes/junit.xml
```

Gitea sólo llama a `localhost` porque `ALLOWED_HOST_LIST = loopback` en
`/etc/gitea/app.ini`. Con un **API token** de Jenkins no hace falta *crumb*.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
