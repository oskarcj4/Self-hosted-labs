# Rollback con cambio de base de datos

> DevOps · despliegues · migraciones · expand/contract · compatibilidad hacia atrás

## Escenario

"Si algo va mal, volvemos a la versión anterior". Funciona... hasta que la
release cambia el esquema de la base de datos:

```
desplegar v2    -> migración 002: RENAME COLUMN nombre TO nombre_completo
desplegar v1    -> v1 hace SELECT nombre ...  ->  500 en toda la tienda
```

El rollback cambia el **código**, no la base de datos. Deshacer la
migración tampoco vale: perderías lo que se escribió con v2.

En producción corre la v1. La v2 está en `/opt/tienda/releases/v2`.
`desplegar vN` aplica las migraciones pendientes y cambia de versión.

## Objetivos

Cambia **sólo la v2** (la v1 ya está desplegada) para que:

1. `v2 → v1 → v2 → …` funcione siempre;
2. no se pierda ningún dato ni se quede ningún cliente sin nombre, en
   ningún sentido;
3. la v2 use la columna nueva `nombre_completo`.

## Pistas

```bash
cat /opt/tienda/releases/v2/migraciones/*.sql
diff /opt/tienda/releases/v1/app.py /opt/tienda/releases/v2/app.py
sudo python3 -c "import sqlite3;c=sqlite3.connect('/var/lib/tienda/tienda.db');print(c.execute('pragma table_info(clientes)').fetchall())"
```

**Expandir y contraer**: en una release se añade lo nuevo sin quitar lo
viejo. Se quita lo viejo en una release posterior, cuando ya no se puede
volver a la versión que lo usaba.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
