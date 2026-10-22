# Solución — Lab 82

```bash
# El CRS ya viene cargado por el paquete; sólo hay que encender el motor.
sudo sed -i 's/^SecRuleEngine.*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
sudo apache2ctl -t
sudo service apache2 restart
```

Probar:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/                         # 200
curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1/?q=1%27+OR+%271%27=%271" # 403
bash /opt/lab/check.sh
```

## Lecciones

- `DetectionOnly` no protege: hay que pasar a `On`. En Debian el CRS ya está
  incluido por el paquete; no dupliques includes (IDs repetidos → Apache no
  arranca).
- Valida siempre con un ataque de prueba (403) y con tráfico legítimo (200): un
  WAF que bloquea todo es tan inútil como uno que no bloquea nada.
- El WAF cubre capa 7; contra floods volumétricos van firewall/CDN (labs 83/84 y
  el curso 14).
- En producción: despliega en detección, caza falsos positivos, luego bloquea.
