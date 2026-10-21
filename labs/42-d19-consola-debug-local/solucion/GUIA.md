# Resolución guiada · Día 19

:::piensa Antes de tocar nada
`"5555:5555"` parece inocente, pero sin IP significa **todas las interfaces** (IPv4 e IPv6). Para una consola que ejecuta código sin contraseña, eso es ejecución remota para cualquiera que llegue al host. El uso legítimo (soporte, desde la misma máquina) sólo necesita **loopback**.
:::

## Paso 1 · Comprueba la exposición desde la red

**Pregúntate:** ¿cómo demuestro que es accesible desde fuera? Probando contra la IP de red de la máquina, no contra `localhost`.

:::pista Cómo comprobarlo
```bash
cd ~/billing
docker port billing-api-1
curl -s "http://$(hostname -i):5555/?eval=1+1"
```
Si responde `2`, cualquiera en la red puede ejecutar código.
:::

## Paso 2 · ¿Qué sintaxis liga un puerto a una IP?

**Pregúntate:** la forma larga es `"IP_HOST:PUERTO_HOST:PUERTO_CONTENEDOR"`. ¿Qué IP pongo para que sólo la propia máquina llegue?

:::pista Cómo hacerlo
```yaml
    ports:
      - "8000:8000"
      - "127.0.0.1:5555:5555"
```
```bash
docker compose up -d
docker port billing-api-1
```
:::

## Paso 3 · Verifica los tres casos

**Pregúntate:** ¿qué debe pasar desde la red, desde local y con la API?

```bash
curl -s --max-time 2 http://$(hostname -i):5555/ || echo "red: cerrado"
curl -s http://127.0.0.1:5555/ | head -1
curl -s http://$(hostname -i):8000/ | head -1
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Pon siempre la IP** en `ports:` si el servicio no es público.
- **Docker inserta sus propias reglas de iptables**: un puerto publicado puede saltarse ufw/firewalld. No confíes en el firewall del host para esto.
- **Para soporte remoto**: túnel SSH (`ssh -L 5555:127.0.0.1:5555 servidor`).
- A medio plazo, lo correcto es que una consola así **no exista** en producción.

## Si te atascas

- Sigue respondiendo desde la red: ¿hiciste `docker compose up -d` después de editar?
