# Resolución guiada · Lab 08

:::piensa Antes de tocar nada
Segmentar es responder, para cada servicio, a la pregunta: **¿desde dónde debe poder llegar alguien aquí?** La web pública: desde cualquier sitio. El panel de administración: sólo desde la propia máquina. El firewall debe reflejar esa respuesta, regla por regla.
:::

## Paso 1 · Lee las reglas tal como están

**Pregúntate:** ¿en qué orden se evalúan las reglas de iptables? De arriba abajo; la primera que encaja decide.

**Por qué importa:** si no entiendes el orden, añadir una regla puede no tener efecto (porque otra anterior ya aceptó el paquete).

:::pista Cómo comprobarlo
```bash
sudo iptables -S INPUT
```
Lee cada línea en voz alta: "acepta loopback", "acepta 80 de cualquiera", "acepta 9000 de cualquiera"… ¿Cuál contradice la intención?
:::

## Paso 2 · Quita la regla permisiva

**Pregúntate:** ¿cómo borro una regla concreta sin tocar las demás? Con `-D` y la misma especificación.

:::pista Cómo hacerlo
```bash
sudo iptables -D INPUT -p tcp --dport 9000 -j ACCEPT
```
:::

## Paso 3 · Bloquea explícitamente

**Pregúntate:** si quito el ACCEPT y la política por defecto es ACCEPT, ¿queda bloqueado? No. Necesitas un DROP explícito.

**Por qué importa:** ¿y la propia máquina? Ya hay una regla que acepta `lo` **antes**, así que el tráfico local sigue llegando.

:::pista Cómo hacerlo
```bash
sudo iptables -A INPUT -p tcp --dport 9000 -j DROP
sudo iptables -S INPUT
```
Comprueba que el `-i lo -j ACCEPT` está por encima del DROP.
:::

## Paso 4 · Lo que debe seguir vivo

**Pregúntate:** ¿he roto algo que debía funcionar? El 80 debe seguir aceptado.

```bash
sudo iptables -S INPUT | grep 'dport 80'
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Primero la intención, luego las reglas**: escribe en una tabla qué puerto, desde dónde.
- **El orden importa**: loopback y establecidas arriba, DROP abajo.
- **Prueba desde fuera**, no desde la propia máquina: el tráfico local entra por `lo` y te engaña.
- En producción: política por defecto `DROP` (lab 18) y abre sólo lo necesario.

## Si te atascas

- `-D` dice "Bad rule": la especificación debe coincidir exactamente con la que aparece en `-S`. Cópiala de ahí cambiando `-A` por `-D`.
