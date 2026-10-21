# Solución — De iptables a nftables

## 1. Entender lo que hay

```bash
cat /etc/firewall/rules-legacy.sh
iptables -S
```

El script heredado:

- `-P INPUT ACCEPT`: todo entra salvo lo que se bloquee (al revés de lo que
  se quiere).
- SSH (22) abierto a cualquiera.
- Telnet (23) y web (80): servicios que ya no existen, pero sus puertos
  siguen abiertos. Superficie de ataque gratis.

```bash
iptables-save | iptables-restore-translate     # traducción literal, de partida
```

Útil para ver la equivalencia, pero el objetivo (un set `admin_nets`, SSH
acotado y con límite) se escribe a mano.

## 2. Escribir /etc/nftables.conf

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
    chain output { type filter hook output priority filter; policy accept; }
}
```

Claves de la migración:

- **`table inet`**: una sola tabla para IPv4 e IPv6, en vez de `iptables` +
  `ip6tables` por separado.
- **`policy drop`** y lista blanca. El orden importa: primero lo barato
  (`lo`, `established,related`), luego lo específico.
- **set `admin_nets`** con `flags interval` para admitir CIDR. Añadir una red
  nueva es tocar una línea, no cada regla.
- **`limit rate 10/minute burst 5`** sólo sobre `ct state new`: frena la
  fuerza bruta de SSH sin molestar a las conexiones ya abiertas.
- **7681** explícito: sin él, `policy drop` te deja fuera de esta terminal.
- Nada de 23 ni 80: no se traducen, se eliminan.

## 3. Aplicar y hacer permanente

```bash
sudo nft -c -f /etc/nftables.conf        # valida SIN aplicar (red de seguridad)
sudo systemctl disable --now legacy-fw.service
sudo iptables -F; sudo iptables -P INPUT ACCEPT    # limpia lo que dejó el script viejo
sudo systemctl enable --now nftables
nft list ruleset
```

Orden deliberado: valida antes de aplicar; quita el servicio viejo para que
no reaparezca al reiniciar; limpia las tablas que dejó iptables para que no
convivan dos cortafuegos; activa nftables. `enable` lo hace permanente.

> Si trabajas en un equipo remoto de verdad (no este lab), aplica con red:
> `( nft -f nuevo.conf; sleep 60; nft -f viejo.conf )` en un `at`/`tmux`, o
> prueba la sesión SSH **antes** de dar por buena la regla. Una política
> `drop` mal puesta te deja fuera.

## Lecciones

- Migrar no es traducir 1:1. Es la ocasión de pasar a **deny por defecto** y
  tirar reglas muertas (telnet, web).
- `inet` + sets + `limit rate`: nftables hace en pocas líneas lo que en
  iptables eran decenas de reglas y dos binarios.
- `nft -c -f` antes de aplicar. Y siempre deja abierto el camino por el que
  administras (aquí, 7681; en producción, tu SSH).
- Un cortafuegos, no dos: deja a nftables como única fuente y desactiva lo
  heredado, o acabarán peleándose.
