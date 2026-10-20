# Solución — Lab 15

## 1. Descubrir el secuestro

```bash
type -a ls
# ls is /usr/local/bin/ls
# ls is /usr/bin/ls
echo "$PATH"        # /usr/local/bin va antes que /usr/bin
file "$(command -v ls)"   # script de shell, no un ELF -> sospechoso
```

El `ls` que gana es `/usr/local/bin/ls` y es un **script**, no el ELF real.

## 2. Inspeccionar el impostor

```bash
cat /usr/local/bin/ls
# registra en /var/log/.ls-hijack y luego: exec /bin/ls "$@"
```

Llama al `ls` real para no levantar sospechas, pero antes ejecuta lo suyo.

## 3. Eliminarlo

```bash
sudo rm -f /usr/local/bin/ls
hash -r               # limpia la caché de rutas de la shell actual
type -a ls            # ahora resuelve a /usr/bin/ls (o /bin/ls)
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- El orden de `PATH` es superficie de ataque: un directorio escribible antes que
  `/usr/bin` permite secuestrar comandos. Nunca pongas `.` ni rutas escribibles
  por todos al principio del `PATH`.
- Verifica integridad con hashes (`sha256sum`) contra una línea base o contra el
  gestor de paquetes (`dpkg --verify`, `debsums`).
- `type -a` / `which -a` revelan comandos duplicados; un comando básico que es un
  script es bandera roja.
