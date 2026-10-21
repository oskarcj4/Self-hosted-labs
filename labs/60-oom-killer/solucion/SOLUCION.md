# Solución — OOM killer

## 1. "Está active"... pero mira el PID

```bash
systemctl status report-gen
#  Active: active (running) since ...; 2s ago      <- siempre "hace 2 segundos"
systemctl show report-gen -p NRestarts             # sube cada pocos segundos
```

`active` es una foto del instante. El servicio está en un bucle de reinicios
que esconde `Restart=on-failure`.

## 2. La evidencia

```bash
sudo journalctl -u report-gen --no-pager | tail
# report-gen.service: A process of this unit has been killed by the OOM killer.
# report-gen.service: Main process exited, code=killed, status=9/KILL
# report-gen.service: Failed with result 'oom-kill'.
sudo journalctl -u report-gen | grep -m1 'OOM killer' > ~/incidente/causa.txt
```

El proceso no puede dejar nada en su log: `SIGKILL` no se puede capturar y
no da tiempo a escribir nada. El mensaje lo deja **systemd**, y el kernel lo
deja en `dmesg` / `journalctl -k` (`Memory cgroup out of memory: Killed
process ...`).

## 3. La causa

```bash
systemctl show report-gen -p MemoryMax     # 67108864 (64 MB)
cat /etc/report-gen.conf                   # BATCH_SIZE=500000  (~100 MB)
```

Con 500000 registros × 200 bytes ≈ 100 MB, el servicio supera su
`MemoryMax=64M` y el kernel mata el proceso dentro de su cgroup. El comentario
del fichero lo dice: el valor probado es 100000.

## 4. Arreglo: la causa, no el síntoma

```bash
sudo sed -i 's/^BATCH_SIZE=.*/BATCH_SIZE=100000/' /etc/report-gen.conf
sudo systemctl restart report-gen
watch -n1 systemctl show report-gen -p NRestarts,MemoryCurrent
```

¿Y subir `MemoryMax`? Puedes hacerlo con un drop-in (`systemctl edit
report-gen`) si el lote grande hace falta de verdad, siempre dentro del
presupuesto del host. Lo que **no** debes hacer es quitar el límite
(`MemoryMax=infinity`): el próximo fallo se llevaría por delante a los demás
servicios de la máquina, o despertaría al OOM killer global, que mata lo que
le parece.

## Lecciones

- Si un proceso muere sin error, piensa en un `SIGKILL` desde fuera: OOM,
  timeout de systemd, `kill -9` de alguien.
- `NRestarts`, el tiempo desde el arranque en `status` y `Result=oom-kill`
  delatan un bucle de reinicios.
- `MemoryMax` en systemd (o `mem_limit` en Docker) es un cortafuegos de
  memoria: protege a los vecinos. Arregla el consumo antes que el límite.
