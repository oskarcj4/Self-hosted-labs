# Solución — Lab 84

```bash
# 1) mitigación: bloquear rangos confirmados...
while read -r net; do
  [ -n "$net" ] && sudo iptables -I INPUT -s "$net" -j DROP
done < /etc/ddos/blocklist.txt

# ...y/o rate limit de seguridad al 80
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW \
  -m hashlimit --hashlimit-above 25/sec --hashlimit-burst 50 \
  --hashlimit-mode srcip --hashlimit-name http -j DROP

# 2) postmortem
cat > /home/analista/postmortem.md <<'EOF'
# Postmortem — DDoS web-84
## Impacto
~40 min de 503 en /buscar; sin pérdida de datos.
## Cronología
11:30 pico; 11:35 saturación; 11:40 triage; 11:50 mitigado.
## Mitigación
Bloqueo de 203.0.113.0/24 y 198.51.100.0/24 + hashlimit 25/s por IP en el 80.
## Prevención
Rate limit en reverse proxy, mod_evasive/reqtimeout, alerta por 5xx, evaluar CDN.
EOF

# 3) verificar servicio
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/
bash /opt/lab/check.sh
```

## Lecciones

- Cerrar un incidente = mitigación **duradera** + documentación, no sólo "volvió
  el servicio".
- Bloqueo por rango (preciso contra lo conocido) + rate limit (red de seguridad
  contra lo nuevo) se complementan.
- Postmortem *blameless*: impacto, cronología, mitigación, prevención con dueño y
  fecha.
- Persiste las reglas (`iptables-save` / `netfilter-persistent`).
