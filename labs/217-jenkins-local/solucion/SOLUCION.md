# Solución — Jenkins local bien montado

## Resumen

| Problema | Arreglo |
|----------|---------|
| Corre como root | usuario `jenkins`, `chown -R` de `JENKINS_HOME`, drop-in `User=jenkins` |
| Sin seguridad | `securityRealm: local` + `loggedInUsersCanDoAnything` sin lectura anónima |
| Configuración a clics | `/etc/jenkins/casc.yaml` + `CASC_JENKINS_CONFIG` en el servicio |
| Contraseñas en el YAML | `${readFile:/etc/jenkins/secrets/...}` (ficheros 640) |
| Builds en el controlador | `numExecutors: 0` + nodo `agente-linux` (label `linux`) |
| Agente inexistente | servicio `jenkins-agent` con usuario propio, `agent.jar -webSocket -secret @fichero` |
| Contraseña en el Jenkinsfile | credencial `deploy-pass` + `withCredentials(usernamePassword(...))` |

Todo el detalle (YAML, servicios y el cambio del job por la API REST con
*crumb*) está en `solve.sh`.

## Notas

- **El *crumb*** (protección CSRF) es obligatorio en los POST. Va ligado a la
  sesión: pide el crumb y haz el POST con el mismo *cookie jar*. Con un API
  token de usuario no hace falta.
- **JCasC manda**: lo que cambies a clics en algo que define el YAML se pierde
  al reiniciar. Es la idea: la fuente de verdad es el fichero.
- **Los jobs** no están en este YAML. Lo habitual: Job DSL o *multibranch*
  leyendo el `Jenkinsfile` del repo (lab 218).
- **El agente con su usuario** separa permisos: un build no puede leer
  `JENKINS_HOME` (secretos, `credentials.xml`, la clave maestra).
