# Solución — Día 11: Quitar credenciales hardcodeadas

## 1. Encontrar el secreto y sus copias

```bash
grep -n PASSWORD /opt/maint/db-maintenance.sh
ls -la /opt/maint/      # db-maintenance.sh (0755) y db-maintenance.sh.orig (0644)
sudo grep -rlF 'Vk7#pR2' /opt /etc /home /var/log 2>/dev/null
```

## 2. Fichero de credenciales, creado ya cerrado

```bash
sudo install -d -m 0700 -o root -g root /etc/maint
sudo install -m 0600 -o root -g root /dev/null /etc/maint/db.cred
sudo tee /etc/maint/db.cred >/dev/null <<'EOF'
DB_USER=maint
DB_PASSWORD='Vk7#pR2-maint-2026'
EOF
```

(`install -m 0600 /dev/null` crea el fichero vacío con los permisos correctos
**antes** de escribir el secreto.)

## 3. El script lo carga en lugar de llevarlo dentro

```bash
sudo sed -i -e '/^DB_USER=/d' -e "/^DB_PASSWORD=/c\\
# Credenciales fuera del código (root, 0600)\\
. /etc/maint/db.cred || { echo 'ERROR: no puedo leer /etc/maint/db.cred'; exit 1; }" \
  /opt/maint/db-maintenance.sh
sudo chown root:root /opt/maint/db-maintenance.sh
sudo chmod 0755 /opt/maint/db-maintenance.sh
```

Resultado (cabecera del script):

```bash
DB_HOST=127.0.0.1
DB_PORT=5433
# Credenciales fuera del código (root, 0600)
. /etc/maint/db.cred || { echo 'ERROR: no puedo leer /etc/maint/db.cred'; exit 1; }
```

## 4. Eliminar la copia y verificar

```bash
sudo rm /opt/maint/db-maintenance.sh.orig
sudo /opt/maint/db-maintenance.sh            # ... VACUUM OK
grep -c Vk7 /opt/maint/db-maintenance.sh     # 0
cat /etc/maint/db.cred                       # Permission denied (como analista)
```

## Lecciones

- El código se lee, se copia, se versiona y se pega en tickets: el secreto
  no puede vivir ahí.
- Fichero aparte = permisos propios (`0600 root`) y rotación sin tocar el código.
- Busca **copias** (`.orig`, `.bak`, repos git, logs con `set -x`).
- Si la contraseña estuvo expuesta: **rotarla** en la BD, no sólo moverla.
