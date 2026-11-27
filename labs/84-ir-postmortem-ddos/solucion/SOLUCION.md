# Solución — Lab 84

```bash
# 0) evidencia (los logs de Apache sólo los lee root/adm)
sudo awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head
sudo awk '{print $4}' /var/log/apache2/access.log | sort | sed -n '1p;$p'

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
800 peticiones a /buscar con 503 entre 11:30 y 11:35 UTC, desde 80 IP de
203.0.113.0/24 y 198.51.100.0/24. Sin pérdida de datos.
## Cronología (access.log)
11:30:00 primera petición del ataque; 11:35:05 última; rangos confirmados en la blocklist.
## Mitigación
Bloqueo de 203.0.113.0/24 y 198.51.100.0/24 + hashlimit 25/s por IP en el 80.
## Prevención
Persistir reglas (iptables-save), rate limit en reverse proxy, alerta por 5xx, evaluar CDN.
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
