# Resolución guiada · Lab 219

:::piensa ¿Por qué falla el despliegue aunque cada paso "funcione"?
Ansible ejecuta cada tarea en **todos** los hosts antes de pasar a la
siguiente. Las 3 instancias se reinician en el mismo segundo y pasan juntas
los ~4 s de calentamiento. HAProxy no lo sabe y les sigue mandando tráfico:
**todos** los clientes ven 503. Para desplegar sin cortes hacen falta tres
cosas: ir de una en una, sacar cada instancia del balanceador antes de
tocarla y no devolverla hasta comprobar que está bien.
:::

**El plan:** (1) medir el problema, (2) dar a HAProxy health checks,
(3) desplegar de una en una y parar si algo falla, (4) sacar, desplegar,
verificar y devolver cada instancia y (5) probar con una release rota.

## Paso 1 · Mide el problema

**Objetivo:** tener una cifra de errores antes de cambiar nada, para saber
después si lo has arreglado.

:::pista Cómo hacerlo
```bash
cd ~/despliegue
trafico 30
ansible-playbook deploy.yml -e version=v2
trafico 30
```
- `trafico N` es un comando del lab: resume las peticiones de los clientes
  simulados de los últimos N segundos.
- `-e version=v2` (*extra vars*) da valor a la variable `version` del
  playbook desde la línea de comandos; gana sobre el valor que tenga dentro.

**Qué deberías ver:** antes, 0 errores. Después del despliegue, cientos, con
`503` de las tres instancias a la vez en "Últimos errores".
:::

## Paso 2 · Health checks en HAProxy

**Objetivo:** que HAProxy deje de mandar tráfico a una instancia que no
responde bien.

**Pregúntate:** ahora mismo, ¿cómo sabe HAProxy si una instancia está sana?

:::pista Cómo hacerlo
No lo sabe: sin `check`, da por buena cualquier instancia. Edita el
`backend web` de `/etc/haproxy/haproxy.cfg`:
```bash
sudo nano /etc/haproxy/haproxy.cfg
```
```
backend web
    balance roundrobin
    option httpchk GET /salud
    http-check expect status 200
    default-server inter 1s fall 2 rise 2
    retries 2
    option redispatch
    server web1 127.0.0.1:8001 check
    server web2 127.0.0.1:8002 check
    server web3 127.0.0.1:8003 check
```

| Directiva | Qué significa |
|---|---|
| `option httpchk GET /salud` | Para comprobar una instancia, HAProxy le pide `/salud` (por defecto sólo miraría si el puerto acepta conexiones). |
| `http-check expect status 200` | Sólo un `200` cuenta como sana. Un `503` de "calentando" no. |
| `default-server inter 1s fall 2 rise 2` | Valores para todos los `server`: comprueba cada 1 s; 2 fallos seguidos la marcan **DOWN**; 2 éxitos seguidos, **UP**. |
| `retries 2` + `option redispatch` | Si la conexión a una instancia falla, reintenta y puede mandar la petición a **otra**. |
| `check` en cada `server` | Activa las comprobaciones para ese servidor. Sin esta palabra, las líneas de arriba no hacen nada. |

Valida y aplica:
```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy
echo "show servers state web" | sudo socat stdio /run/haproxy/admin.sock
```
- `haproxy -c -f fichero` comprueba la sintaxis sin tocar el servicio.
- `reload` aplica la configuración sin cortar las conexiones abiertas.
- HAProxy tiene una **API de administración** en un socket Unix. `socat stdio
  <socket>` conecta tu terminal con ese socket: lo que entra por `echo` es el
  comando; lo que sale es la respuesta.
:::

:::piensa ¿Bastan los health checks para tener 0 errores?
No. HAProxy tarda `fall 2 × inter 1s` ≈ 2 s en marcar una instancia como DOWN,
y en ese tiempo le siguen llegando peticiones. Los health checks protegen de
fallos **inesperados**. Para un reinicio **planificado**, lo correcto es
sacarla antes.
:::

