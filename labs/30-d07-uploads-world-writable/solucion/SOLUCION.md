# Solución — Día 07: Corregir un directorio web escribible por todos

## 1. Diagnóstico

```bash
sudo find /var/www/media/uploads -perm -0002 -ls
# drwxrwxrwx root root  uploads, avatars, docs
# -rw-rw-rw- root root  ficheros
systemctl show media-app -p User   # User=www-data
```

El problema de origen era que la carpeta pertenecía a `root`; el `777` lo
"arregló" dando escritura **a todo el mundo** en vez de al único que la necesita.

## 2. Dar la escritura sólo a quien escribe

```bash
U=/var/www/media/uploads
sudo chown -R www-data:www-data "$U"
sudo find "$U" -type d -exec chmod 0755 {} +
sudo find "$U" -type f -exec chmod 0644 {} +
```

- Carpetas `0755`: www-data crea ficheros; el resto sólo lee/atraviesa (nginx puede servirlas).
- Ficheros `0644`: www-data los reescribe; nadie más.
- Si nada más que la app debe leerlos, aún mejor `0750/0640`.

## 3. Verificar

```bash
sudo find "$U" -perm -0002 | wc -l                       # 0
sudo -u nobody touch "$U/avatars/x" || echo "nobody bloqueado"
curl -X POST --data-binary hola 'http://127.0.0.1:8300/upload?name=t.txt&dir=docs'
ls -l "$U/docs/t.txt"                                    # www-data www-data
```

## Lecciones

- `chmod 777` nunca es la solución a "Permission denied": la solución es el
  **dueño correcto** con el permiso mínimo.
- Revisa recursivamente: subcarpetas y ficheros heredan el desastre.
- Para carpetas compartidas de verdad existe el *sticky bit* (`1777` como
  `/tmp`), pero un directorio de una app no lo es.
- Defensa extra: que el servidor web no ejecute nada de `uploads/`
  (sin PHP/CGI ahí, `noexec` si es un montaje aparte).
