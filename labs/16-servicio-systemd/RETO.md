# Lab 16 — Convierte una app en un servicio de systemd

## Escenario (tarea de operaciones)

En `app-16` hay una app que ahora mismo se arranca a mano (`python3
/opt/app/app.py`) y escucha en el puerto **8000**. Si la máquina reinicia, la app
no vuelve sola. Tu trabajo: convertirla en un **servicio de systemd** que
arranque al boot, se reinicie si se cae y se gestione con `systemctl`.

## Objetivos

1. **Crea la unidad** `/etc/systemd/system/myapp.service` que ejecute
   `python3 /opt/app/app.py`, con `Restart=always`.
2. **Recarga systemd y habilítala** para que arranque en el boot.
3. **Arráncala** y comprueba que el puerto 8000 responde.

## Requisitos de la unidad

- `ExecStart` debe lanzar la app (`/usr/bin/python3 /opt/app/app.py`).
- `WantedBy=multi-user.target` (para que `enable` tenga efecto en el boot).
- El servicio debe quedar **enabled** y **active**.

## Comandos que te pueden servir

```bash
sudoedit /etc/systemd/system/myapp.service   # o: sudo nano ...
sudo systemctl daemon-reload
sudo systemctl enable --now myapp.service
systemctl status myapp.service
curl -s localhost:8000
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
