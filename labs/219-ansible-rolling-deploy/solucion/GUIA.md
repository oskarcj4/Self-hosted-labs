# Resolución guiada · Lab 219

:::piensa ¿Por qué falla el despliegue actual aunque cada paso "funcione"?
Ansible ejecuta cada tarea en **todos** los hosts antes de pasar a la
siguiente (5 forks). Las 3 instancias se reinician en el mismo segundo y
pasan juntas los ~4 s de calentamiento. HAProxy no lo sabe y les sigue
mandando tráfico: **todos** los clientes ven 503.
:::

## Paso 1 · Mira el tráfico

```bash
trafico 30
tail /var/log/trafico/errores.log
```

Lanza el playbook tal cual (`ansible-playbook deploy.yml -e version=v2`) y
repite `trafico 30`: verás cientos de errores.

## Paso 2 · Health checks en HAProxy

:::pista Cómo hacerlo
En `backend web` de `/etc/haproxy/haproxy.cfg`:
```
    option httpchk GET /salud
    http-check expect status 200
    default-server inter 1s fall 2 rise 2
    retries 2
    option redispatch
    server web1 127.0.0.1:8001 check
    ...
```
Valida y recarga sin cortar conexiones:
`sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy`.
:::

:::piensa ¿Bastan los health checks para tener 0 errores?
No. HAProxy tarda `fall 2 × inter 1s` en marcar una instancia como DOWN, y
en ese tiempo le llegan peticiones. Los health checks protegen de fallos
**inesperados**. Para un reinicio **planificado**, saca antes la instancia
(drain).
:::

## Paso 3 · De una en una, y parar si falla

:::pista Cómo hacerlo
En el play:
```yaml
  serial: 1
  max_fail_percentage: 0
```
Con `serial: 1`, si un host falla, Ansible no sigue con el siguiente lote.
:::

## Paso 4 · Drain, desplegar, verificar y devolver

:::pista Cómo hacerlo
```yaml
  pre_tasks:
    - name: Drain
      ansible.builtin.shell: echo "set server web/{{ inventory_hostname }} state drain" | socat stdio /run/haproxy/admin.sock
  tasks:
    # ... unarchive, symlink, restart ...
    - name: Esperar /salud
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ puerto }}/salud"
      register: salud
      until: salud.status == 200
      retries: 15
      delay: 1
    - name: Versión correcta
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ puerto }}/version"
        return_content: true
      register: ver
      failed_when: ver.content | trim != version
  post_tasks:
    - name: Ready
      ansible.builtin.shell: echo "set server web/{{ inventory_hostname }} state ready" | socat stdio /run/haproxy/admin.sock
```
Si una tarea falla, `post_tasks` no se ejecuta. La instancia rota se queda
fuera del balanceador y las otras dos atienden el tráfico.
:::

:::piensa ¿Por qué esperar también a que la instancia salga del drain?
Al pasar a `ready`, HAProxy la marca UP sólo tras `rise 2` checks buenos.
Si el siguiente host entra en drain antes de eso, durante un momento hay
**una sola** instancia sirviendo. Espera a ver `UP` en `show stat`.
:::

## Paso 5 · Prueba la release rota

```bash
ansible-playbook deploy.yml -e version=v4-rc   # debe FALLAR en web1
trafico 30                                     # 0 errores
ansible-playbook deploy.yml -e version=v3
bash /opt/lab/check.sh
```
