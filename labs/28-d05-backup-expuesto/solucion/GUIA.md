# Resolución guiada · Día 05

:::piensa Antes de tocar nada
Todo lo que está dentro del docroot es **público**, esté enlazado o no. Y esto es un incidente, no sólo limpieza: el log sugiere que alguien ya lo descargó. Actúa en orden: **inventario → identificar → preservar evidencia → retirar → verificar → evaluar el impacto**.
:::

## Paso 1 · Inventario del docroot

**Pregúntate:** ¿qué ficheros hay y cuáles no parecen parte de una web?

:::pista Cómo comprobarlo
```bash
sudo find /var/www/shop -type f | sort
sudo find /var/www/shop -type f \( -name '*.tar*' -o -name '*.tgz' -o -name '*.zip' -o -name '*.sql*' -o -name '*.bak' \) -ls
```
Fíjate también en carpetas ocultas (empiezan por `.`).
:::

## Paso 2 · ¿Cuál es legítimo y cuál no?

**Pregúntate:** un `.zip` no es malo por ser `.zip`. ¿Cómo distingo un fichero de la web de un backup? Por su **contenido** y por si la web lo **enlaza**.

:::pista Cómo comprobarlo
```bash
tar -tzf <archivo>                      # ¿qué contiene?
grep -n href /var/www/shop/index.html   # ¿qué enlaza la web?
sha256sum <candidato1> <candidato2>     # ¿son el mismo fichero con otro nombre?
```
Si dos ficheros tienen el mismo hash, son copias: hay que retirar **las dos**.
:::

## Paso 3 · ¿Lo descargó alguien?

**Pregúntate:** ¿qué dice el log de acceso? Esto decide si basta con retirarlo o si hay que **rotar credenciales**.

```bash
sudo grep -E 'tar.gz|tgz' /var/log/nginx/access.log
```

## Paso 4 · Preserva y retira

**Pregúntate:** ¿por qué no borrar directamente? Porque el fichero es **evidencia** (qué se filtró exactamente). Muévelo fuera del docroot, con permisos cerrados.

:::pista Cómo hacerlo
```bash
sudo install -d -m 700 /root/evidencia
sudo mv <backup1> <backup2> /root/evidencia/
sudo chmod 600 /root/evidencia/*
```
:::

## Paso 5 · Verifica

```bash
IP=$(hostname -I | awk '{print $1}')
for u in / /downloads/press-kit.zip <rutas-de-los-backups>; do
  printf '%-36s %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code}' http://$IP$u)"
done
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Busca por extensión y por hash**: las copias se renombran y se esconden.
- **No rompas lo legítimo**: comprueba qué enlaza la web antes de borrar.
- **Evalúa el impacto**: si se descargó, las credenciales del volcado están comprometidas. Rótalas y avisa.
- Prevención: los backups se escriben **fuera** del docroot.

## Si te atascas

- El validador dice que queda un backup: busca carpetas ocultas con `find /var/www/shop -name '.*'`.
