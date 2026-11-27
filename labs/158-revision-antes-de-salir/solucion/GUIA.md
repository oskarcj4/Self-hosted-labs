# Resolución guiada · Lab 158

:::piensa Red debajo antes de saltar
Cada punto del checklist de salida es una pregunta que te harás en el peor
momento: ¿y si lo hackean? ¿y si se pierde la base de datos? ¿y si hay que
volver atrás a las 3 de la mañana? Respóndelas ahora, con calma. Y un punto no
está cerrado porque lo marques: está cerrado cuando existe en el sistema.
:::

**El plan:** (1) el servicio sin root, (2) el secreto protegido, (3) backups
programados y probados, (4) runbook, (5) script de rollback y (6) firmar.

## Paso 1 · El servicio, sin root

:::pista Cómo hacerlo
```bash
sudo systemctl show allsafe-api -p User
sudo mkdir -p /etc/systemd/system/allsafe-api.service.d
printf '[Service]\nUser=appuser\n' | sudo tee /etc/systemd/system/allsafe-api.service.d/user.conf
sudo systemctl daemon-reload
sudo systemctl restart allsafe-api
sudo systemctl show allsafe-api -p User
```
- `systemctl show -p User` dice con qué usuario corre (vacío = root).
- Un fichero en `<unidad>.service.d/` (*drop-in*) se suma a la unidad
  original sin modificarla. Es lo mismo que crea `systemctl edit`.

**Qué deberías ver:** `User=` vacío antes y `User=appuser` después.
:::

## Paso 2 · El secreto

:::pista Cómo hacerlo
```bash
ls -l /etc/allsafe/secret.env
sudo chmod 600 /etc/allsafe/secret.env
```
`600`: sólo su dueño lee y escribe. systemd lee el fichero como root antes de
lanzar el servicio, así que la app sigue recibiendo las variables.
:::

## Paso 3 · Backups programados y probados

**Pregúntate:** un backup que nunca ha corrido, ¿existe?

:::pista Cómo hacerlo
El script:
```bash
sudo tee /usr/local/bin/backup.sh >/dev/null <<'S'
#!/usr/bin/env bash
set -e
dst=/var/backups/allsafe/allsafe-$(date +%Y%m%d-%H%M%S).tar.gz
tar czf "$dst" -C /opt allsafe
echo "backup: $dst"
S
sudo chmod +x /usr/local/bin/backup.sh
```
`set -e` para el script si falla un paso (un backup a medias debe fallar, no
decir "hecho"). `tar -C /opt allsafe` entra en `/opt` y empaqueta `allsafe`,
para que dentro del archivo la ruta sea `allsafe/…`.

El servicio (qué ejecutar) y el timer (cuándo):
```bash
sudo tee /etc/systemd/system/allsafe-backup.service >/dev/null <<'U'
[Unit]
Description=Backup de allsafe
[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
U
sudo tee /etc/systemd/system/allsafe-backup.timer >/dev/null <<'T'
[Unit]
Description=Backup diario de allsafe
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
T
sudo systemctl daemon-reload
sudo systemctl enable --now allsafe-backup.timer
systemctl list-timers allsafe-backup.timer
```
- `Type=oneshot`: una tarea que se ejecuta y termina.
- `OnCalendar=daily`: cada día a medianoche (`systemd-analyze calendar daily`
  te dice cuándo es la próxima).
- `Persistent=true`: si la máquina estaba apagada a esa hora, lo ejecuta al
  arrancar.
- `enable` lo deja activado para los próximos arranques; `--now` lo arranca ya.

Y una prueba real:
```bash
sudo /usr/local/bin/backup.sh
ls -l /var/backups/allsafe/
```
:::

## Paso 4 · El runbook

:::pista Cómo hacerlo
Un runbook es lo que leerá quien esté de guardia sin conocer el sistema:
pasos concretos, no descripciones.
```bash
sudo tee /opt/allsafe/RUNBOOK.md >/dev/null <<'R'
# Runbook · allsafe-api

## Despliegue
1. Publicar la versión nueva.
2. `sudo systemctl restart allsafe-api` y comprobar `/healthz`.

## Rollback
Ejecutar `sudo /usr/local/bin/rollback.sh`.
Cuándo: errores 5xx > 2 % durante 5 min, o readiness en rojo.

## Contacto
Guardia SRE: #allsafe-oncall. Escalado: jefatura de plataforma.
R
```
:::

## Paso 5 · El rollback

:::pista Cómo hacerlo
```bash
sudo tee /usr/local/bin/rollback.sh >/dev/null <<'RB'
#!/usr/bin/env bash
set -e
echo "Volviendo a la versión anterior de allsafe-api..."
# en un caso real: apuntar a la versión anterior (tag, digest, enlace) y reiniciar
systemctl restart allsafe-api
echo "rollback hecho."
RB
sudo chmod +x /usr/local/bin/rollback.sh
```
Lo importante es que exista, esté probado y lo pueda ejecutar cualquiera de
la guardia sin pensar.
:::

## Paso 6 · Firma el checklist

:::pista Cómo hacerlo
```bash
sed -i 's/^\[ \]/[x]/' ~/checklist.txt
sed -i 's/^Aprobado por:.*/Aprobado por: analista/' ~/checklist.txt
cat ~/checklist.txt
bash /opt/lab/check.sh
```
`s/^\[ \]/[x]/` cambia cada `[ ]` del principio de línea por `[x]` (los
corchetes van escapados en el patrón porque en una expresión regular `[…]`
significa "uno de estos caracteres").
:::

## Cómo actuar en una situación así

- No marques un punto sin dejarlo demostrado en el sistema: el validador mira
  los artefactos reales, no el texto.
- Convierte el checklist en un paso del pipeline que bloquee la salida.
- Ensaya el rollback antes de necesitarlo.

## Si te atascas

- **`User` sigue vacío:** falta `daemon-reload` o el `restart`.
- **Timer no habilitado:** `enable`, no sólo `start`.
- **El checklist no pasa:** no debe quedar ningún `[ ]` y tiene que haber un
  nombre después de `Aprobado por:`.
