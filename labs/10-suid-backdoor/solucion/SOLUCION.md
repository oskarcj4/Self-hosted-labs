# Solución — Lab 10

## 1. Listar los SUID

```bash
find / -perm -4000 -type f 2>/dev/null
```

Entre los legítimos (`/usr/bin/sudo`, `/usr/bin/su`, `/usr/bin/passwd`, `mount`,
`umount`…) aparece `/usr/bin/.dbus-cache`. El punto inicial lo oculta en un `ls`
normal y el nombre imita algo de sistema.

```bash
file /usr/bin/.dbus-cache     # ELF ... (copia de bash)
ls -la /usr/bin/.dbus-cache   # -rwsr-xr-x  -> la 's' es el bit SUID
```

Un SUID-root que es una shell = escalada de privilegios para cualquiera:
`/usr/bin/.dbus-cache -p` daría una shell con EUID 0.

## 2. Neutralizarlo

```bash
sudo rm -f /usr/bin/.dbus-cache       # recomendado: borrarlo
# alternativa si quieres conservarlo para análisis:
# sudo chmod u-s /usr/bin/.dbus-cache
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- Audita SUID periódicamente: `find / -perm -4000 -type f`. Guarda una línea base
  y alerta de cualquier cambio.
- Shells SUID (`bash -p`), copias de `find`/`vim`/`nmap` con SUID, binarios SUID
  en `/tmp` o `/dev/shm`: señales claras de backdoor.
- Principio de mínimo privilegio: cuantos menos SUID, menor superficie.
