# Línea base contra rootkits (rkhunter)

> Defensa del host · rkhunter · chkrootkit · debsums · línea base

## Escenario

`srv-prod-01` se instaló ayer y mañana se expone a Internet. Te toca la
auditoría inicial (`~/ticket/TAREA-111.txt`). rkhunter compara el sistema con
una **línea base**: lo que guardes hoy es lo que dará por "bueno" siempre.
Así que antes de guardarla, asegúrate de que el sistema está sano.

`/mnt/offsite` es un volumen aparte: hace de "otro servidor" donde guardar la
línea base y los reportes.

## Objetivos

1. Verifica los binarios contra el gestor de paquetes **antes** de tomar la
   línea base. Si algo no cuadra, investígalo y restáuralo desde
   `/var/cache/paquetes-oficiales/` (no hay red).
2. Elimina lo que el binario alterado escondía (proceso y ficheros).
3. Toma la línea base (`rkhunter --propupd`) y lanza un análisis completo.
4. Pasa también `chkrootkit`.
5. En `/mnt/offsite/` deja: `rkhunter.dat` (copia de la línea base), el log
   de rkhunter (`*rkhunter*.log`), la salida de chkrootkit (`*chkrootkit*`) e
   `informe.txt` con el hallazgo real y cada Warning clasificado
   (`falso positivo` + motivo, o real).

## Comandos que te pueden servir

```bash
sudo debsums -c
dpkg -S /usr/bin/ps ; file /usr/bin/ps ; cat /usr/bin/ps
sudo dpkg -i /var/cache/paquetes-oficiales/procps_*.deb
sudo rkhunter --propupd
sudo rkhunter --check --sk
sudo grep -i warning /var/log/rkhunter.log
sudo chkrootkit
```

> Nota: los rootkits de **kernel** (módulos LKM) no se pueden simular en
> Docker: el kernel es el del host. Para eso hace falta una VM.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
