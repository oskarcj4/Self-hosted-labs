# Jenkins local bien montado

> DevOps · CI/CD · Jenkins LTS · Configuration as Code (JCasC) · agentes · credenciales · systemd

## Escenario

El Jenkins de la empresa se instaló "en un rato" hace dos años y se nota:

1. Corre como **root**.
2. **No tiene seguridad**: cualquiera, sin login, es administrador (y puede ejecutar Groovy en el servidor).
3. Todo se configuró **a clics**: si el disco muere, nadie sabe cómo estaba.
4. Los builds corren **en el propio controlador**. El job `humo` pide un agente `linux` y lleva horas en cola.
5. El job `despliegue-legacy` lleva la **contraseña de despliegue en claro** en el pipeline.

Jenkins: <http://localhost:8217> · Detalles en `~/TAREA.txt`.

## Objetivos

1. Jenkins corre con un usuario propio (no root), dueño de `JENKINS_HOME`.
2. Sin login no se ve nada (403).
3. Configuración en un YAML de **JCasC** (`CASC_JENKINS_CONFIG`) con seguridad y nodos, **sin contraseñas literales** (`${readFile:/ruta}`).
4. El controlador con **0 ejecutores**; agente `agente-linux` (label `linux`) por **WebSocket**, como servicio y con usuario propio.
5. `humo` en verde en `agente-linux`.
6. Credencial `deploy-pass` (usuario `deploy`) y `despliegue-legacy` usándola con `withCredentials`, publicando bien.

## Pistas

```bash
systemctl cat jenkins; ls /var/lib/jenkins; cat /var/lib/jenkins/config.xml
java -jar /usr/local/share/agent.jar -help
curl -s localhost:8080/manage/configuration-as-code/reference   # tras activar seguridad, con -u
```

No hay internet: los plugins (JCasC, Pipeline, Credentials Binding...) ya están instalados.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
