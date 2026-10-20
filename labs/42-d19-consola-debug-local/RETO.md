# Día 19 — Consola de depuración sólo en local

> 30 días de DevSecOps · Docker · Exposición del runtime de contenedores

## Escenario

La API de facturación (`~/billing`) trae una **consola de depuración** en el
puerto `5555` que evalúa expresiones Python **sin autenticación**:

```bash
curl -s 'http://localhost:5555/?eval=__import__("os").popen("id").read()'
```

El equipo de soporte la usa desde **este mismo servidor** y no quiere
perderla, pero hoy está publicada en todas las interfaces: cualquiera que
llegue a la IP del host tiene ejecución remota de código.

## Objetivos

1. La consola `5555` sólo debe publicarse en **loopback** (`127.0.0.1`).
2. Desde la red (`$(hostname -i):5555`) no debe responder.
3. Desde el propio servidor (`127.0.0.1:5555`) sí.
4. La API sigue pública en `:8000`.
5. El cambio debe estar en `compose.yaml`.

## Comandos que te pueden servir

```bash
cd ~/billing && cat compose.yaml
docker compose ps
docker port billing-api-1
hostname -i                                  # IP "de red" de este servidor
curl -s http://$(hostname -i):5555/ ; curl -s http://127.0.0.1:5555/
docker compose up -d
```

> Pista: la sintaxis larga de `ports:` es `"IP_HOST:PUERTO_HOST:PUERTO_CONTENEDOR"`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
