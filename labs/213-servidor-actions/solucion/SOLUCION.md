# Solución — Tu propio GitHub Actions

## Las piezas

| Pieza | Problema | Arreglo |
|-------|----------|---------|
| Gitea | `[actions] ENABLED = false` | `ENABLED = true` y reiniciar |
| Acciones | `DEFAULT_ACTIONS_URL = github` sin internet | `DEFAULT_ACTIONS_URL = self` (usa la org `actions` de la propia forja) |
| Repo | creado con Actions apagado: sin la unidad Actions | Ajustes → Avanzado → Actions, o `PATCH /api/v1/repos/analista/web {"has_actions": true}` |
| Runner | sin registrar, sin servicio | usuario `act-runner`, `generate-config`, `register`, unidad systemd con `User=` |
| Etiquetas | con `--config`, act_runner **ignora `--labels`** y usa `runner.labels`, que por defecto son imágenes Docker | `runner.labels: ["self-hosted:host"]` en el config |
| Workflow | `runs-on: ubuntu-latest` | `runs-on: self-hosted` |
| Disparador | `on: push` (cualquier rama) | `on: push: branches: [main]` |
| Token | en claro y revocado | secreto `DEPLOY_TOKEN` con el valor de `/etc/deployer/token`, pasado por `env:` |

El script completo está en `solve.sh`.

## Por qué cada cosa

- **`:host` frente a `:docker://`**: la parte tras los dos puntos dice *dónde*
  corre el job. `ubuntu-latest:docker://...` pide un contenedor; sin Docker,
  el daemon ni arranca (`Docker Engine socket not found`). `:host` ejecuta
  directamente en la máquina, como el usuario del runner: por eso ese usuario
  no puede ser root.
- **El repo sin Actions**: Gitea decide qué unidades tiene un repo al crearlo.
  Si Actions estaba apagado, encenderlo después no se lo añade a los repos viejos.
- **El secreto por `env:`**: `${{ secrets.X }}` dentro de `run:` se pega en el
  script antes de ejecutarlo; pasarlo como variable de entorno evita que acabe
  en ficheros temporales del runner y que se cuele en una inyección de comandos.
- **Token rotado**: un token que estuvo en un repo está quemado aunque borres
  la línea: sigue en el historial.

## Más allá del lab

- Runners efímeros (un contenedor o una VM por job), y nunca jobs de forks en un runner con secretos.
- Protección de rama en `main` (lab 219) para que nadie despliegue sin revisión.
- En GitHub real, el equivalente es un *self-hosted runner*, y para despliegues, OIDC en lugar de tokens largos.
