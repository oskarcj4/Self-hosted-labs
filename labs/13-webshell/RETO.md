# Lab 13 — La webshell escondida entre los archivos del sitio

## Escenario

Subieron algo raro a `cms-13`. El sitio (`/var/www/html`) tiene decenas de
archivos legítimos y, entre ellos, una **webshell**: un pequeño archivo que
ejecuta comandos del sistema a partir de parámetros HTTP. Es la forma #1 de
mantener acceso tras comprometer una web. Tienes que encontrarla y borrarla sin
romper el sitio.

## Objetivos

1. **Encuentra la webshell.** Busca patrones típicos (`system(`, `shell_exec(`,
   `passthru(`, `eval(base64_decode(`) y archivos con fecha de modificación
   fuera de lo normal o en carpetas de subidas.
2. **Bórrala.**
3. **No borres los archivos legítimos** del sitio (`index.html`, etc.).

## Comandos que te pueden servir

```bash
grep -rnEl 'system\(|shell_exec\(|passthru\(|eval\(base64_decode' /var/www 2>/dev/null
find /var/www -name '*.php' -newermt '2020-01-01' -printf '%Tc  %p\n' 2>/dev/null | sort
ls -laR /var/www/html/uploads     # las webshells aman las carpetas de subida
sudo rm -f /var/www/html/ruta/a/la/webshell.php
```

> Una carpeta `uploads/` nunca debería contener código ejecutable. Un `.php` con
> un punto inicial (oculto) en subidas es casi seguro una webshell.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
