# Solución BLUE — Credenciales por defecto y errores verbosos

> Solo la vía defensiva: cerrar las dos fugas sin romper el panel.

## El diagnóstico

`/srv/app/app.py` lee dos claves de `/etc/panel/config.json`:

- `panel_pass`: la contraseña del panel admin. Arranca en `"admin"` — una
  contraseña por defecto que cualquiera prueba primero.
- `verbose_errors`: si está en `true`, `/debug` responde con un traceback que
  incluye el contexto del proceso (y ahí viaja un secreto).

Las dos cosas son configuración, no código: se arreglan en el JSON.

## El arreglo

```bash
cat /etc/panel/config.json       # ver el estado actual
```

Pon una contraseña fuerte y apaga los errores verbosos:

```bash
NEWPASS=$(head -c18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c20)
cat > /etc/panel/config.json <<EOF
{
  "panel_pass": "$NEWPASS",
  "verbose_errors": false
}
EOF
app-reload
echo "panel admin -> admin:$NEWPASS"
```

Verifica:

```bash
curl -s -u admin:admin http://127.0.0.1:8080/panel        # 401 ahora
curl -s -u "admin:$NEWPASS" http://127.0.0.1:8080/panel   # 200 (sigue vivo)
curl -s 'http://127.0.0.1:8080/debug?q=x'                 # 500 genérico, sin TCLAB{
bash /opt/lab/check.sh
```

## Por qué funciona

- **Contraseña por defecto**: `admin:admin` es lo primero que se prueba en un
  ataque. Una contraseña larga y aleatoria quita ese camino; guárdala en un
  gestor, no la reutilices.
- **Errores verbosos**: un traceback en producción filtra rutas, variables y
  secretos. El cliente solo necesita saber que hubo un 500; el detalle va al log
  interno, nunca al cuerpo de la respuesta.

## Lecciones

- Credenciales por defecto = primera puerta que prueba un atacante (OWASP A07).
- No devuelvas trazas al cliente; `debug=off` en producción (OWASP A05).
- Al endurecer, comprueba que lo legítimo sigue funcionando: no basta con cerrar,
  no hay que romper.
