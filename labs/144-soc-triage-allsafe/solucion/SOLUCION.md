# Solución — Triage en el SOC de Allsafe

## Qué pasaba

El feed mezcla 31 alertas de ruido con 3 reales. El ruido dominante son los
health checks del balanceador interno (`healthcheck_http`, 18 eventos, nivel 2).
Los 3 incidentes reales vienen todos de `203.0.113.7` y encadenan el ataque:

- `ssh_bruteforce_success` (nivel 12): acceso tras 240 fallos.
- `web_shell_upload` (nivel 13): webshell subida.
- `privesc_sudo` (nivel 12): escalada a root.

El escáner `vuln_scan` desde `10.0.5.5` es el equipo de pentest con ventana
aprobada: se vigila, no se escala.

## Arreglo

```bash
soc-stats                                  # ruido dominante + candidatos nivel>=10
jq -c 'select(.nivel>=10)' /var/log/soc/alertas.jsonl
jq -c 'select(.src_ip=="203.0.113.7")' /var/log/soc/alertas.jsonl   # la cadena

# IDs reales (nivel alto):
jq -r 'select(.nivel>=10).id' /var/log/soc/alertas.jsonl | sort | paste -sd,

cat > ~/triage.txt <<'T'
ip_atacante=203.0.113.7
alertas_reales=7031,7032,7033
regla_ruidosa=healthcheck_http
T

# Silenciar SOLO el ruido
sudo tee -a /etc/soc/supresiones.txt <<<'healthcheck_http'

bash /opt/lab/check.sh
```

> Los ids exactos los da `jq -r 'select(.nivel>=10).id' ... | sort`; aquí salen
> 7031, 7032 y 7033, pero cópialos de tu feed por si acaso.

## Más allá del lab

- En Wazuh subirías el nivel/`<if_sid>` de la regla ruidosa o la mandarías a un
  índice aparte; en Loki, una regla de alerta con `for:` y agrupación.
- Documenta por qué silencias algo: el ruido de hoy puede ser señal mañana si
  cambia el origen.
- El escáner autorizado va a una lista de "actividad esperada", con su CHG.
