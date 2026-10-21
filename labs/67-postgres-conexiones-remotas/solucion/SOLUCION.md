# Solución — PostgreSQL rechaza las conexiones remotas

## 1. Síntoma desde app-04

```bash
/usr/local/bin/informe-diario.sh
# psql: error: connection to server at "pg-01" (10.76.67.20), port 5432 failed: Connection refused
```

`Connection refused` significa que **nadie escucha** en esa IP y ese puerto.
Todavía no es un problema de contraseñas.

## 2. listen_addresses (en pg-01)

```bash
ssh dba@pg-01
sudo ss -ltnp | grep 5432           # 127.0.0.1:5432 y [::1]:5432 únicamente
```

Si cambias `listen_addresses` en `postgresql.conf` y reinicias, **sigue
igual**. Pregunta a PostgreSQL de dónde sale el valor:

```bash
sudo -u postgres psql -c "SELECT setting, sourcefile, sourceline FROM pg_settings WHERE name='listen_addresses'"
#  localhost | /etc/postgresql/15/main/conf.d/90-hardening.conf | 2
```

`postgresql.conf` termina con `include_dir = 'conf.d'`, y gana el **último**
valor que se lee. El hardening está en `conf.d/90-hardening.conf`: corrígelo
ahí, con un comentario que explique la excepción.

```bash
sudo tee /etc/postgresql/15/main/conf.d/90-hardening.conf >/dev/null <<'EOF'
# Hardening CIS 3.1 (SEC-118): sólo loopback + red interna (excepción INC-6707: app-04).
listen_addresses = 'localhost,10.76.67.20'
EOF
sudo systemctl restart postgresql      # listen_addresses sólo cambia al reiniciar
```

Desde app-04, el error cambia. Eso es progreso:

```
FATAL:  pg_hba.conf rejects connection for host "10.76.67.10", user "informes", database "ventas", no encryption
```

## 3. pg_hba.conf: el orden importa

```bash
sudo -u postgres psql -c 'SELECT line_number, type, database, user_name, address, auth_method FROM pg_hba_file_rules'
```

PostgreSQL usa la **primera** regla que coincide. Si añades tu línea al
**final**, detrás de `host all all 0.0.0.0/0 reject`, nunca se llega a
evaluar. Ponla **encima** del `reject`:

```bash
sudo nano /etc/postgresql/15/main/pg_hba.conf
```

```
# INC-6707: informe diario desde app-04
host    ventas          informes        10.76.67.10/32          scram-sha-256

# Hardening CIS (SEC-118): ninguna conexión de red salvo las que se autoricen arriba.
host    all             all             0.0.0.0/0               reject
```

```bash
sudo -u postgres psql -c 'SELECT line_number, address, auth_method, error FROM pg_hba_file_rules'   # sin errores
sudo systemctl reload postgresql       # pg_hba.conf se relee con reload
```

## 4. Verificación desde app-04

```bash
/usr/local/bin/informe-diario.sh                                   # pedidos: 1200 · total: ...
psql "host=pg-01 dbname=ventas user=informes password=mala" -c 'select 1'      # password authentication failed
psql "host=pg-01 dbname=postgres user=informes password=Informes-2026"           # rejects connection
```

Prueba también lo que **no** debe funcionar. Ese es el contrato con seguridad.

## Lecciones

- `Connection refused` = nadie escucha (`listen_addresses`, el servicio o el
  puerto). `no pg_hba.conf entry` / `rejects connection` = escucha, pero las
  reglas no te dejan entrar. `password authentication failed` = la regla te
  deja pasar y la credencial está mal.
- `pg_settings.sourcefile` te dice qué fichero manda. `pg_hba_file_rules`
  te enseña cómo interpreta PostgreSQL el `pg_hba.conf` (y si tiene errores)
  antes de recargar.
- `reload` para `pg_hba.conf`; `restart` para `listen_addresses`.
- `trust` en una regla de red es entregar la BD a cualquiera. `md5` es
  obsoleto: usa `scram-sha-256`.
- Excepciones de seguridad mínimas: un host /32, un usuario, una BD.
