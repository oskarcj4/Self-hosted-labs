# Defacement de fsociety

> Mr. Robot · integridad de ficheros · AIDE · inotify · restauración

## Escenario

La portada de `allsafe-149` amaneció pintada: "Hacked by fsociety". Un
defacement es vandalismo visible, pero lo importante es doble: **restaurar
rápido** desde una copia buena y **enterarte la próxima vez en el acto**, no
cuando lo vea un cliente.

- El respaldo conocido-bueno está en `/opt/backups/index.html.orig`. Restaurar
  es copiarlo encima; confirma antes que de verdad es el bueno.
- **AIDE** toma una huella (hash + metadatos) de cada fichero y la guarda en
  una base de datos. `aide --check` compara el estado actual contra esa base y
  te dice qué cambió. La línea base se toma **sobre el estado bueno**.
- **inotify** (`inotifywait`) avisa en tiempo real de cambios en el webroot:
  bueno para reaccionar en segundos; AIDE, para auditar a conciencia.

## Objetivos

1. Confirma el defacement y restaura la portada desde el respaldo.
2. Inicia la línea base de AIDE sobre `/var/www` (config en
   `/etc/aide/aide-www.conf`): base en `/var/lib/aide/aide.db` y que
   `aide --check` salga limpio tras restaurar.
3. Deja vigilancia en tiempo real del webroot: un servicio `fim-www` con
   `inotifywait` que escriba en `/var/log/fim.log`, o un cron con `aide --check`.
4. `~/hallazgos.txt`:

   ```
   pagina_afectada=/var/www/html/index.html
   firma_defacement=fsociety
   ```

## Comandos que te pueden servir

```bash
diff /opt/backups/index.html.orig /var/www/html/index.html
sudo cp /opt/backups/index.html.orig /var/www/html/index.html
sudo aide --init -c /etc/aide/aide-www.conf
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
sudo aide --check -c /etc/aide/aide-www.conf          # limpio tras restaurar
sudo systemctl enable --now fim-www.service           # tras crear la unit
sudo tail -f /var/log/fim.log
```

> El orden importa: **restaura primero, toma la línea base después**. Si
> inicias AIDE con la web pintada, estarás "validando" el defacement.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
