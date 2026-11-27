# Resolución guiada · Lab 149

:::piensa Dos trabajos
Restaurar (rápido, visible) y detectar la próxima vez (silencioso, preventivo).
El orden entre ellos no es negociable: primero restauras, luego fijas la base.
:::

## Paso 1 · Confirma y restaura

:::pista Cómo comprobarlo
```bash
diff /opt/backups/index.html.orig /var/www/html/index.html
sudo cp /opt/backups/index.html.orig /var/www/html/index.html
curl -s localhost | head
```
:::

## Paso 2 · Línea base de AIDE

**Pregúntate:** si inicio la base ahora, ¿qué estoy declarando "correcto"?

:::pista Cómo hacerlo
```bash
sudo aide --init -c /etc/aide/aide-www.conf
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
sudo aide --check -c /etc/aide/aide-www.conf      # debe salir limpio
```
**AIDE** guarda una huella (hashes, permisos, fechas) de cada fichero vigilado
en una base de datos. `--init` la crea en `aide.db.new`; al copiarla a
`aide.db` pasa a ser la referencia; `--check` compara el disco con ella.
Si la inicias con la web pintada, `--check` dirá "limpio" sobre el defacement.
:::

## Paso 3 · Vigilancia en tiempo real

:::pista Cómo hacerlo
```bash
sudo tee /etc/systemd/system/fim-www.service >/dev/null <<'U'
[Unit]
Description=Vigilancia de integridad de /var/www/html
[Service]
ExecStart=/usr/bin/inotifywait -m -r -e modify,create,delete,move -o /var/log/fim.log /var/www/html
Restart=always
[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload
sudo systemctl enable --now fim-www
echo prueba | sudo tee /var/www/html/x.txt >/dev/null; sleep 1; sudo tail -2 /var/log/fim.log
sudo rm /var/www/html/x.txt
```
- `inotifywait` recibe del kernel un aviso por cada cambio: `-m` sigue
  escuchando, `-r` incluye subcarpetas, `-e` elige los eventos y `-o` escribe en
  un fichero.
- AIDE compara contra la base cuando lo ejecutas; inotify avisa **en el
  momento**. Son complementarios.
- No uses `--format` con `%` dentro de una unidad: systemd interpreta los `%`
  como sus propias variables.

**Qué deberías ver:** líneas `CREATE x.txt` / `MODIFY x.txt` en el log.
:::

## Paso 4 · Documenta

:::pista Cómo hacerlo
`~/hallazgos.txt` con `pagina_afectada=` y `firma_defacement=fsociety`.
:::

## Cómo actuar en una situación así

- Un defacement casi siempre entra por otra puerta (webshell, CMS sin parchear):
  restaurar la portada no cierra la vía. Busca el cómo.
- Integridad + webroot inmutable = el cambio no solo se ve, no debería ni poder
  ocurrir en caliente.

## Si te atascas

- `aide --check` da diferencias: reiniciaste la base antes de restaurar, o
  tocaste ficheros después. Vuelve a `--init` sobre el estado bueno.
- `fim-www` no arranca ("bad unit file setting"): quitaste los `%%` o usaste
  `--format "%T..."`; usa `-o fichero` con el formato por defecto.
