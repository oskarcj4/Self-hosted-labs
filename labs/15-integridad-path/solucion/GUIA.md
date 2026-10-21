# Resolución guiada · Lab 15

:::piensa Antes de tocar nada
Cuando escribes `ls`, la shell no "sabe" qué es `ls`: recorre las carpetas del `PATH` en orden y ejecuta **el primero que encuentra**. Si alguien pone un `ls` en una carpeta que va antes que `/usr/bin`, gana el suyo. Tu pregunta guía: **¿qué se está ejecutando de verdad cuando escribo este comando?**
:::

## Paso 1 · ¿Cuántos `ls` hay?

**Pregúntate:** ¿cómo veo todas las definiciones de un comando, no sólo la que gana?

:::pista Cómo comprobarlo
```bash
type -a ls
echo "$PATH"
```
`type -a` lista todas en orden de prioridad. Si hay más de un `ls` en el disco, algo pasa.
:::

## Paso 2 · ¿Qué es el que gana?

**Pregúntate:** un `ls` real es un binario compilado (ELF). ¿Qué tipo de fichero es el que gana?

**Por qué importa:** un comando básico que resulta ser un script es una bandera roja enorme.

:::pista Cómo comprobarlo
```bash
file "$(command -v ls)"
cat "$(command -v ls)"
```
Lee el script: hace algo "extra" y luego llama al `ls` real para que no notes nada.
:::

## Paso 3 · Retíralo y limpia la caché

**Pregúntate:** si lo borro, ¿la shell actual se entera? Bash recuerda dónde encontró cada comando (`hash`).

:::pista Cómo hacerlo
```bash
sudo rm -f /usr/local/bin/ls
hash -r
type -a ls
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Revisa los otros comandos básicos**: si alguien secuestró `ls`, quizá también `ps`, `ss`, `sudo`… `ls -la /usr/local/bin` te da la lista.
- **Verifica integridad** contra el gestor de paquetes: `dpkg -S <ruta>` (¿pertenece a un paquete?) y `dpkg --verify`.
- **Mira qué registraba el impostor**: puede haber recogido información que ahora tiene el atacante.
- Prevención: ninguna carpeta escribible por usuarios normales antes de `/usr/bin` en el `PATH`, y nunca `.` en el `PATH`.

## Si te atascas

- `type -a` sólo muestra uno: puede ser un alias o una función; prueba `type ls` y `alias`.
