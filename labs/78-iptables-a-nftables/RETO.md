# De iptables a nftables

> Operaciones · cortafuegos · nftables · migración · hardening

## Escenario

Estás en `fw-01`. El cortafuegos corre con un script de `iptables` de 2015
(`/etc/firewall/rules-legacy.sh`, servicio `legacy-fw.service`). Auditoría lo
rechaza: política por defecto **ACCEPT**, SSH abierto a todo Internet y
reglas de servicios que ya no existen. Lee `~/ticket/CHG-7801.txt`.

> ⚠️ Esta terminal llega por el puerto **7681**. Si lo cierras o pones la
> política en drop sin permitirlo, **pierdes el acceso**. Piénsalo antes de
> aplicar.

## Objetivos

Migrar a **nftables nativo**, con `/etc/nftables.conf` como única fuente,
cargado por `nftables.service`:

1. Política de `input`: **drop**. Permite loopback, `established,related` e
   ICMP (ping).
2. SSH (22): **sólo** desde las redes de administración, con **límite de
   ritmo**. Usa un set llamado `admin_nets` = `{ 10.76.78.0/24, 192.168.10.0/24 }`.
3. La consola web (tcp/**7681**) sigue abierta.
4. Nada de telnet (23) ni web (80).
5. Desactiva `legacy-fw.service`: nftables tiene que ser el único cortafuegos.
6. Persiste tras reinicio.

## Comandos que te pueden servir

```bash
cat /etc/firewall/rules-legacy.sh        # lo que hay que traducir
iptables -S                              # reglas cargadas ahora mismo
nft list ruleset                         # lo que ve nftables
# traducción automática (buen punto de partida, NO el resultado final):
iptables-save | iptables-restore-translate
man nft    # busca: set, interval, ct state, limit rate, policy
nft -c -f /etc/nftables.conf             # valida SIN aplicar
systemctl disable --now legacy-fw.service
systemctl enable --now nftables
```

Pista: la política `drop` sólo deja pasar lo que aceptes explícitamente;
repasa que están loopback, established/related y el 7681 **antes** de
aplicar. `iptables-restore-translate` te da una traducción literal, pero el
resultado que piden (un set `admin_nets`, SSH acotado, sin telnet/web) hay
que escribirlo a mano.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
