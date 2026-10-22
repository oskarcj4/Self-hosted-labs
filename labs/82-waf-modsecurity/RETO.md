# Lab 82 — Activa un WAF: ModSecurity + OWASP CRS

## Escenario (hardening)

`web-82` tiene **ModSecurity** y el **OWASP Core Rule Set** instalados, pero el
WAF está en modo `DetectionOnly`: ve los ataques y los **apunta en el log**,
pero no bloquea nada. Es un guardia que toma notas y no detiene a nadie.
Enciéndelo en modo bloqueo.

> En Debian el paquete `libapache2-mod-security2` ya deja el CRS cableado
> (`/etc/apache2/mods-available/security2.conf` incluye el `owasp-crs.load`). Lo
> que falta es **encender el motor**: `SecRuleEngine On` en
> `/etc/modsecurity/modsecurity.conf`.

Un WAF (Web Application Firewall) inspecciona cada petición HTTP y bloquea
patrones de ataque de **capa 7**: inyección SQL, XSS, path traversal, scanners y
—con las reglas opcionales del CRS— abuso de endpoints.

## Objetivos

1. **Pon `SecRuleEngine On`** en `/etc/modsecurity/modsecurity.conf`.
2. Deja la **config válida** (`apache2ctl -t`) y Apache sirviendo en el 80.
3. Comprueba que el WAF **bloquea** un ataque de prueba (una SQLi debe dar 403)
   sin romper el tráfico legítimo (200).

## Comandos que te pueden servir

```bash
sudo apache2ctl -M | grep -i security2       # ¿está cargado el módulo?
grep SecRuleEngine /etc/modsecurity/modsecurity.conf
sudo sed -i 's/^SecRuleEngine.*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
sudo apache2ctl -t
sudo service apache2 restart

# legítimo -> 200 ; ataque -> 403
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/
curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1/?q=1%27+OR+%271%27=%271"
sudo tail /var/log/apache2/error.log         # verás la regla del CRS que disparó
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
