# Resolución guiada · Lab 111

:::piensa Antes de tocar nada
Si `ps` miente, todo lo que veas con `ps` es sospechoso. La pregunta no es
"¿qué procesos hay?" sino "¿puedo fiarme de la herramienta que me lo dice?".
:::

Orden mental: **verificar herramientas → encontrar lo oculto → restaurar → línea base → guardarla fuera**.

## Paso 1 · ¿Los binarios son los del paquete?

**Pregúntate:** ¿qué fuente conoce el hash original de cada fichero instalado por apt?

**Por qué importa:** dpkg guarda los md5 de cada paquete. `debsums` los compara con lo que hay en disco.

:::pista Cómo comprobarlo
```bash
sudo debsums -c          # sólo los ficheros cambiados
file $(which ps); head -5 $(which ps)
```
Un `ps` que es un script de shell no es el `ps` de procps.
:::

## Paso 2 · ¿Qué escondía?

**Pregúntate:** si `ps` filtra un nombre, ¿qué otra fuente lista procesos sin pasar por `ps`?

:::pista Cómo comprobarlo
```bash
ls /proc | grep -E '^[0-9]+$' | while read p; do echo "$p $(cat /proc/$p/comm 2>/dev/null)"; done
systemctl list-units --type=service | grep -v '^  systemd'
```
Busca `kswapd-upd`: un nombre que imita un hilo del kernel, pero que corre como servicio.
:::

## Paso 3 · Restaura y limpia

**Pregúntate:** ¿de dónde saco un `ps` confiable? No lo copies de otra máquina: reinstala el paquete oficial.

:::pista Cómo hacerlo
```bash
sudo dpkg -i /var/cache/paquetes-oficiales/procps_*.deb
sudo debsums -s procps                       # sin salida = íntegro
sudo systemctl disable --now kswapd-upd
sudo rm -f /usr/local/sbin/kswapd-upd /usr/lib/x86_64-linux-gnu/libprocps-cache.so.0
```
:::

## Paso 4 · Línea base y revisión

**Pregúntate:** rkhunter compara contra una base de datos de propiedades. Si la creas con el troyano dentro, ¿qué consigues?

:::pista Cómo hacerlo
```bash
sudo rkhunter --propupd                      # SÓLO con el sistema ya limpio
sudo rkhunter --check --sk
sudo chkrootkit
```
Los avisos de un contenedor recién instalado (ficheros ocultos de systemd, etc.) son falsos positivos: anótalos, no los "arregles".
:::

## Paso 5 · Fuera del equipo

**Pregúntate:** si el atacante vuelve con root, ¿qué le impide reescribir `rkhunter.dat`?

:::pista Cómo hacerlo
```bash
sudo cp /var/lib/rkhunter/db/rkhunter.dat /var/log/rkhunter.log /mnt/offsite/
sudo sh -c 'chkrootkit > /mnt/offsite/chkrootkit.txt 2>&1'
sudo nano /mnt/offsite/informe.txt          # hallazgo real + falsos positivos
```
:::

## Cómo actuar en una situación así

- **Herramientas de confianza primero.** Usa binarios estáticos o del paquete, nunca los del sistema comprometido.
- **La línea base se hace limpia** y se guarda en otro sitio (solo lectura, otro servidor).
- **Separa hallazgo real de ruido.** Un informe con 40 avisos sin clasificar no sirve a nadie.

## Si te atascas

- `debsums` no aparece: `sudo apt list --installed | grep debsums`; ya viene instalado.
- rkhunter sigue avisando de `ps`: hiciste `--propupd` antes de restaurar. Restaura y repite.
