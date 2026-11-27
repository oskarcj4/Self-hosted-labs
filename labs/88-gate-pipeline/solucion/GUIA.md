# Resolución guiada · Lab 88

:::piensa Un control que no puede parar nada no es un control
Un *gate* de seguridad en un pipeline es un paso que, si falla, impide
desplegar. Aquí el escaneo de secretos detecta la contraseña y falla… pero el
pipeline lo ignora por dos vías: el paso lleva `continue-on-error: true` (su
fallo no cuenta) y `deploy` no depende de él (arranca igual). Hay que arreglar
las dos mitades: el código (el escaneo tiene razón) y el YAML (el pipeline no
le hace caso).
:::

**El plan:** (1) ver el pipeline como está, (2) sacar la contraseña del
código, (3) hacer el gate obligatorio y (4) comprobar.

## Paso 1 · El pipeline como está

:::pista Cómo hacerlo
```bash
cd ~/gate-ci
cat pipeline.yml
cat jobs/secret-scan.sh
./run-ci.sh
```
`run-ci.sh` es un runner mínimo: ejecuta los jobs del YAML y respeta `needs` y
`continue-on-error` como un sistema de CI real.

**Qué deberías ver:** `secret-scan … failed (continue-on-error)` y a
continuación `deploy ok`. El escaneo encontró algo y se desplegó igual.
:::

## Paso 2 · La contraseña, fuera del código

**Pregúntate:** ¿de dónde debería leer la app la contraseña?

:::pista Cómo hacerlo
```bash
cat app/config.py
nano app/config.py
```
Deja la línea así:
```python
import os
PASSWORD = os.environ.get("APP_PASSWORD", "")
```
`os.environ.get("APP_PASSWORD", "")` lee la variable de entorno; si no
existe, queda vacía. El valor real lo pone quien despliega, no el repositorio.
```bash
bash jobs/secret-scan.sh; echo "exit=$?"
```
**Qué deberías ver:** `exit=0`: el escaneo busca un `PASSWORD = "…"` con el
valor escrito, y ya no lo hay.

La contraseña estuvo en el repositorio: en un caso real, **rótala**.
:::

## Paso 3 · El gate, obligatorio

:::pista Cómo hacerlo
Deja `pipeline.yml` así:
```yaml
name: shop-gate
jobs:
  secret-scan:
    run: bash jobs/secret-scan.sh
  deploy:
    needs: [secret-scan]
    run: bash jobs/deploy.sh
```
- Sin `continue-on-error`: si el escaneo falla, el pipeline falla.
- `needs: [secret-scan]`: `deploy` sólo se ejecuta si `secret-scan` terminó
  bien. Sin `needs`, los jobs son independientes y uno no espera al otro.
:::

## Paso 4 · Comprueba

```bash
./run-ci.sh; echo "exit=$?"
ls dist/
bash /opt/lab/check.sh
```
**Qué deberías ver:** `secret-scan ok`, `deploy ok`, `exit=0` y
`dist/deployed.txt`. Para ver el gate en acción, vuelve a poner una contraseña
escrita en `config.py` y ejecuta `./run-ci.sh`: ahora `deploy` no se ejecuta.

## Cómo actuar en una situación así

- `continue-on-error` en un paso de seguridad lo convierte en decoración.
  Si da falsos positivos, se ajusta la regla, no se ignora el resultado.
- El despliegue tiene que depender de **todos** los controles (`needs`).
- Protege la rama principal para que no se pueda saltar el pipeline.

## Si te atascas

- **El escaneo sigue fallando:** queda otro `PASSWORD = "…"` en `app/`;
  `grep -rn PASSWORD app/`.
- **`deploy` sigue ejecutándose con el escaneo en rojo:** falta el `needs` o
  quedó el `continue-on-error`.
