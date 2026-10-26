# Resolución guiada · El servicio que muere sin rastro (OOM killer)

:::piensa Antes de tocar nada
"Está active" y "no hay error en el log" a la vez huele a muerte por `SIGKILL`:
nadie puede capturar la señal 9 ni escribir un error al morir. Si un proceso
desaparece sin traza, lo mató **algo de fuera** (OOM, timeout de systemd, un
`kill -9`). Aquí: OOM dentro del cgroup. Arregla la **causa**, no subas el
límite.
:::

## Paso 1 · "active" miente: mira el PID y los reinicios

**Pregúntate:** ¿lleva horas vivo o "2 segundos" otra vez?

:::pista Cómo comprobarlo
```bash
systemctl status report-gen                 # Active: running ... 2s ago (siempre)
systemctl show report-gen -p NRestarts      # sube cada pocos segundos
```
`active` es una foto. `Restart=on-failure` esconde un bucle de reinicios.
:::

## Paso 2 · La evidencia (y guárdala)

**Pregúntate:** si el proceso no deja error, ¿quién sí? systemd y el kernel.

:::pista Cómo encontrarla
```bash
sudo journalctl -u report-gen --no-pager | tail
# ... killed by the OOM killer. ... code=killed, status=9/KILL ... result 'oom-kill'.
sudo journalctl -k | grep -i -E 'oom|killed'    # la línea del kernel (dmesg)
sudo journalctl -u report-gen | grep -m1 'OOM killer' > ~/incidente/causa.txt
```
:::

## Paso 3 · La causa

**Pregúntate:** ¿cuánta memoria le dejamos y cuánta pide?

```bash
systemctl show report-gen -p MemoryMax     # 67108864 = 64 MB
cat /etc/report-gen.conf                   # BATCH_SIZE=500000  (~100 MB)
```

500000 registros × ~200 B ≈ 100 MB > `MemoryMax=64M` → el kernel mata el
proceso dentro de su cgroup. El propio fichero avisa: valor probado = 100000.

## Paso 4 · Arregla la causa, no el síntoma

**Pregúntate:** ¿bajo el consumo o subo el límite? Baja el consumo (host
compartido, presupuesto 256 MB).

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^BATCH_SIZE=.*/BATCH_SIZE=100000/' /etc/report-gen.conf
sudo systemctl restart report-gen
watch -n1 systemctl show report-gen -p NRestarts,MemoryCurrent   # NRestarts deja de subir
```
Si el lote grande hiciera falta de verdad, sube `MemoryMax` con `systemctl edit
report-gen` **dentro** del presupuesto. Lo que **nunca**: `MemoryMax=infinity`
— el próximo pico se llevaría por delante a los vecinos o al OOM global.
:::

## Paso 5 · Verifica

```bash
cat ~/incidente/causa.txt
systemctl show report-gen -p NRestarts,Result,MemoryCurrent
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Muerte sin error = señal externa.** Piensa OOM, timeout de systemd, `kill -9`.
- **`NRestarts` + "hace 2s" en `status` + `Result=oom-kill`** delatan el bucle.
- **`MemoryMax` (systemd) / `mem_limit` (Docker)** es un cortafuegos que protege
  a los vecinos: arregla el consumo antes que el límite.

## Si te atascas

- No encuentras la causa en el log del servicio → no está ahí; mira
  `journalctl -u` (systemd) y `journalctl -k` (kernel).
- Sigue reiniciando tras bajar `BATCH_SIZE` → ¿reiniciaste el servicio?
  ¿`MemoryCurrent` sigue cerca de `MemoryMax`?
