# Solución BLUE — SSRF en el proxy de estado

> Solo la vía defensiva: cerrar el SSRF sin romper el health legítimo.

## El diagnóstico

`/srv/app/app.py` expone `/fetch?url=...` que hace `urlopen(url)` desde el
servidor. Con `restrict_targets: false`, trae **cualquier** URL, incluida
`http://127.0.0.1:8081/...`, el servicio interno de metadatos que solo escucha en
loopback. Eso es SSRF: el servidor es tu proxy hacia su propia red interna.

La app ya trae una `allowlist` con el único destino legítimo; solo falta
activarla.

## El arreglo

```bash
cat /etc/panel/config.json
cat > /etc/panel/config.json <<'JSON'
{
  "restrict_targets": true,
  "allowlist": ["http://status.lab:8080/health"]
}
JSON
app-reload
```

Verifica:

```bash
curl -s 'http://127.0.0.1:8080/fetch?url=http://127.0.0.1:8081/user'   # 403, sin TCLAB
curl -s 'http://127.0.0.1:8080/fetch?url=http://status.lab:8080/health' # OK
bash /opt/lab/check.sh
```

## Por qué funciona

- **Default-deny**: con `restrict_targets: true`, cualquier destino que no esté
  en la allowlist se rechaza (403). El metadata interno deja de ser alcanzable.
- **La allowlist es una lista corta y explícita**: solo el health legítimo. Es
  mucho más robusto que una denylist de IPs internas, que siempre se puede
  esquivar (DNS rebinding, representaciones raras de 127.0.0.1, IPv6, redirects).

## Defensa en profundidad (más allá del lab)

- Valida el destino **tras resolver DNS**, y re-valida tras cada redirect.
- Bloquea rangos privados y loopback (10/8, 172.16/12, 192.168/16, 127/8,
  169.254/16, `::1`, fc00::/7) además de la allowlist.
- El servicio de metadatos no debería confiar en "viene de loopback": pide auth.
- Da al proxy una salida de red segmentada, sin ruta a la red interna.

## Lecciones

- SSRF (OWASP A10): si tu servidor trae URLs que da el usuario, él elige el
  destino. Restríngelo tú.
- Allowlist corta y explícita > denylist de IPs.
- Cerrar sin romper: el health legítimo debe seguir pasando.
