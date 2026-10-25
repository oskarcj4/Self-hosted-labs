# xtrace que filtra el secreto

> Pipeline / runtime · CI · set -x · secretos · masking · artefactos

## Escenario

`~/trace-ci` corre `./run-ci.sh`: carga `secrets/deploy_token`, ejecuta
`jobs/*.sh` en orden, guarda `logs/last-run.log` y publica `dist/` como
artefacto del build en `artifacts/` (cualquiera con acceso al CI lo descarga).

Mira la última ejecución. El token sale por **más de un sitio**:

- `set -x` hace que bash imprima cada comando ya expandido. No siempre se
  escribe `set -x`.
- Alguien "ofuscó" el token en base64 para soporte. base64 no es cifrado.
- La cabecera con el token se escribe en `dist/`… y `dist/` se publica.

GitHub/GitLab enmascaran secretos en el log (`***`). Tu runner no. Y el
enmascarado sólo reconoce el valor literal: no salva un base64.

## Objetivos

1. Ni rastro de xtrace en `run-ci.sh` ni en `jobs/`.
2. El log no contiene el token, ni en claro ni en base64.
3. `artifacts/` no contiene el token. La cabecera no se escribe en `dist/`
   (pásala por stdin: `bin/push -`, o un fichero temporal que borres).
4. `run-ci.sh` **enmascara** el valor de `DEPLOY_TOKEN` en todo lo que
   imprimen los jobs. El check añadirá un job que hace `echo $DEPLOY_TOKEN`.
5. El deploy sigue funcionando: `push ok` en el log y `artifacts/ok.txt`.
6. El token sigue en `secrets/deploy_token` (no se arregla borrándolo).

## Comandos que te pueden servir

```bash
cd ~/trace-ci
cat run-ci.sh jobs/*.sh bin/push
grep -rn tclab-trace logs/ artifacts/
grep -rn "$(printf %s tclab-trace-token-do-not-log | base64)" logs/
./run-ci.sh
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
