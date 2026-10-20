# Lab 15 — El `ls` que no es `ls` (secuestro de PATH)

## Escenario

En `host-15`, cada vez que escribes `ls` pasa algo raro: hay un retardo mínimo y
aparecen entradas en un log que no pusiste tú. Un atacante colocó un binario
impostor **antes** del real en tu `PATH`. Como `/usr/local/bin` va antes que
`/usr/bin`, su `ls` se ejecuta primero (hace lo suyo y luego llama al real, así
no sospechas). Detecta el secuestro y elimínalo.

## Objetivos

1. **Descubre que `ls` está secuestrado**: mira *todas* las rutas donde existe el
   comando y cuál gana en tu `PATH`.
2. **Inspecciona el impostor** (es un script que registra y luego llama al `ls`
   real).
3. **Elimínalo** para que `ls` vuelva a resolver al binario legítimo.

## Comandos que te pueden servir

```bash
type -a ls            # muestra TODAS las definiciones de 'ls' por orden de PATH
which -a ls
file "$(command -v ls)"
cat /usr/local/bin/ls           # ¿un script en vez de un ELF?
echo "$PATH"                    # ¿/usr/local/bin va antes que /usr/bin?
sudo rm -f /usr/local/bin/ls
hash -r                         # limpia la caché de rutas de la shell
```

> Un comando básico (`ls`, `ps`, `cat`) que resuelve a `/usr/local/bin` o a un
> **script** en vez de a su ELF en `/usr/bin` es sospechoso. Confirma con hashes
> contra una copia buena conocida.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
