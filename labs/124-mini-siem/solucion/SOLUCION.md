# Solución — Mini SIEM: detección mapeada a la Kill Chain

## Qué pasaba

Loki recibía logs de nginx y auth de tres servidores, pero no había ninguna
regla: la intrusión en curso (escaneo, subida de ejecutable, fuerza bruta SSH,
cuenta UID 0, volcado y exfiltración) no generaba alertas.

## Arreglo

`/etc/siem/reglas/deteccion.yml`:

```yaml
groups:
  - name: deteccion
    rules:
      - alert: EscaneoWeb
        expr: sum by (host) (count_over_time({job="nginx"} |~ "\" 404 " [5m])) > 5
        labels: {severity: low, kill_chain: reconocimiento}
      - alert: SubidaDeEjecutable
        expr: sum by (host) (count_over_time({job="nginx"} |~ "POST /api/upload\\?name=[^ ]*\\.(sh|php|exe|elf)" [10m])) > 0
        labels: {severity: high, kill_chain: entrega}
      - alert: FuerzaBrutaSSH
        expr: sum by (host) (count_over_time({job="auth"} |= "Failed password" [5m])) > 10
        labels: {severity: high, kill_chain: explotacion}
      - alert: CuentaUID0
        expr: sum by (host) (count_over_time({job="auth"} |~ "useradd.*UID=0" [15m])) > 0
        labels: {severity: critical, kill_chain: instalacion}
      - alert: VolcadoYExfiltracion
        expr: sum by (host) (count_over_time({job="auth", host="db-01"} |~ "COMMAND=.*(pg_dump|curl -T)" [15m])) > 0
        labels: {severity: critical, kill_chain: acciones}
```

Comprueba y documenta:

```bash
curl -s http://loki:3100/prometheus/api/v1/alerts | jq '.data.alerts[] | {a:.labels.alertname, s:.state}'
nano ~/soc.md
bash /opt/lab/check.sh
```

`soc.md`: antivirus (firmas en un equipo), EDR (comportamiento del endpoint y
respuesta), SIEM (centraliza y correlaciona logs); N1 triage, N2 investigación
y respuesta, N3 caza e ingeniería de detección.

## Más allá del lab

- Envía las alertas a Alertmanager y de ahí a un canal de guardia.
- Mapea también a MITRE ATT&CK (más fino que la Kill Chain).
- Versiona las reglas en git y pruébalas en CI (detection as code).
