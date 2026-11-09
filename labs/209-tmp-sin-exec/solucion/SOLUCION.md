# Solución — temporales sin ejecución

## Qué pasaba

Los tres directorios temporales eran del rootfs/shm con `exec,suid,dev`; el atacante
dejó ficheros ocultos en cada uno.

## Arreglo

```bash
mkdir -p ~/evidencia
cp -p /tmp/.font-unix/.kworker /dev/shm/.run /var/tmp/.cache-x ~/evidencia/
sudo tee -a /etc/fstab <<'F'
tmpfs  /tmp      tmpfs  defaults,nosuid,nodev,noexec,size=256m,mode=1777  0 0
tmpfs  /dev/shm  tmpfs  defaults,nosuid,nodev,noexec,size=128m            0 0
/tmp   /var/tmp  none   bind,nosuid,nodev,noexec                          0 0
F
sudo mount /tmp; sudo mount -o remount,nosuid,nodev,noexec /dev/shm; sudo mount /var/tmp
bash /opt/lab/check.sh
```

## Más allá del lab

- CIS Benchmark 1.1.2.x: opciones por directorio. `auditd` sobre ejecuciones en temporales.
- Contenedores: `--tmpfs /tmp:rw,noexec,nosuid` y `read_only: true`.
