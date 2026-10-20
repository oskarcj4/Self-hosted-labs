# Día 21 — Configuración montada en sólo lectura

> 30 días de DevSecOps · Docker · Montajes, usuarios y privilegios

## Escenario

El API gateway del stack `edge` (`~/edge`) lee sus rutas de
`/etc/gateway/routes.conf`, que viene de la carpeta `./config` del host
montada **en lectura/escritura**. Si alguien compromete el gateway, puede
reescribir las rutas y desviar tráfico… y el cambio persiste en el host.

## Objetivos

1. Monta `./config` en `/etc/gateway` en **sólo lectura**.
2. Desde dentro del contenedor no debe poder escribirse en `/etc/gateway`.
3. El gateway debe seguir arrancando y sano: `curl localhost:8080/health`.
4. `config/routes.conf` no debe cambiar.
5. El cambio debe estar en `compose.yaml`.

> Ojo: si sólo pones `:ro`, el gateway **no arrancará**. Lee los logs y el
> `README.md` del proyecto para ver por qué y cómo evitarlo.

## Comandos que te pueden servir

```bash
cd ~/edge && cat compose.yaml README.md
docker compose up -d
docker compose ps -a
docker compose logs gateway --tail 20
docker inspect edge-gateway-1 --format '{{json .Mounts}}' | jq
docker compose exec gateway touch /etc/gateway/prueba
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
