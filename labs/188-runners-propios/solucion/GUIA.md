# Resolución guiada · Lab 188

:::piensa ¿De quién es el código que ejecuta un runner?
De quien abre el PR. Si el runner acepta PRs de forks, es código de un
desconocido. Trátalo como trataste el código no confiable en los labs de
contenedores: con el mínimo privilegio y sin nada que robar.
:::

## Paso 1 · Mira lo que ve un job

:::pista Cómo hacerlo
```bash
ci-job 'id; env | sort; pwd; ls -la; cat /home/analista/notas.txt'
ci-job 'echo hola > dejado.txt'; ci-job 'ls'
```
:::

## Paso 2 · Usuario y directorio

:::pista Cómo hacerlo
`useradd --system --no-create-home --shell /usr/sbin/nologin ci-runner`,
`chown -R ci-runner: /srv/ci` y `User=ci-runner` en la unidad.
:::

## Paso 3 · Configuración del runner

:::pista Cómo hacerlo
En `runner.ini`: `espacio_efimero = si`, `timeout = 60`,
`etiquetas = linux, x64` y `heredar_entorno = no`. El runner ya sabe matar
el grupo de procesos entero al vencer el timeout.
:::

## Paso 4 · El token

:::pista Cómo hacerlo
Las unidades de `/etc/systemd/system` son legibles por todos, y
`systemctl show` enseña el `Environment=`. Pásalo a `/etc/runner/token.env`
con `chmod 600` y `EnvironmentFile=`: systemd lo lee como root antes de
cambiar de usuario.
:::

## Paso 5 · Sandbox

:::pista Cómo hacerlo
```ini
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/srv/ci
ProtectHome=yes
MemoryMax=1G
```
`systemd-analyze security runner` te dice qué más puedes cerrar.
:::

## Cómo actuar en una situación así

- No ejecutes PRs de forks en runners propios sin aprobación manual. GitHub y GitLab tienen opciones para eso.
- Mejor runners efímeros (una VM o un contenedor por job, destruido al acabar) que un runner persistente endurecido.
- Si sospechas que un job malicioso corrió, rota todo lo que el runner podía ver y reinstala el runner.
