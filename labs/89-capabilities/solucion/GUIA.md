# Resolución guiada · Lab 89

:::piensa
¿La api hace sysctl, iptables o montajes? Si no, no necesita ninguna capability.
:::

## Paso 1 · Confirma que el HTTP no usa esas caps

```bash
cat ~/caps/api/app.py
```

## Paso 2 · Reescribe compose.yaml

Quita `cap_add`. Pon:

```yaml
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

```bash
cd ~/caps && docker compose up -d
bash /opt/lab/check.sh
```
