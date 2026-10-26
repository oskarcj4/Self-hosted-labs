# Resolución guiada · De iptables a nftables

:::piensa Antes de tocar nada
⚠️ Esta terminal llega por el puerto **7681**. Si lo cierras o pones `policy
drop` sin permitirlo, **pierdes el acceso**. Revisa que están loopback,
`established,related` y el 7681 **antes** de aplicar, y valida con `nft -c -f`.
Migrar no es traducir 1:1: es la ocasión de pasar a **deny por defecto** y tirar
reglas muertas (telnet, web). `iptables-restore-translate` es sólo punto de
partida; el set `admin_nets` y el SSH acotado se escriben a mano.
:::

## Paso 1 · Entiende lo que hay

```bash
cat /etc/firewall/rules-legacy.sh
iptables -S
# -P INPUT ACCEPT  (al revés de lo que se quiere)
# SSH 22 abierto a todos; telnet 23 y web 80 abiertos sin servicio detrás
iptables-save | iptables-restore-translate     # equivalencia literal, de partida
```

## Paso 2 · Escribe `/etc/nftables.conf`

**Pregúntate:** ¿qué debe pasar **antes** del drop por defecto? lo, established,
ICMP, SSH acotado desde admin, y 7681.

:::pista La config
```nft
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    set admin_nets {
        type ipv4_addr
        flags interval
        elements = { 10.76.78.0/24, 192.168.10.0/24 }
    }
    chain input {
        type filter hook input priority filter; policy drop;

        iif "lo" accept
        ct state established,related accept
        ct state invalid drop

        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept

        ip saddr @admin_nets tcp dport 22 ct state new \
            limit rate 10/minute burst 5 packets accept

        tcp dport 7681 accept
    }
    chain forward { type filter hook forward priority filter; policy drop; }
    chain output  { type filter hook output  priority filter; policy accept; }
}
```
- **`table inet`**: IPv4 e IPv6 en una tabla (no `iptables` + `ip6tables`).
- **`policy drop`** + lista blanca; primero lo barato (`lo`, established).
- **set `admin_nets`** con `flags interval` para CIDR: añadir red = una línea.
- **`limit rate 10/minute burst 5`** sólo sobre `ct state new`: frena fuerza
  bruta SSH sin molestar conexiones vivas.
- **7681 explícito**: sin él, `policy drop` te echa de esta terminal.
- 23 y 80 no se traducen: se eliminan.
:::

## Paso 3 · Aplica y haz permanente (orden deliberado)

**Pregúntate:** ¿cómo evito que convivan dos cortafuegos?

:::pista Cómo hacerlo
```bash
sudo nft -c -f /etc/nftables.conf        # valida SIN aplicar
sudo systemctl disable --now legacy-fw.service
sudo iptables -F; sudo iptables -P INPUT ACCEPT    # limpia lo que dejó el script viejo
sudo systemctl enable --now nftables
nft list ruleset
bash /opt/lab/check.sh
```
Valida → quita el servicio viejo (que no reaparezca al reiniciar) → limpia las
tablas de iptables (que no convivan dos cortafuegos) → activa nftables.
`enable` lo hace permanente.
:::

:::piensa En un equipo remoto real (no este lab)
Aplica con red de seguridad: `( nft -f nuevo.conf; sleep 60; nft -f viejo.conf )`
en un `at`/`tmux`, o prueba una nueva sesión SSH **antes** de dar la regla por
buena. Una `policy drop` mal puesta te deja fuera.
:::

## Cómo actuar en una situación así

- **Migrar no es traducir 1:1**: aprovecha para **deny por defecto** y tirar
  reglas muertas.
- **`inet` + sets + `limit rate`**: nftables hace en pocas líneas lo que en
  iptables eran decenas de reglas y dos binarios.
- **`nft -c -f` antes de aplicar**, y deja siempre abierto el camino de
  administración (aquí 7681; en producción, tu SSH).
- **Un cortafuegos, no dos**: nftables única fuente, desactiva el heredado.

## Si te atascas

- Perdiste el acceso a la terminal → faltó `tcp dport 7681 accept` antes del
  drop (recupéralo por consola local).
- SSH no entra desde admin → revisa `admin_nets` (`flags interval`) y que la
  regla está antes del drop implícito.
- Tras reiniciar vuelve el viejo → no hiciste `disable` de `legacy-fw.service`
  o falta `enable` de nftables.
