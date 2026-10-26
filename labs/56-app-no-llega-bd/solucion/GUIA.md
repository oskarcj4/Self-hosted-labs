# Resolución guiada · La app no llega a la base de datos

:::piensa Antes de tocar nada
Una conexión cliente→servidor falla en una de cuatro capas, en este orden:
**nombre** (¿a qué IP resuelve?) → **ruta** (¿hay camino?) → **firewall**
(¿deja pasar?) → **servicio** (¿alguien escucha ahí?). Aquí falla en varias a
la vez. Diagnostica capa por capa y no arregles una sin saber en cuál estás.
:::

## Paso 1 · El nombre (capa 1)

**Pregúntate:** ¿a qué IP resuelve `db.interno` **para las aplicaciones**?
Usa `getent`, no `dig`: `getent` sigue `/etc/nsswitch.conf` (primero
`/etc/hosts`, luego DNS), igual que la app. `dig` sólo pregunta al DNS.

:::pista Cómo comprobarlo
```bash
curl -s http://127.0.0.1:8080/health     # el error exacto de la app
getent hosts db.interno                   # 10.76.56.99  <- IP vieja (pre-migración)
grep db.interno /etc/hosts
```
Arréglalo (la IP real de db-01 es `10.76.56.20`):
```bash
sudo nano /etc/hosts        # cambia 10.76.56.99 -> 10.76.56.20
getent hosts db.interno     # 10.76.56.20
```
:::

:::pista Si `sed -i /etc/hosts` da "Device or resource busy"
En contenedor, Docker monta `/etc/hosts` desde fuera. `sed -i` intenta
**reemplazar** el fichero y falla. `nano` o `... | sudo tee /etc/hosts`
escriben **dentro** y sí funcionan.
:::

## Paso 2 · ¿Abre TCP? (distingue firewall de servicio)

**Pregúntate:** ¿el puerto responde? Y si no, ¿es **timeout** o **refused**?
Son pistas distintas:
- **timeout** → nadie responde: suele ser firewall que hace `DROP`.
- **connection refused** → el host respondió pero nadie escucha ahí.

```bash
nc -zv -w 3 db.interno 5432     # timed out  -> mira el firewall de db-01
```

> `ping` no sirve de prueba: muchos firewalls tiran ICMP. Prueba el puerto real.

## Paso 3 · El firewall de db-01 (capa 3)

**Pregúntate:** la regla que abre 5432 ¿a qué origen apunta? Seguramente a la
IP vieja de app-01. Hay que arreglarla **sin** romper el default-deny y
**guardarla en disco**.

:::pista Cómo hacerlo
```bash
ssh dba@db-01
sudo iptables -S INPUT
# -P INPUT DROP ... -A INPUT -s 10.76.56.99/32 -p tcp --dport 5432 -j ACCEPT  <- vieja
sudo iptables -L INPUT --line-numbers         # localiza el número de regla (p.ej. 5)
sudo iptables -R INPUT 5 -s 10.76.56.10/32 -p tcp --dport 5432 -j ACCEPT
sudo sed -i 's#10\.76\.56\.99/32#10.76.56.10/32#' /etc/iptables/rules.v4
sudo iptables-restore --test /etc/iptables/rules.v4 && echo "rules.v4 OK"
```
Abre sólo a app-01 (o su subred), nunca a `0.0.0.0/0`. Un cambio que no está en
`rules.v4` desaparece en el próximo reinicio.
:::

## Paso 4 · ¿Quién escucha y dónde? (capa 4)

**Pregúntate:** ahora `nc` da **refused** desde app-01: el firewall ya deja
pasar, pero ¿minidb escucha en una IP alcanzable, o sólo en loopback?

:::pista Cómo hacerlo (en db-01)
```bash
sudo ss -ltnp | grep 5432        # 127.0.0.1:5432  <- sólo loopback
sudo sed -i 's/^listen_address = 127.0.0.1/listen_address = 10.76.56.20/' /etc/minidb/minidb.conf
sudo systemctl restart minidb
sudo ss -ltnp | grep 5432        # 10.76.56.20:5432
exit
```
Escuchar en la IP de la red interna es mejor que `0.0.0.0`: no se expone en
interfaces futuras sin querer.
:::

## Paso 5 · Verifica de extremo a extremo

```bash
nc -zv db.interno 5432                    # succeeded
curl -s http://127.0.0.1:8080/health      # orders-app ok (MINIDB 1.0 READY)
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Diagnostica por capas**: `getent` (nombre), `ip route get` (ruta),
  timeout vs refused (firewall vs servicio), `ss -ltn` (quién escucha).
- **`ping` no prueba un servicio**: usa `nc -zv` o `curl -v telnet://host:puerto`.
- **Las migraciones dejan IPs viejas** en `/etc/hosts`, firewall y configs.
  Cázalas todas: `grep -r 10.76.56.99 /etc`.
- **Firewall sin guardar = temporal.** Persiste en `rules.v4` y valídalo con
  `iptables-restore --test`.

## Si te atascas

- `getent` da la IP vieja: sigue en `/etc/hosts`; edítalo con `nano`/`tee`.
- `nc` timeout: firewall; `nc` refused: servicio escuchando en otra IP.
- Funciona ahora pero temes el reinicio: ¿guardaste `rules.v4`?