## Paso 3 · De una en una, y parar si falla

**Objetivo:** que nunca estén las tres instancias reiniciándose a la vez, y
que una release rota no pase de la primera.

**Pregúntate:** ¿cómo le dices a Ansible "termina el play entero en un host
antes de empezar con el siguiente"?

:::pista Cómo hacerlo
Al principio del play, debajo de `become: true`:
```yaml
  serial: 1                 # de una en una
  max_fail_percentage: 0    # si falla una, no se toca ninguna más
```
- `serial: 1` divide los hosts en lotes de 1. Ansible ejecuta **todas** las
  tareas en `web1`, luego todas en `web2`… en vez de cada tarea en los tres.
- `max_fail_percentage: 0`: si falla cualquier host de un lote, el playbook
  aborta y no empieza el siguiente lote. Con `serial: 1` ya sería así por
  defecto, pero dejarlo escrito evita sorpresas si mañana alguien cambia el
  `serial` a lotes más grandes.
:::

## Paso 4 · Drain, desplegar, verificar y devolver

**Objetivo:** que cada instancia salga del balanceador antes de reiniciarla y
vuelva sólo cuando esté sana y con la versión correcta.

**Pregúntate:** al sacar una instancia, ¿qué pasa con las peticiones que ya
estaba atendiendo? Y al devolverla, ¿la ve HAProxy UP al instante?

:::pista Cómo hacerlo
Ansible tiene tres secciones que se ejecutan en orden por cada lote:
`pre_tasks` → `tasks` → `post_tasks`. Úsalas así. Añade al play, junto a
`base`, una variable para no repetir el comando de `socat`:
```yaml
    hap: "socat stdio {{ haproxy_socket }}"
```
`haproxy_socket` y `haproxy_backend` ya están definidas en `inventario.ini`.

**Antes de tocar la instancia** (`pre_tasks`, encima de `tasks:`):
```yaml
  pre_tasks:
    - name: Sacar la instancia de HAProxy (drain)
      ansible.builtin.shell: echo "set server {{ haproxy_backend }}/{{ inventory_hostname }} state drain" | {{ hap }}
      changed_when: true

    - name: Esperar a que termine sus peticiones en curso
      ansible.builtin.shell: >
        echo "show stat" | {{ hap }} |
        awk -F, '$1=="{{ haproxy_backend }}" && $2=="{{ inventory_hostname }}" {print $5}'
      register: en_curso
      until: en_curso.stdout | trim == "0"
      retries: 15
      delay: 1
      changed_when: false
```
- `state drain`: HAProxy deja de mandarle peticiones **nuevas**, pero las que
  tiene en curso terminan con normalidad. (`state maint` las cortaría.)
- `show stat` devuelve una tabla CSV con una fila por servidor. `awk -F,`
  parte por comas; la columna 1 es el backend, la 2 el servidor y la **5**
  (`scur`) las sesiones abiertas ahora mismo.
- `register` guarda la salida de la tarea; `until` repite la tarea hasta que
  la condición se cumpla, como mucho `retries` veces, esperando `delay`
  segundos entre intentos. Aquí: hasta que no queden peticiones en curso. Si
  reinicias antes, esas peticiones se cortan y cuentan como errores.
- `delay` tiene que ser un número **entero** en esta versión de Ansible: un
  `0.5` se convierte en `0` (sin pausa).
- `changed_when` sólo decide cómo se informa la tarea (amarillo `changed` o
  verde `ok`); no cambia lo que hace.

**Después de reiniciar** (al final de `tasks:`, tras "Reiniciar la instancia"):
```yaml
    - name: Esperar a que /salud responda 200
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ puerto }}/salud"
        status_code: 200
      register: salud
      until: salud.status == 200
      retries: 15
      delay: 1

    - name: Comprobar que sirve la versión pedida
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ puerto }}/version"
        return_content: true
      register: ver
      failed_when: ver.content | trim != version
```
- El módulo `uri` hace una petición HTTP desde Ansible. Si la respuesta no es
  `status_code`, la tarea falla; con `until` se reintenta mientras la
  instancia calienta (~4 s).
