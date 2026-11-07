# Resolución guiada · Lab 173

:::piensa ¿Qué mide el verde?
`/health` devuelve 200 sin tocar el pool, ni la CPU, ni el DNS. Un health
check que no prueba lo que usa el usuario es un adorno. Mide desde fuera, con
la petición real (`/comprar`), y divide el tiempo por capas.
:::

## Paso 1 · ¿Dónde se va el tiempo?

:::pista Qué mirar
```bash
time getent hosts pagos.interno     # ~2 s: DNS
curl -s localhost:8080/pool         # en_uso sube y no baja: fuga
cat /sys/fs/cgroup/system.slice/tienda.service/cpu.stat   # nr_throttled sube
```
:::

## Paso 2 · DNS

:::pista Qué pasa
`/etc/resolv.conf` lista primero `127.0.0.2`, que nunca responde.
glibc espera `timeout:2` y luego prueba el siguiente. Cada petición paga 2 s.
Quita esa línea.
:::

## Paso 3 · CPU

:::pista Qué pasa
`CPUQuota=5%` = 50 ms de CPU por segundo. `calcular_total` necesita más, así
que el kernel congela el proceso hasta el siguiente periodo. Quita la línea (o
pon un valor realista) y `daemon-reload`.
:::

## Paso 4 · El pool

:::pista Qué pasa
En el `except HTTPError` hay un `return` antes de `POOL.devolver()`. Cada pago
rechazado se queda una conexión. Usa `try/finally`:
```python
try:
    ...
finally:
    POOL.devolver()
```
:::

## Cómo actuar en una situación así

- Mide lo que ve el usuario (latencia y errores de la ruta real), no sólo "proceso vivo".
- Divide por capas: red/DNS, CPU/memoria del cgroup, recursos de la app (pools, colas).
- Expón métricas de saturación del pool (`en_uso`/`tam`) y alerta antes del 100 %.

## Si te atascas

- `strace -e trace=sendto,recvfrom` en el proceso muestra consultas a `127.0.0.2:53` sin respuesta.
- Si `cpu.stat` no existe en esa ruta: `systemctl status tienda` muestra el cgroup.
