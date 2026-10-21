# Resolución guiada · Lab 18

:::piensa Antes de tocar nada
Hay dos filosofías de firewall: "acepto todo y bloqueo lo malo" (nunca terminas de listar lo malo) y "bloqueo todo y acepto lo necesario" (*default-deny*). La segunda es la buena. Pero cuidado con el orden: si cierras primero, **te cortas a ti mismo**.
:::

## Paso 1 · ¿Qué necesita entrar?

**Pregúntate:** antes de escribir reglas, haz la lista. ¿Qué tráfico es legítimo?

- La máquina hablando consigo misma (loopback).
- Las **respuestas** a conexiones que la máquina inició (si no, ni `apt` funciona).
- Los servicios que ofrece: SSH (22), HTTP (80), HTTPS (443).

## Paso 2 · Abre lo necesario PRIMERO

**Pregúntate:** ¿qué pasa si pongo la política en DROP y luego añado el 22? Durante ese instante, tu sesión SSH se corta.

:::pista Cómo hacerlo
```bash
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22  -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80  -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```
:::

## Paso 3 · Cierra por defecto

**Pregúntate:** ¿qué hace la política? Decide qué pasa con el paquete que no encaja con ninguna regla.

:::pista Cómo hacerlo
```bash
sudo iptables -P INPUT DROP
sudo iptables -S INPUT
```
La primera línea debe ser `-P INPUT DROP`.
:::

## Paso 4 · Verifica

```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost   # loopback sigue funcionando
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Orden**: loopback → establecidas → servicios → política DROP.
- **Persiste las reglas**: sin `iptables-save`/`netfilter-persistent`, desaparecen al reiniciar.
- **IPv6 también**: `ip6tables` tiene sus propias reglas. Un firewall sólo IPv4 deja la puerta de atrás abierta.
- En remoto, programa una "red de seguridad" antes de cambiar reglas (p.ej. un `at now + 5 min` que ponga la política en ACCEPT) y cancélala si todo va bien.

## Si te atascas

- Reglas duplicadas: `sudo iptables -F INPUT` las borra todas (la política no cambia) y empiezas de nuevo.
