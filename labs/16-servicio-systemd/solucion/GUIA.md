# Resolución guiada · Lab 16

:::piensa Antes de tocar nada
Una app que se arranca a mano depende de que alguien se acuerde. systemd se
encarga de tres cosas que tú no quieres hacer: **arrancarla al encender la
máquina**, **relanzarla si se cae** y **guardar sus logs**. Sólo tienes que
describirle la app en un fichero de texto: una **unidad**.
:::

**El plan:** (1) entender qué necesita saber systemd, (2) escribir la unidad,
(3) cargarla, habilitarla y arrancarla y (4) comprobar que se relanza sola.

## Paso 1 · ¿Qué necesita saber systemd?

**Objetivo:** entender las tres secciones de una unidad antes de escribirla.

**Pregúntate:** para gestionar la app, ¿qué tiene que saber systemd? Qué
ejecutar, qué hacer si muere y cuándo arrancarla.

:::pista Cómo es una unidad
Esas tres preguntas son las tres secciones del fichero:

| Sección | Para qué |
|---|---|
| `[Unit]` | Descripción y orden respecto a otras unidades. |
| `[Service]` | Qué ejecutar y cómo comportarse si termina. |
| `[Install]` | Cuándo arrancarla al encender la máquina. Sólo la usa `systemctl enable`. |

Antes de escribirla, averigua la ruta completa del intérprete:
```bash
command -v python3
```
`command -v` dice qué fichero ejecutaría la shell para ese nombre. systemd
**no** usa el `PATH` de tu terminal: en `ExecStart` las rutas van completas.

**Qué deberías ver:** `/usr/bin/python3`.
:::

## Paso 2 · Crea la unidad

**Objetivo:** el fichero `/etc/systemd/system/myapp.service`.

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
`sudo tee fichero` escribe lo que le llega en un fichero de root (un
`sudo echo … > fichero` no funcionaría: la redirección `>` la hace tu shell,
sin privilegios). `>/dev/null` evita que `tee` repita el texto en pantalla.

| Directiva | Qué significa |
|---|---|
| `After=network.target` | Si ambas arrancan a la vez, ésta va después de que la red esté configurada. Es sólo **orden**, no obliga a arrancar la red. |
| `ExecStart=` | El comando que lanza la app. Ese proceso es el "proceso principal" que systemd vigila. |
| `Restart=always` | Si el proceso termina por lo que sea (error, señal o incluso saliendo bien), systemd lo vuelve a lanzar. `on-failure` sólo lo haría si termina con error. |
| `WantedBy=multi-user.target` | `multi-user.target` es el estado normal de un servidor arrancado. `enable` engancha la unidad ahí para que arranque con él. |
:::

## Paso 3 · Que systemd la lea, la habilite y la arranque

**Pregúntate:** ¿qué diferencia hay entre `enable` y `start`?

:::pista Cómo hacerlo
`enable` = "arráncala en cada encendido"; `start` = "arráncala ahora". Quieres
las dos.
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp.service
```
- `daemon-reload`: systemd no vigila la carpeta; hay que decirle que relea
  las unidades tras crear o editar una.
- `enable` crea un enlace en `/etc/systemd/system/multi-user.target.wants/`;
  `--now` además la arranca en el momento.

**Qué deberías ver:** una línea `Created symlink …multi-user.target.wants/myapp.service`.
:::

## Paso 4 · Verifica, y prueba que se levanta sola

```bash
systemctl status myapp.service --no-pager
systemctl is-enabled myapp.service
curl -s localhost:8000
```
**Qué deberías ver:** `active (running)`, `enabled` y `myapp ok`.

Ahora comprueba el `Restart=always`: mata el proceso y mira si vuelve.
```bash
systemctl show -p MainPID --value myapp       # PID actual
sudo systemctl kill myapp                     # le manda SIGTERM, como si se cayera
sleep 1
systemctl show -p MainPID --value myapp       # otro PID: se relanzó sola
bash /opt/lab/check.sh
```
`systemctl kill` envía una señal al proceso sin "parar" la unidad: para
systemd es una caída, no una parada pedida, así que la relanza. (Con
`systemctl stop` no la relanzaría: le has pedido tú que pare.)

## Cómo actuar en una situación así

- **Rutas absolutas** en `ExecStart`.
- **Tras editar una unidad:** `daemon-reload` y después `restart`.
- Los logs de la app quedan en el journal: `journalctl -u myapp -f`.
- Siguiente nivel: un usuario propio (`User=`), `NoNewPrivileges=yes`,
  `ProtectSystem=strict` (lab 31).

## Si te atascas

- **`status` dice `failed`:** `journalctl -u myapp -n 20 --no-pager` dice por
  qué. Suele ser una ruta mal escrita en `ExecStart`.
- **`is-enabled` dice `static`:** falta la sección `[Install]`, así que
  `enable` no tiene dónde engancharla.
- **`Unit myapp.service not found`:** no hiciste `daemon-reload`, o el fichero
  no acaba en `.service`.
