# Día 05 — Retirar un backup expuesto

> 30 días de DevSecOps · Linux · Exposición e higiene web

## Escenario

Antes de una migración, alguien hizo un backup completo de la tienda **dentro
del propio web root** (`/var/www/shop`). El archivo incluye un volcado de la
base de datos con credenciales. El log de nginx sugiere que alguien de fuera
ya lo encontró.

## Objetivos

1. Ningún backup debe poder descargarse desde la web.
2. No debe quedar **ningún backup dentro de `/var/www/shop`**, tampoco
   copias escondidas o renombradas.
3. La web debe seguir intacta: portada, CSS, logo y el **kit de prensa**
   (`/downloads/press-kit.zip`, que sí es un `.zip` legítimo y enlazado).
4. nginx válido y activo.

> No basta con "bloquear la URL" en nginx: el archivo seguiría en el docroot y
> cualquier cambio de configuración lo volvería a exponer.

## Comandos que te pueden servir

```bash
sudo find /var/www/shop -type f | sort
sudo find /var/www/shop -type f \( -name '*.tar*' -o -name '*.tgz' -o -name '*.zip' -o -name '*.sql*' -o -name '*.bak' \) -ls
sudo grep -h 'tar.gz\|tgz\|zip' /var/log/nginx/access.log
tar -tzf <archivo>          # mira qué contiene antes de decidir
sha256sum <a> <b>           # ¿son el mismo archivo con otro nombre?
```

En un incidente real, **conserva una copia fuera del web root** (por ejemplo
`/root/evidencia/`, modo `600`) antes de borrar, rota las credenciales que
contiene y avisa del acceso de `185.220.101.7`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
