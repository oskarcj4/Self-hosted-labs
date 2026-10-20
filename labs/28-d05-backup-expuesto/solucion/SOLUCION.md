# Solución — Día 05: Retirar un backup expuesto

## 1. Inventario del docroot

```bash
sudo find /var/www/shop -type f -ls
```

Candidatos:

- `/var/www/shop/backup-2026-10-01.tar.gz` → backup evidente.
- `/var/www/shop/assets/.cache/site-old.tgz` → escondido en una carpeta oculta.
- `/var/www/shop/downloads/press-kit.zip` → **legítimo**, enlazado desde `index.html`.

```bash
tar -tzf /var/www/shop/backup-2026-10-01.tar.gz      # site/db/shop.sql ...
sha256sum /var/www/shop/backup-2026-10-01.tar.gz /var/www/shop/assets/.cache/site-old.tgz   # idénticos
grep -n href /var/www/shop/index.html                # press-kit.zip está enlazado
```

## 2. Preservar evidencia y retirar

```bash
sudo install -d -m 700 /root/evidencia
sudo mv /var/www/shop/backup-2026-10-01.tar.gz /var/www/shop/assets/.cache/site-old.tgz /root/evidencia/
sudo chmod 600 /root/evidencia/*
sudo rmdir /var/www/shop/assets/.cache 2>/dev/null || true
```

## 3. Verificar

```bash
IP=$(hostname -I | awk '{print $1}')
for u in /backup-2026-10-01.tar.gz /assets/.cache/site-old.tgz /downloads/press-kit.zip /; do
  printf '%-32s %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code}' http://$IP$u)"
done
# 404, 404, 200, 200
```

## 4. Lo que un incidente real exige además

- El log muestra que `185.220.101.7` **descargó ambos archivos**: las credenciales
  `shop_app` del volcado están comprometidas → rotarlas ya.
- Revisar qué más hay en el volcado (hashes de usuarios → forzar reseteo).
- Prevención: los backups se escriben **fuera** del docroot (`/var/backups`) y,
  como defensa extra, nginx puede negar extensiones peligrosas:
  `location ~* \.(sql|bak|tar|tgz|gz)$ { deny all; }`.

## Lecciones

- Lo que está en el docroot es público, aunque nadie lo enlace.
- Busca por extensión **y** por contenido/hash: las copias se renombran.
- No rompas lo legítimo: un `.zip` no es sospechoso por ser `.zip`.
