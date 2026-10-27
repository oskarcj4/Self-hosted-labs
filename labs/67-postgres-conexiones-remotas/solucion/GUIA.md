# Resolución guiada · PostgreSQL rechaza las conexiones remotas

:::piensa Antes de tocar nada
El mensaje de error te dice **en qué capa** estás: `Connection refused` = nadie
escucha; `rejects connection` / `no pg_hba.conf entry` = escucha pero las reglas
no te dejan; `password authentication failed` = la regla te deja y la credencial
está mal. Dos piezas que arreglar: `listen_addresses` (dónde escucha) y
`pg_hba.conf` (quién entra). Y el hardening metió la config en `conf.d/`, no en
`postgresql.conf`.
:::

## Paso 1 · Síntoma desde app-04

```bash
/usr/local/bin/informe-diario.sh
# ... port 5432 failed: Connection refused
```

`Connection refused` = nadie escucha en esa IP:puerto. Aún no es de contraseñas.

## Paso 2 · listen_addresses, y de qué fichero sale

**Pregúntate:** cambié `postgresql.conf` y sigue igual. ¿Quién gana?

:::pista Cómo averiguarlo (en pg-01)
```bash
ssh dba@pg-01
sudo ss -ltnp | grep 5432      # sólo 127.0.0.1 y [::1]
sudo -u postgres psql -c "SELECT setting, sourcefile, sourceline FROM pg_settings WHERE name='listen_addresses'"
#  localhost | .../conf.d/90-hardening.conf | 2
```
`include_dir = 'conf.d'` hace que gane el **último** valor leído. Corrige ahí:
```bash
sudo tee /etc/postgresql/15/main/conf.d/90-hardening.conf >/dev/null <<'EOF'
# Hardening CIS 3.1 (SEC-118): loopback + red interna (excepción INC-6707: app-04).
listen_addresses = 'localhost,10.76.67.20'
EOF
sudo systemctl restart postgresql      # listen_addresses sólo cambia al REINICIAR
```
No pongas `'*'`. Ahora el error cambia a `pg_hba.conf rejects` → es progreso.
:::

## Paso 3 · pg_hba.conf: el orden manda

**Pregúntate:** ¿dónde pongo mi regla? **Encima** del `reject` (gana la primera
que coincide).

:::pista Cómo hacerlo
```bash
sudo -u postgres psql -c 'SELECT line_number,type,database,user_name,address,auth_method FROM pg_hba_file_rules'
sudo nano /etc/postgresql/15/main/pg_hba.conf
```
```
# INC-6707: informe diario desde app-04
host    ventas          informes        10.76.67.10/32          scram-sha-256

# Hardening CIS (SEC-118): rechaza el resto.
host    all             all             0.0.0.0/0               reject
```
```bash
sudo -u postgres psql -c 'SELECT line_number,address,auth_method,error FROM pg_hba_file_rules'  # sin errores
sudo systemctl reload postgresql       # pg_hba.conf se relee con RELOAD
```
Mínimo privilegio: un host /32, un usuario, una BD, `scram-sha-256`.
:::

## Paso 4 · Verifica lo que SÍ y lo que NO

```bash
/usr/local/bin/informe-diario.sh                                      # ok
psql "host=pg-01 dbname=ventas user=informes password=mala" -c 'select 1'   # auth failed (bien)
psql "host=pg-01 dbname=postgres user=informes password=..."                # rejects (bien)
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Lee el error como una capa**: refused → rejects → auth failed, cada uno más
  adentro que el anterior.
- **`pg_settings.sourcefile`** dice qué fichero manda; **`pg_hba_file_rules`**
  enseña cómo interpreta PostgreSQL las reglas antes de recargar.
- **`reload`** para `pg_hba.conf`; **`restart`** para `listen_addresses`.
- **Nunca `trust` en red**; `md5` es obsoleto, usa `scram-sha-256`.

## Si te atascas

- Cambiaste `listen_addresses` y nada → mira `sourcefile`: gana `conf.d/`.
- Sigue `rejects` → tu regla está debajo del `reject`; súbela.
