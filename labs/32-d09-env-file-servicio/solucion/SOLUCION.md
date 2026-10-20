# Solución — Día 09: Proteger el env file de un servicio

## 1. Diagnóstico

```bash
ls -la /etc/notifier/
# -rw-r--r-- root root notifier.env
# -rw-r--r-- root root notifier.env.bak
cat /etc/notifier/notifier.env      # ¡analista lee SMTP_PASSWORD!
```

## 2. ¿Quién lee el env file?

**systemd (PID 1, root)** lo lee *antes* de lanzar el proceso y le pasa las
variables ya cargadas. El servicio (`User=notifier`) nunca abre el fichero.
Por eso basta con que lo lea root:

```bash
sudo chown root:root /etc/notifier/notifier.env
sudo chmod 0600 /etc/notifier/notifier.env
```

## 3. La copia olvidada

```bash
sudo rm /etc/notifier/notifier.env.bak
# (o, si hay que conservarla: sudo chmod 0600 y moverla a /root/)
sudo grep -rl 'mXq-7Rt' /etc /opt /home /tmp 2>/dev/null   # nada legible queda
```

## 4. Verificar que el servicio sigue cargándolo

```bash
sudo systemctl restart notifier
curl -s http://127.0.0.1:8500/      # smtp configured, webhook configured
cat /etc/notifier/notifier.env      # Permission denied (como analista)
```

## Por qué no poner los secretos en la unidad

`Environment=SMTP_PASSWORD=...` dentro de `notifier.service` parece cómodo,
pero los ficheros de unidad son `0644` y `systemctl cat` / `systemctl show`
los muestran **a cualquier usuario**. Además el secreto acaba en el entorno
del proceso (lo verás en el día 12).

## Lecciones

- `EnvironmentFile=` lo lee systemd como root: `0600 root:root` es suficiente.
- Las copias (`.bak`, `.orig`, `~`, `.swp`) son la fuga más común de secretos.
- Si estuvo expuesto, en un caso real: **rotar** SMTP_PASSWORD y WEBHOOK_TOKEN.
- Mejor aún: `LoadCredential=` de systemd o un gestor de secretos.