- `return_content: true` guarda el cuerpo de la respuesta en `ver.content`.
- `failed_when` define tú cuándo falla la tarea: aquí, si la versión servida
  no es la pedida. `| trim` quita el salto de línea final antes de comparar.
- Con `v4-rc`, `/salud` responde `500` siempre: tras 15 intentos la tarea
  falla y el playbook se para. `web1` se queda fuera del balanceador (en drain)
  y las otras dos atienden el tráfico.

**Al terminar** (`post_tasks`, debajo de `tasks:`):
```yaml
  post_tasks:
    - name: Devolver la instancia a HAProxy
      ansible.builtin.shell: echo "set server {{ haproxy_backend }}/{{ inventory_hostname }} state ready" | {{ hap }}
      changed_when: true

    - name: Esperar a que HAProxy la vea UP
      ansible.builtin.shell: >
        echo "show stat" | {{ hap }} |
        awk -F, '$1=="{{ haproxy_backend }}" && $2=="{{ inventory_hostname }}" {print $18}'
      register: st
      until: st.stdout | trim == "UP"
      retries: 15
      delay: 1
      changed_when: false
```
- Si una tarea falla, Ansible **no** ejecuta `post_tasks` en ese host: por eso
  una instancia rota nunca vuelve al balanceador.
- La columna **18** de `show stat` es el estado (`UP`, `DOWN`, `DRAIN`…). Hay
  que esperarla: tras `state ready`, HAProxy necesita `rise 2` comprobaciones
  buenas para marcarla UP. Si el siguiente lote entra en drain antes, durante
  un momento sólo sirve **una** instancia.

Antes de lanzarlo, comprueba la sintaxis:
```bash
ansible-playbook deploy.yml --syntax-check
```
:::

## Paso 5 · Prueba la release rota y la buena

```bash
ansible-playbook deploy.yml -e version=v4-rc   # debe FALLAR en web1
trafico 30                                     # 0 errores
ansible-playbook deploy.yml -e version=v3      # debe terminar bien en las 3
trafico 30
bash /opt/lab/check.sh
```
**Qué deberías ver:** con `v4-rc`, `FAILED` en "Esperar a que /salud responda
200" de `web1`, el resumen final con `failed=1` y `web2`/`web3` sin tocar. Con
`v3`, las tres en `ok`. En ambos casos, `trafico 30` con 0 errores.

## Cómo actuar en una situación así

- **Drain frente a maint:** `drain` deja terminar lo que está en curso;
  `maint` corta. Para desplegar, siempre `drain`.
- **Canary:** con muchas máquinas, `serial: ["1", "25%", "100%"]` despliega
  primero en una, luego en un cuarto y luego en el resto.
- **`delegate_to`:** con servidores reales, el drain se ejecuta en la máquina
  del balanceador (`delegate_to: lb1`), no en el host web. Aquí todo vive en la
  misma máquina (`ansible_connection=local`).
- **Capacidad:** con `serial: 1` y 3 instancias, durante el despliegue sirves
  con el 66 %. Dimensiona para aguantar una instancia menos.

## Si te atascas

- **`--syntax-check` da un `ERROR!` que señala la tarea donde está `serial`:** lo
  pusiste dentro de una tarea. Va a nivel del play, al lado de `hosts:` y
  `become:`, con la misma sangría (2 espacios).
- **Siguen saliendo errores en `trafico`:** falta la espera de `scur == 0`
  antes de reiniciar, o la espera de `UP` después de devolverla.
- **Con `v4-rc` el playbook no falla:** te falta la tarea de `/salud` con
  `status_code: 200`, o pusiste `ignore_errors`.
- **Después de `v4-rc`, `web1` aparece en `DRAIN`:** es lo esperado. El
  siguiente despliegue bueno la saca de ahí en su `post_tasks`.
