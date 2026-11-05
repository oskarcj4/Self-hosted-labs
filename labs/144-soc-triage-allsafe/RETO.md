# Triage en el SOC de Allsafe

> Mr. Robot · SOC · triage de alertas · señal vs ruido · cadena de ataque

## Escenario

Turno de noche en el SOC. El SIEM escupe cientos de alertas y el equipo está
**ciego por ruido**: health checks, inicios de sesión normales y un escáner de
vulnerabilidades *autorizado* ahogan lo que de verdad importa. Entre todo ese
ruido hay **3 alertas reales** que forman una cadena de ataque.

- No todo lo que es nivel alto es incidente, y no todo lo rutinario es inocuo.
  Pero un patrón ayuda: **nivel alto + origen externo + acciones encadenadas**
  (acceso → webshell → escalada).
- Un escáner con ventana aprobada (CHG-…) es actividad esperada: se vigila,
  no se escala como incidente.
- Silenciar ruido no es taparse los ojos: es dejar de disparar alertas que
  nunca son accionables, para no perder las que sí.

## Objetivos

1. Analiza `/var/log/soc/alertas.jsonl` (usa `soc-stats`) y escribe `~/triage.txt`:

   ```
   ip_atacante=<IP de los incidentes reales>
   alertas_reales=<ids separados por coma>
   regla_ruidosa=<la regla de bajo nivel a silenciar>
   ```

2. Silencia esa regla: añádela a `/etc/soc/supresiones.txt` (una por línea).
   No silencies un incidente real ni el escáner (ese se vigila).

## Comandos que te pueden servir

```bash
soc-stats
jq -c 'select(.nivel>=10)' /var/log/soc/alertas.jsonl        # candidatos a incidente
jq -r .regla /var/log/soc/alertas.jsonl | sort | uniq -c | sort -rn
jq -c 'select(.src_ip=="203.0.113.7")' /var/log/soc/alertas.jsonl
sudo tee -a /etc/soc/supresiones.txt <<<'healthcheck_http'
```

> En un SOC real esto es Wazuh/Loki: subir el umbral de una regla, agruparla
> o mandarla a un canal de baja prioridad. El criterio es el mismo: ¿esta
> alerta cambia lo que hago? Si nunca, es ruido.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
