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
Si la inicias con la web pintada, `--check` dirá "limpio" sobre el defacement.
:::

## Paso 3 · Vigilancia en tiempo real

:::pista Cómo hacerlo
Crea `fim-www.service` con `inotifywait -m -r -e modify,create,delete,move -o
/var/log/fim.log /var/www/html` y `enable --now`. Evita `--format` con `%` en la
unit: systemd se come los `%`. Comprueba con `tail -f /var/log/fim.log`.
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
