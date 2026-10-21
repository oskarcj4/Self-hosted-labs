# Solución — La app no llega a la base de datos

## Capa 1: el nombre

```bash
curl -s http://127.0.0.1:8080/health
# orders-app ERROR db db.interno:5432: [Errno 113] No route to host   (o timed out)
getent hosts db.interno
# 10.76.56.99   db.interno       <- IP vieja, de antes de la migración
grep db.interno /etc/hosts
```

`getent` usa el mismo camino que las aplicaciones (`/etc/nsswitch.conf`:
primero `files`, o sea `/etc/hosts`, y después DNS). `dig` sólo pregunta al
DNS, así que no habría visto esta entrada.

```bash
sudo nano /etc/hosts             # cambia 10.76.56.99 por 10.76.56.20
getent hosts db.interno          # 10.76.56.20
```

> En un contenedor, `sed -i` sobre `/etc/hosts` falla con `Device or resource
> busy`. Docker monta ese fichero desde fuera y `sed -i` intenta *reemplazar*
> el fichero por uno nuevo. `nano` o `... | sudo tee /etc/hosts` escriben
> **dentro** del fichero existente y sí funcionan.

## Capa 2: ¿abre TCP?

```bash
nc -zv -w 3 db.interno 5432
# nc: connect to db.interno port 5432 (tcp) timed out
```

**Timeout** (no hay respuesta) suele ser un firewall que tira paquetes
(`DROP`). **Connection refused** es que el host respondió, pero nadie escucha
en ese puerto. Distinguirlos ahorra mucho tiempo.

## Capa 3: el firewall de db-01

```bash
ssh dba@db-01
sudo iptables -S INPUT
# -P INPUT DROP
# ...
# -A INPUT -s 10.76.56.99/32 -p tcp -m tcp --dport 5432 -j ACCEPT    <- IP vieja
```

Arregla la regla en caliente **y** en disco (sin abrir 5432 a todo el mundo):

```bash
sudo iptables -R INPUT 5 -s 10.76.56.10/32 -p tcp --dport 5432 -j ACCEPT
#   (5 = posición de la regla; mírala con: sudo iptables -L INPUT --line-numbers)
sudo sed -i 's#10\.76\.56\.99/32#10.76.56.10/32#' /etc/iptables/rules.v4
sudo iptables-restore --test /etc/iptables/rules.v4 && echo "rules.v4 OK"
```

## Capa 4: ¿quién escucha y dónde?

Desde app-01, `nc` ahora da **Connection refused**: el firewall ya deja
pasar, pero no hay nadie escuchando en esa IP.

```bash
sudo ss -ltnp | grep 5432
# LISTEN 0 5 127.0.0.1:5432 ...  users:(("minidb",...))
sudo sed -i 's/^listen_address = 127.0.0.1/listen_address = 10.76.56.20/' /etc/minidb/minidb.conf
sudo systemctl restart minidb
sudo ss -ltnp | grep 5432        # 10.76.56.20:5432
exit
```

Escuchar sólo en la IP de la red interna (`10.76.56.20`) es mejor que
`0.0.0.0`: si mañana la máquina tiene otra interfaz, la BD no aparece en ella.

## Verificación

```bash
nc -zv db.interno 5432           # succeeded
curl -s http://127.0.0.1:8080/health
# orders-app ok (MINIDB 1.0 READY)
```

## Lecciones

- Diagnostica por capas: **nombre** (`getent`), **ruta** (`ip route get`),
  **firewall** (timeout), **servicio** (refused, `ss -ltn`).
- `ping` no es la prueba: muchos firewalls tiran ICMP. Prueba el puerto real
  con `nc -zv` o `curl -v telnet://host:puerto`.
- Las migraciones de red dejan IPs viejas en `/etc/hosts`, reglas de firewall
  y configs. Búscalas todas: `grep -r 10.76.56.99 /etc`.
- Un cambio de firewall que no está en disco desaparece en el próximo
  reinicio.
