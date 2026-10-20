# Lab 18 — Levanta un firewall base (default-deny)

## Escenario (tarea de hardening)

`fw-18` está con el firewall **abierto de par en par**: la política por defecto de
la cadena `INPUT` es `ACCEPT` y no hay reglas. Aplica una base sensata de
*default-deny*: bloquea todo lo entrante salvo lo necesario.

## Objetivos

Configura `iptables` (cadena `INPUT`) para que:

1. La **política por defecto** sea `DROP`.
2. Se acepte el tráfico de **loopback** (`lo`).
3. Se acepte el tráfico de conexiones **ya establecidas** (`ESTABLISHED,RELATED`).
4. Se acepten **sólo** los puertos entrantes `22` (SSH), `80` (HTTP) y `443` (HTTPS).

## Comandos que te pueden servir

```bash
sudo iptables -S INPUT                 # estado actual
sudo iptables -P INPUT DROP
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22  -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80  -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

> Orden importa: acepta loopback y establecidas **antes** de que la política DROP
> corte todo. Si administras por SSH, abre el 22 antes de poner la política en DROP.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
