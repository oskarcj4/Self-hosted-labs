# Solución — Pipeline completo

```yaml
skip_clone: true
steps:
  - name: clone
    image: bash
    commands:
      - git clone -q "$CI_REPO_CLONE_URL" .
      - git checkout -q "$CI_COMMIT_SHA"
  - name: test
    image: bash
    commands: [python3 -m unittest -v]
  - name: scan
    image: bash
    commands: [gitleaks dir . --no-banner]
  - name: build
    image: bash
    commands: ['bash ci/build.sh "$CI_COMMIT_SHA"']
  - name: publish
    image: bash
    commands: ['docker push -q "$(cat .image)"']
  - name: deploy
    image: bash
    commands: ['bash ci/deploy.sh "$(cat .image)"']
```

`ci/build.sh`: `docker build -t localhost:5000/api:${1:0:12} .` y escribe el
nombre en `.image`.

`ci/deploy.sh`:
```bash
OLD=$(docker inspect -f '{{.Config.Image}}' api 2>/dev/null || true)
run "$NEW"
for _ in $(seq 1 20); do curl -fs localhost:8080/health && exit 0; sleep 1; done
[ -n "$OLD" ] && run "$OLD"     # rollback
exit 1
```

`config.py`: `GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")`.

## Por qué cada pieza

| Step | Protege de |
|------|-----------|
| test | desplegar código que no cumple su contrato |
| scan | publicar secretos (gitleaks) |
| build por SHA | no saber qué corre; no poder volver atrás |
| publish | que el despliegue dependa de la máquina que construyó |
| deploy + health + rollback | que un arranque roto deje producción caída |

## Más allá del lab

- Despliega por **digest** (`@sha256:...`) además de por tag: inmutable de verdad.
- Añade escaneo de vulnerabilidades (Trivy, lab 174) y firma (cosign, lab 219).
- El token filtrado se revoca en GitHub; quitarlo del código no basta.
