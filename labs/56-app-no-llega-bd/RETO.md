# La app no llega a la base de datos

> Operaciones · Redes · 2 servidores · DNS, firewall y bind

## Escenario

Anoche se migró la red interna y desde entonces `orders-app` (en `app-01`, la
máquina donde estás) devuelve **503**. El equipo de datos jura que la BD de
`db-01` "está arriba". Tienes el ticket en `~/ticket/INC-4120.txt`, con el
acceso SSH a `db-01`.

```
app-01 (10.76.56.10)  ──TCP 5432──▶  db-01 (10.76.56.20)  minidb
```

Una conexión puede fallar en varias capas: **nombre → ruta → firewall →
proceso escuchando**. Aquí falla en más de una. Ve capa por capa y no cambies
nada sin saber qué capa estás arreglando.

## Objetivos

1. `db.interno` resuelve en `app-01` a la IP **actual** de `db-01`.
2. `app-01` conecta a `db-01:5432` y `orders-app /health` responde **200**.
3. En `db-01`, el firewall **sigue en default-deny**: abre 5432 **sólo** a
   `app-01` (o a su subred), y deja el cambio **guardado** en
   `/etc/iptables/rules.v4`.
4. `minidb` escucha en una interfaz que se pueda alcanzar desde la red.

> En `db-01` corre un agente de inventario en el puerto 9100. Es de sólo
> lectura y lo usa el validador: no lo pares.

## Comandos que te pueden servir

```bash
curl -s http://127.0.0.1:8080/health     # el error exacto de la app
getent hosts db.interno                  # lo que resuelve el sistema (hosts + DNS)
nc -zv -w 3 db.interno 5432               # ¿abre TCP?
ping -c1 10.76.56.20                     # ojo: ICMP también puede estar filtrado
ssh dba@db-01
  sudo ss -ltnp                          # ¿en qué IP escucha?
  sudo iptables -S INPUT -v              # reglas y contadores
  cat /etc/minidb/minidb.conf
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
