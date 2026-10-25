# Gate de seguridad saltado

> Pipeline / runtime · CI · gate · continue-on-error

## Escenario

`~/gate-ci` despliega aunque el scan de secretos falle. En `pipeline.yml` el job
`secret-scan` tiene `continue-on-error: true` y `deploy` **no** lo declara en
`needs`. `app/config.py` lleva una contraseña en claro; por eso el scan sale
rojo... y el deploy sale verde igual. Mira `./run-ci.sh` (el runner respeta
`needs` y `continue-on-error`).

## Objetivos

1. El pipeline **no** usa `continue-on-error: true`.
2. `deploy` tiene `needs: [secret-scan]` (el gate es obligatorio).
3. `app/` ya no tiene `PASSWORD = "..."`.
4. `./run-ci.sh` termina 0 y escribe `dist/deployed.txt`.

## Comandos que te pueden servir

```bash
cd ~/gate-ci
cat pipeline.yml app/config.py
./run-ci.sh
bash jobs/secret-scan.sh
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
