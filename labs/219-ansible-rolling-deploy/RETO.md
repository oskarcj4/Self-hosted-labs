# Rolling deploy con Ansible bajo tráfico real

> DevOps · Ansible · `serial` · HAProxy · health checks · drain · zero downtime

## Escenario

La tienda corre en **3 instancias** (`web1`, `web2`, `web3`) detrás de
**HAProxy** (`:8080`). En este momento hay **tráfico real**: unas 100
peticiones por segundo, y cada una que falla queda registrada.

El playbook de despliegue (`~/despliegue/deploy.yml`) funciona... más o menos:

- actualiza las 3 instancias **a la vez**;
- reinicia sin sacarlas del balanceador. Cada instancia tarda ~4 s en
  calentar, y mientras tanto responde `503`;
- si la release viene rota, la despliega **en todas** igualmente.

Además, HAProxy no tiene health checks: le manda tráfico a una instancia
aunque esté caída.

| Servicio | URL |
|----------|-----|
| Tienda (HAProxy) | <http://localhost:8219> |

## Objetivos

1. El despliegue actualiza **de una en una** (`serial: 1`).
2. Cada instancia sale de HAProxy (**drain**) antes de tocarla y vuelve sólo
   cuando `/salud` responde `200` con la **versión pedida**.
3. Con una release rota (`v4-rc`), el playbook **falla y se para** en la
   primera instancia, y los clientes no ven ni un error.
4. HAProxy hace **health checks** de `/salud` en las 3 instancias.

El check despliega `v4-rc` y después `v3` **con tu playbook**, con el tráfico
en marcha, y cuenta los errores. El objetivo es 0.

## Pistas

```bash
cat ~/TAREA.txt; trafico 30
echo "show servers state web" | sudo socat stdio /run/haproxy/admin.sock
curl -s localhost:8001/salud; curl -s localhost:8001/version
```

Mira `serial`, `max_fail_percentage`, `pre_tasks`/`post_tasks`, el módulo
`uri` con `until`, y los comandos `set server <backend>/<server> state drain|ready`
de la API de HAProxy.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
