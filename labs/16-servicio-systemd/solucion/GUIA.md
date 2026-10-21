# Resolución guiada · Lab 16

:::piensa Antes de tocar nada
Una app que se arranca a mano depende de que alguien se acuerde. systemd se encarga de tres cosas que tú no quieres hacer: **arrancarla al boot**, **relanzarla si cae** y **guardar sus logs**. Sólo tienes que describirle la app en un fichero de unidad.
:::

## Paso 1 · ¿Qué necesita systemd saber?

**Pregúntate:** para gestionar la app, ¿qué tiene que saber systemd? Qué ejecutar, qué hacer si muere y cuándo arrancarla.

**Por qué importa:** esas tres preguntas son las tres secciones de una unidad: `[Unit]`, `[Service]`, `[Install]`.

:::pista Esqueleto
```ini
[Unit]
Description=...
After=network.target

[Service]
ExecStart=<ruta ABSOLUTA del intérprete> <ruta del script>
Restart=always

[Install]
WantedBy=multi-user.target
```
`ExecStart` no usa el `PATH` de tu shell: escribe rutas absolutas (`command -v python3` te la da).
:::

## Paso 2 · Crea la unidad

:::pista Cómo hacerlo
```bash
sudo tee /etc/systemd/system/myapp.service >/dev/null <<'EOF'
[Unit]
Description=My App
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```
:::

## Paso 3 · Que systemd la lea, la habilite y la arranque

**Pregúntate:** ¿qué diferencia hay entre `enable` y `start`? `enable` = "arráncala en cada boot"; `start` = "arráncala ahora". Quieres las dos.

:::pista Cómo hacerlo
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp.service
```
:::

## Paso 4 · Verifica como lo haría un compañero

```bash
systemctl status myapp.service
systemctl is-enabled myapp.service
curl -s localhost:8000
bash /opt/lab/check.sh
```

Si no arranca, el motivo está en `journalctl -u myapp -n 20 --no-pager`.

## Cómo actuar en una situación así

- **Rutas absolutas** en `ExecStart`.
- **Tras editar una unidad**: `daemon-reload` y después `restart`.
- **Prueba el reinicio automático**: mata el proceso (`sudo systemctl kill myapp`) y comprueba que vuelve.
- Siguiente nivel de seguridad: `User=` dedicado, `NoNewPrivileges=yes`, `ProtectSystem=strict` (lab 31).

## Si te atascas

- `status` dice `failed`: lee `journalctl -u myapp`. Suele ser una ruta mal escrita.
- `is-enabled` dice `static`: falta la sección `[Install]`.
