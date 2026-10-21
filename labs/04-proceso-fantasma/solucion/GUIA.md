# Resolución guiada · Lab 04

:::piensa Antes de tocar nada
Si el síntoma (carga al 100 %) y la herramienta (monitor al 0 %) se contradicen, una de las dos miente. El hardware no se inventa el calor. Desconfía de la herramienta y ve a una fuente que el atacante no controle tan fácilmente: el kernel, a través de `/proc`.
:::

## Paso 1 · Demuestra que el monitor miente

**Pregúntate:** ¿con qué otra herramienta puedo ver el consumo de CPU por proceso?

**Por qué importa:** antes de actuar quieres **evidencia** de la discrepancia, no una sensación.

:::pista Cómo comprobarlo
```bash
sysmon
ps -eo pid,comm,%cpu --sort=-%cpu | head
```
¿Qué proceso aparece arriba en `ps` y no aparece en `sysmon`?
:::

## Paso 2 · ¿Es un hilo del kernel de verdad?

**Pregúntate:** ¿qué diferencia a un hilo del kernel de un programa normal? Un hilo del kernel **no tiene ejecutable en disco**: vive dentro del kernel.

**Por qué importa:** el nombre se puede copiar; la ruta del ejecutable no se puede ocultar a `/proc`.

:::pista Cómo comprobarlo
```bash
pgrep -x kworker
ls -la /proc/<PID>/exe
cat /proc/<PID>/cmdline | tr '\0' ' '; echo
file <ruta-que-te-dio-exe>
```
Compara con un kworker real: `ps -eo pid,comm | grep 'kworker/'`. Los reales llevan barra y números, y su `exe` no apunta a nada.
:::

## Paso 3 · Neutraliza

**Pregúntate:** ¿hay algo que lo relance? (Revisa rápido cron y timers, como en el lab 02.) Si no, mata y borra.

:::pista Cómo hacerlo
```bash
sudo kill -9 <PID>
sudo rm -f /tmp/kworker
```
:::

## Paso 4 · ¿Por qué el monitor no lo veía?

**Pregúntate:** si `sysmon` es un script, ¿puedo leerlo? ¿Qué filtra?

**Por qué importa:** una herramienta troyanizada sigue mintiendo después de limpiar. Si no la corriges, el próximo incidente tampoco lo verás.

:::pista Cómo comprobarlo
```bash
command -v sysmon
cat "$(command -v sysmon)"
```
Busca un `grep -v`. Cuando entiendas qué ocultaba, bórralo:
```bash
sudo rm -f "$(command -v sysmon)"
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Contrasta fuentes.** Si dos herramientas discrepan, ve a la más cercana al kernel (`/proc`, `ss`, `ps` de un binario verificado).
- **Identidad = ruta + hash + padre**, no el nombre.
- **Las herramientas también se comprometen.** Tras un incidente, verifica la integridad de los binarios (`dpkg --verify`, hashes).

## Si te atascas

- `pgrep -x kworker` no devuelve nada: prueba `ps -eo pid,comm,%cpu --sort=-%cpu | head` y fíjate en el que no lleva `/`.
- No sabes dónde está `sysmon`: `command -v sysmon`.
