# Búsqueda de secretos y cambios recientes

> Defensa del host · grep · find -mtime · cuentas

## Escenario

Antes de dar acceso al repositorio de la tienda a un proveedor externo, toca
revisar `/srv/app` en `dev-119` (`~/ticket/TAREA-119.txt`): credenciales en
claro, cambios recientes que nadie ha explicado y cuentas que sobran.

## Objetivos

1. Inventaria los secretos en claro de `/srv/app` en `~/secretos.txt`
   (fichero y línea). Busca también en ficheros ocultos.
2. Lista en `~/recientes.txt` lo que cambió en `/srv/app` en las últimas 24 h
   (sólo eso).
3. Revisa qué cuentas tienen shell interactiva. La que sobra: bloqueada y con
   `nologin` (o borrada).
4. Saca los secretos del código a `/srv/app/.env` (dueño `app`, modo 600) y
   haz que `src/payments.py` lea la clave de `os.environ`. Fuera también lo
   que se añadió hoy a `deploy.sh` y las notas con contraseña.

## Comandos que te pueden servir

```bash
grep -rnEi "password|api_key|secret|token|AKIA" /srv/app
find /srv/app -type f -mtime -1
grep -v nologin /etc/passwd
sudo usermod -L -s /usr/sbin/nologin <usuario>
sudo -u app nano /srv/app/.env ; sudo chmod 600 /srv/app/.env
```

> Un secreto que estuvo en un repositorio se considera **filtrado**: además
> de sacarlo del código, en la vida real se rota (ver lab de gitleaks).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
