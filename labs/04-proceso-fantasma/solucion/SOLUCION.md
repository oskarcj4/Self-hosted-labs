# Solución — Lab 04

## 1. El monitor miente

```bash
sysmon                     # dice CPU 0%
ps -eo pid,comm,%cpu --sort=-%cpu | head
```

`ps` muestra un proceso `kworker` consumiendo CPU que `sysmon` no reporta. El
monitor está amañado.

## 2. Identificar al impostor

```bash
PID=$(pgrep -x kworker)
ls -la /proc/$PID/exe        # -> /tmp/kworker  (¡un kworker real no tiene exe en disco!)
cat /proc/$PID/cmdline | tr '\0' ' '; echo
file /tmp/kworker
```

Un hilo del kernel legítimo se llama `kworker/0:1`, vive sólo en memoria y su
`/proc/PID/exe` no apunta a ningún archivo. Éste se llama `kworker` a secas y
sale de `/tmp`: es un proceso de usuario disfrazado.

## 3. Matarlo y borrar el binario

```bash
sudo kill -9 "$PID"
sudo rm -f /tmp/kworker
```

## 4. Desenmascarar el monitor

```bash
cat /usr/local/bin/sysmon          # verás el 'grep -v -w kworker' que lo oculta
sudo rm -f /usr/local/bin/sysmon
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- El kernel (`/proc`) no miente; las herramientas de espacio de usuario sí se
  pueden troyanizar. Compara siempre varias fuentes.
- Nombre de proceso ≠ identidad. `/proc/PID/exe`, `cmdline` y el hash del binario
  cuentan la verdad.
- Un `kworker` con binario en disco es, por definición, falso.
