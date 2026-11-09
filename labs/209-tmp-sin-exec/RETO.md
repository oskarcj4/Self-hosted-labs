# /tmp, /var/tmp y /dev/shm sin ejecución

> Hardening · noexec · nosuid · nodev · tmpfs · bind mount · evidencia

## Escenario

Un pentest en `tmp-209` demostró que puede dejar y ejecutar código desde
`/tmp`, `/var/tmp` y `/dev/shm`: son escribibles por todos, así que casi todo
malware empieza ahí. La práctica CIS es montarlos con `nosuid,nodev,noexec`.

Cuidado con el **orden**: al montar un `tmpfs` sobre `/tmp`, lo que había
debajo desaparece de la vista. Hay tres ficheros sospechosos (ocultos) y
hay que **conservarlos** antes de tocar nada.

## Objetivos

1. Copia los tres ficheros sospechosos a `~/evidencia/` (sin alterarlos).
2. `/tmp` como `tmpfs` con `nosuid,nodev,noexec,size=256m,mode=1777`.
3. `/dev/shm` con `nosuid,nodev,noexec`.
4. `/var/tmp` como *bind mount* de `/tmp` con `nosuid,nodev,noexec`.
5. Todo en `/etc/fstab` y aplicado ya, sin reiniciar.

## Comandos que te pueden servir

```bash
sudo find /tmp /var/tmp /dev/shm -type f -ls          # busca ocultos: ls -la
findmnt /tmp /var/tmp /dev/shm
sudo mount /tmp                                        # monta lo que dice fstab
sudo mount -o remount,nosuid,nodev,noexec /dev/shm
cp /bin/true /tmp/t && /tmp/t                          # debe dar Permission denied
```

> Algunos instaladores y herramientas (`apt` con scripts, compiladores, Node)
> ejecutan desde `/tmp`: con noexec fallan. Se resuelve con `TMPDIR` propio o
> `APT::ExtractTemplates::TempDir`, no quitando el noexec.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
