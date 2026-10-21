# Resolución guiada · Lab 10

:::piensa Antes de tocar nada
El bit SUID hace que un programa se ejecute con los privilegios de **su dueño**, no de quien lo lanza. Para `passwd` tiene sentido (necesita escribir `/etc/shadow`). Para una copia de `bash` es un regalo: root para cualquiera. Tu trabajo es separar los SUID que el sistema necesita del que alguien añadió.
:::

## Paso 1 · Haz inventario

**Pregúntate:** ¿cómo encuentro todos los ficheros con SUID? `find` puede filtrar por permisos.

**Por qué importa:** no puedes detectar lo raro sin ver la lista completa.

:::pista Cómo comprobarlo
```bash
find / -perm -4000 -type f 2>/dev/null
```
`-perm -4000` = "tiene el bit SUID". `2>/dev/null` oculta los errores de carpetas que no puedes leer.
:::

## Paso 2 · ¿Cuál no encaja?

**Pregúntate:** de esa lista, ¿cuáles reconozco? (`sudo`, `su`, `passwd`, `mount`, `umount`, `chsh`, `newgrp`…). ¿Hay alguno con un nombre raro, oculto (empieza por `.`) o en una ruta inesperada?

**Por qué importa:** el atacante lo camufla; un punto inicial lo oculta de un `ls` normal.

:::pista Cómo comprobarlo
```bash
ls -la <sospechoso>
file <sospechoso>
sha256sum <sospechoso> /bin/bash
```
Si el hash coincide con `bash`, es una shell con SUID: puerta trasera confirmada.
:::

## Paso 3 · Neutraliza

**Pregúntate:** ¿lo borro o le quito el bit? Ambas cosas lo desactivan. Borrarlo es más limpio; quitar el bit te deja el fichero para analizarlo.

:::pista Cómo hacerlo
```bash
sudo rm -f <sospechoso>
# o, para conservarlo:  sudo chmod u-s <sospechoso>
bash /opt/lab/check.sh
```
:::

:::ojo No toques los legítimos
Quitar el SUID a `sudo` o `passwd` rompe el sistema (y te deja sin sudo).
:::

## Cómo actuar en una situación así

- **Guarda una línea base** de SUID (`find ... > suid-base.txt`) y compárala periódicamente.
- **Banderas rojas**: shells con SUID, SUID en `/tmp`, `/dev/shm` o `/home`, nombres ocultos, binarios que no pertenecen a ningún paquete (`dpkg -S <ruta>`).
- Que exista esto significa que el atacante **ya tuvo root**: busca más persistencia.

## Si te atascas

- La lista es larga: filtra lo que no esté en `/usr/bin` o `/usr/sbin`, o busca nombres que empiecen por punto: `find / -perm -4000 -name '.*' 2>/dev/null`.
