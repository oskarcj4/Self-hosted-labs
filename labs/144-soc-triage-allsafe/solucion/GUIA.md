# Resolución guiada · Lab 144

:::piensa ¿Esto cambia lo que hago esta noche?
Un SOC no se ahoga por falta de alertas, sino por exceso. Triar es hacerse una
pregunta con cada una: ¿cambia lo que hago esta noche? Un health check, nunca.
Un acceso externo seguido de una webshell, siempre. Y silenciar lo que nunca
es accionable no es taparse los ojos: es lo que permite ver lo que sí lo es.
:::

**El plan:** (1) ver la forma del ruido, (2) encontrar la cadena de ataque,
(3) no confundir el escáner autorizado, y (4) escribir el triage y silenciar.

## Paso 1 · La forma del ruido

:::pista Cómo hacerlo
```bash
soc-stats
jq -r .regla /var/log/soc/alertas.jsonl | sort | uniq -c | sort -rn | head
```
- `soc-stats` es un comando del lab que resume las alertas por regla y nivel.
- El fichero es **JSON Lines**: un objeto JSON por línea. `jq -r .regla`
  saca el campo `regla` de cada uno, en texto plano (`-r`); `sort | uniq -c |
  sort -rn` cuenta cuántas hay de cada una.

**Qué deberías ver:** `healthcheck_http` con cientos de disparos y nivel
bajo. Nunca lleva a ninguna acción: es ruido.
:::

## Paso 2 · La cadena de ataque

**Pregúntate:** ¿hay un mismo origen detrás de varias alertas graves?

:::pista Cómo hacerlo
```bash
jq -c 'select(.nivel>=10)' /var/log/soc/alertas.jsonl
jq -r 'select(.nivel>=10).src_ip' /var/log/soc/alertas.jsonl | sort -u
```
`select(condición)` deja pasar sólo los objetos que la cumplen; `-c` imprime
cada uno en una línea.

**Qué deberías ver:** tres alertas, todas desde `203.0.113.7`, en orden:
acceso → webshell → escalada de privilegios. Eso es una historia, no tres
alertas sueltas.
:::

## Paso 3 · El escáner autorizado

:::pista Qué mirar
```bash
jq -c 'select(.regla=="vuln_scan")' /var/log/soc/alertas.jsonl | head -3
```
`vuln_scan` desde `10.0.5.5` dice "ventana aprobada CHG-2271": es el equipo de
pentest. No es un incidente, pero **tampoco se silencia**: si un día ese
patrón viene de otra IP o fuera de la ventana, quieres verlo.
:::

## Paso 4 · El triage y la supresión

:::pista Cómo hacerlo
```bash
jq -r 'select(.nivel>=10).id' /var/log/soc/alertas.jsonl | sort | paste -sd,
```
`paste -sd,` une todas las líneas en una, separadas por comas.
```bash
cat > ~/triage.txt <<'T'
ip_atacante=203.0.113.7
alertas_reales=<los ids que acaba de imprimir>
regla_ruidosa=healthcheck_http
T
sudo tee -a /etc/soc/supresiones.txt <<<'healthcheck_http'
bash /opt/lab/check.sh
```
`<<<'texto'` (*here-string*) pasa ese texto como entrada del comando. `tee -a`
lo añade al final del fichero sin borrar lo que hubiera.
:::

## Cómo actuar en una situación así

- Cada alerta accionable lleva una acción; cada regla que se baja, una
  justificación escrita.
- Mide el ratio señal/ruido: si el 90 % de las alertas nunca se acciona, el
  SOC no escala.
- Ante una cadena así: aislar el servidor, bloquear la IP y empezar la
  respuesta a incidentes, no sólo "cerrar la alerta".

## Si te atascas

- **`alertas_reales` no cuadra:** usa exactamente los ids de
  `select(.nivel>=10)`.
- **El check marca error en las supresiones:** no pongas `vuln_scan` ni
  ninguna de las reglas de la cadena.
