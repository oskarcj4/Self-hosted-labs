# Lab 10 — La puerta trasera SUID

## Escenario

En `host-10`, un atacante que ya tuvo root se dejó una vía rápida para volver a
ser root sin contraseña: un **binario con bit SUID** escondido con nombre de
archivo de sistema. Un ejecutable SUID-root corre con privilegios de root sin
importar quién lo lance; una copia de `bash` con SUID es una escalada de
privilegios instantánea.

## Objetivos

1. **Lista todos los binarios SUID** del sistema y detecta el impostor (una copia
   de `bash` con nombre camuflado, fuera de las rutas normales).
2. **Neutralízalo**: bórralo o quítale el bit SUID.
3. **No toques los SUID legítimos** (`sudo`, `su`, `passwd`, `mount`…): son
   normales y necesarios.

## Comandos que te pueden servir

```bash
find / -perm -4000 -type f 2>/dev/null        # todos los SUID
ls -la /usr/bin/.dbus-cache                    # ¿-rwsr-xr-x? la 's' es SUID
file /usr/bin/.dbus-cache                      # ¿es una copia de bash?
sudo rm -f /usr/bin/.dbus-cache                # bórralo…
# …o quítale sólo el bit SUID:
sudo chmod u-s /usr/bin/.dbus-cache
```

> Un SUID-root que sea una shell (`bash`, `dash`, `sh`) es casi siempre una
> puerta trasera. Los SUID legítimos son pocos y conocidos.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
