# Solución — Restaurar un backup y reconectar la app

## 1. Confirma el daño

```bash
curl -s http://127.0.0.1:8080/health | jq
# {"status":"error","detalle":"... database \"tienda_dr\" does not exist ..."}
sudo -u postgres psql -l | grep tienda     # no aparece: la base no existe
```

Dos problemas encadenados: la base **no existe** y la app apunta a un
`tienda_dr` inventado durante el incidente.

## 2. Elige el backup bueno

```bash
ls -l /var/backups/tienda/
# tienda-2026-10-18.dump  ~  (bueno)
# tienda-2026-10-19.dump  0 bytes  (el de hoy falló)
cat /var/backups/tienda/pg-backup.log      # confirma: el 19 dio error
sudo -u postgres pg_restore -l /var/backups/tienda/tienda-2026-10-18.dump | head
```

`pg_restore -l` lista el índice del dump. Si el fichero está vacío o truncado,
falla aquí: un backup que no puedes listar no es un backup.

## 3. Restaura

```bash
sudo -u postgres createdb -O tienda tienda
sudo -u postgres pg_restore -d tienda /var/backups/tienda/tienda-2026-10-18.dump
sudo -u postgres psql -d tienda -c 'SELECT count(*) FROM productos'   # 240
```

El ROLE `tienda` sobrevivió al incidente (solo se borró la base), así que el
`OWNER` del dump existe y el restore no se queja.

## 4. Reconecta la app

```bash
cat /etc/tienda/db.conf
# host=127.0.0.1 port=5433 dbname=tienda_dr ...   <- mal
cat > /etc/tienda/db.conf <<'EOF'
host=127.0.0.1 port=5432 dbname=tienda user=tienda password=tienda
EOF
sudo systemctl restart tienda-web
curl -s http://127.0.0.1:8080/health | jq        # {"status":"ok","productos":240}
```

Restaurar la base no basta: la app seguía apuntando al failover inventado, y
además mantenía conexiones muertas. Corrige el DSN y **reinicia** el servicio
para que abra conexiones nuevas.

## 5. Para el postmortem

- **RPO**: se perdió lo ocurrido entre el backup del 18 (02:00) y el borrado.
  Con un dump diario, ese es el máximo que puedes perder. Para menos, archivado
  de WAL / point-in-time recovery.
- **El backup de hoy falló y nadie se enteró**: alerta si el job sale con error
  o si el fichero pesa mucho menos que el anterior.
- **Ensaya la restauración**: un backup no vale hasta que lo has restaurado.
- **Protege producción**: permisos para que un borrado de base no sea trivial,
  y nada de "apuntar a un failover" a mano en caliente sin que exista.

## Lecciones

- `Connection refused`/`database ... does not exist` = la app no encuentra la
  base; primero restaura, luego reconecta.
- `pg_restore -l` valida el dump antes de usarlo; mira también tamaño y log.
- Restaurar y reconectar son **dos** pasos: base + configuración + reinicio.
- El ROLE y la base son cosas distintas: puedes perder una y conservar el otro.
