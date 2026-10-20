# Día 07 — Corregir un directorio web escribible por todos

> 30 días de DevSecOps · Linux · Permisos e identidad de servicios

## Escenario

`media-app` (corre como `www-data`) guarda las subidas de los usuarios en
`/var/www/media/uploads`. Cuando la app dio "Permission denied", alguien lo
arregló con un `chmod -R 777`. Ahora **cualquier usuario o proceso** del
servidor puede dejar ficheros ahí (o sustituir los de otros): el primer paso
típico para colar una webshell.

## Objetivos

1. Nada dentro de `uploads/` (carpetas ni ficheros) debe ser escribible por "otros".
2. Un usuario ajeno (p.ej. `nobody`) no debe poder crear ficheros en
   `uploads/`, `uploads/avatars/` ni `uploads/docs/`.
3. `media-app` debe seguir pudiendo guardar subidas en las tres carpetas:
   ```bash
   curl -X POST --data-binary @/etc/hostname 'http://127.0.0.1:8300/upload?name=t.txt&dir=avatars'
   ```
4. No borres los ficheros que ya subieron los usuarios.
5. `media-app` sigue corriendo como `www-data` (darle root no es la solución).

## Comandos que te pueden servir

```bash
sudo find /var/www/media/uploads -perm -0002 -ls     # world-writable
ls -la /var/www/media/uploads /var/www/media/uploads/*
systemctl show media-app -p User -p Group
sudo chown -R <usuario>:<grupo> <ruta>
sudo find <ruta> -type d -exec chmod <modo> {} +     # carpetas
sudo find <ruta> -type f -exec chmod <modo> {} +     # ficheros
sudo -u nobody touch /var/www/media/uploads/prueba   # ¿puede un extraño?
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
