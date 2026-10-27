# Actions sin pin de SHA

> Pipeline / runtime · GitHub Actions · supply chain · tags mutables

## Escenario

`~/gha-pin/.github/workflows/ci.yml` usa refs flotantes (`@v4`, `@v2`,
`@main`). Quien controle el repo de una action puede mover el tag y ejecutar
código en tu runner con tus secretos. Pasó de verdad: en marzo de 2025 alguien
movió casi todos los tags de `tj-actions/changed-files` a un commit que volcaba
secretos en los logs de miles de repos.

Acaba de pasar aquí: lee `SECURITY-ADVISORY.md`.

Tienes un mirror de los repos de las actions en `/srv/gh/<owner>/<repo>.git`.
Con él resuelves cada ref al commit al que apunta.

Y `./pin-scan.sh` dice que hay 3 uses sin pin. Hay más: el escáner no los ve.

## Objetivos

1. `pin-scan.sh` detecta **todo** `uses:` sin pin: steps con `name:` delante,
   reusable workflows a nivel de job, comillas, SHA cortos, SHA sólo en el
   comentario, `docker://` sin digest. Y acepta acciones locales (`./…`),
   `docker://…@sha256:<64 hex>` y `@<sha40> # v1.2.3`. El check trae corpus.
2. Cada `uses:` remoto de `ci.yml` fijado al **commit** (no al objeto tag
   anotado) al que apunta hoy su ref, con `# <versión>` al final.
3. Excepción: `acme/tool` fijado a la última versión buena según el advisory.
4. `./pin-scan.sh` limpio. Ningún step ni job eliminado.

## Comandos que te pueden servir

```bash
cd ~/gha-pin
cat SECURITY-ADVISORY.md .github/workflows/ci.yml
git ls-remote --tags /srv/gh/actions/checkout.git        # ojo con las líneas ^{}
git -C /srv/gh/actions/checkout.git rev-parse 'v4^{commit}'
git -C /srv/gh/acme/tool.git log --oneline --decorate --all
git -C /srv/gh/acme/tool.git show v1:action.yml
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
