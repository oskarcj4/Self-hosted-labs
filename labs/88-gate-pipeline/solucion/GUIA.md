# Resolución guiada · Lab 88

:::piensa
Hay dos mitades: el código (el scan tiene razón) y el YAML (el pipeline ignora
al scan). Hace falta las dos.
:::

## Paso 1 · Corre el pipeline como está

```bash
cd ~/gate-ci && ./run-ci.sh
```

Verás `failed (continue-on-error)` y luego `deploy ok`.

## Paso 2 · Saca la contraseña de config.py

Usa `os.environ.get("APP_PASSWORD", "")`. El scan busca `PASSWORD = "..."`.

## Paso 3 · YAML

Quita `continue-on-error`. En `deploy` añade `needs: [secret-scan]`.

```bash
./run-ci.sh
bash /opt/lab/check.sh
```
