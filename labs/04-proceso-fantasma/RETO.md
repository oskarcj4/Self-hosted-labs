# Lab 04 — El servidor está al 100% pero el monitor dice 0%

Inspirado en el video de @terminalcero *"Tu servidor está al 100% pero el monitor dice 0%"*.

## Escenario

`app-prod-04` tiene la carga por las nubes y el ventilador a tope, pero el panel
de monitoreo corporativo (`sysmon`) insiste en que el consumo es **0%**. Si el
monitor miente, hay que ir a la fuente que no se puede falsificar: el **kernel**
(`/proc`). Alguien dejó un proceso que se disfraza de hilo del kernel y, de paso,
amañó el monitor para no aparecer en él.

## Objetivos

1. **Confirma que el monitor miente.** Ejecuta `sysmon` y compáralo con la
   realidad usando `ps` o `top`.
2. **Encuentra el proceso impostor.** Se hace pasar por un hilo del kernel
   (`kworker`), pero los hilos reales del kernel **no** tienen un binario en disco.
   Mira la ruta real del ejecutable en `/proc/<PID>/exe`.
3. **Mátalo y borra su binario** (está en `/tmp`).
4. **Desenmascara el monitor amañado**: `sysmon` es un script que filtra al
   impostor. Bórralo o déjalo claro en tus notas.

## Comandos que te pueden servir

```bash
sysmon                               # el monitor "oficial" (miente)
ps -eo pid,comm,%cpu --sort=-%cpu | head
pgrep -x kworker                     # el impostor usa exactamente este nombre
ls -la /proc/<PID>/exe               # ¿de dónde sale el binario?
cat /proc/<PID>/cmdline | tr '\0' ' '
file /tmp/kworker
```

> Un `kworker` legítimo se llama `kworker/0:1` (con barra y números) y su
> `/proc/PID/exe` no apunta a ningún archivo. El tuyo se llama `kworker` a secas
> y sale de `/tmp`. Bandera roja.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
