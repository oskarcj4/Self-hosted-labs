# Resolución guiada · Lab 158

:::piensa Red debajo antes de saltar
Cada punto del checklist es una pregunta del peor momento: ¿y si lo hackean?
¿y si se pierde la base de datos? ¿y si hay que volver atrás? Respóndelas ahora.
:::

## Paso 1 · Seguridad

:::pista Cómo hacerlo
```bash
sudo systemctl edit allsafe-api     # [Service] \n User=appuser
sudo systemctl daemon-reload && sudo systemctl restart allsafe-api
sudo chmod 600 /etc/allsafe/secret.env
```
:::

## Paso 2 · Backups con timer

:::pista Cómo hacerlo
`backup.sh` que empaqueta a `/var/backups/allsafe/`, un `.service` oneshot y un
`.timer` `OnCalendar=daily`:
```bash
sudo chmod +x /usr/local/bin/backup.sh
sudo systemctl enable allsafe-backup.timer
sudo /usr/local/bin/backup.sh      # prueba: deja un backup real
```
:::

## Paso 3 · Runbook y rollback

:::pista Cómo hacerlo
`/opt/allsafe/RUNBOOK.md` con `## Despliegue`, `## Rollback`, `## Contacto`.
`/usr/local/bin/rollback.sh` ejecutable que reinicia a la versión previa.
:::

## Paso 4 · Firmar el checklist

:::pista Cómo hacerlo
```bash
sed -i 's/^\[ \]/[x]/' ~/checklist.txt
sed -i 's/^Aprobado por:.*/Aprobado por: analista/' ~/checklist.txt
```
:::

## Cómo actuar en una situación así

- No marques un punto sin dejarlo demostrado en el sistema; el check mira los
  artefactos reales, no solo el texto.
- Convierte el checklist en un gate del pipeline para que nadie se lo salte.

## Si te atascas

- `User` sigue root: ¿reiniciaste tras el override? `systemctl show -p User`.
- Timer no habilitado: `systemctl enable allsafe-backup.timer` (no solo start).
- Checklist: deben quedar 0 líneas `[ ]` y una firma tras `Aprobado por:`.
