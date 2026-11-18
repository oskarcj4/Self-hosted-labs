# Solución — Rolling deploy con Ansible bajo tráfico real

| Problema | Arreglo |
|----------|---------|
| Las 3 instancias se reinician a la vez | `serial: 1` en el play |
| Una release rota llega a todas | `max_fail_percentage: 0` + verificación de `/salud` y `/version` |
| Se reinicia con tráfico entrando | `pre_tasks`: `set server web/<host> state drain` y esperar `scur == 0` |
| Vuelve al balanceador antes de estar lista | `uri` con `until` sobre `/salud` antes de `state ready` |
| HAProxy manda tráfico a instancias caídas | `option httpchk GET /salud` + `check` en cada `server` |

Todo automatizado en `solve.sh`.

## Notas

- **Drain frente a maint**: `drain` deja terminar las conexiones abiertas y
  no acepta nuevas; `maint` corta. Para un despliegue, usa siempre `drain`.
- **`serial` en lotes**: con muchas máquinas se usa `serial: ["1", "25%", "100%"]`.
  Es un *canary*: primero una, luego un cuarto, luego el resto.
- **`delegate_to`**: con servidores reales, el drain se ejecuta en la
  máquina del balanceador (`delegate_to: lb1`), no en el host web. Aquí todo
  vive en la misma máquina (`ansible_connection=local`).
- **Rollback**: la release anterior sigue en `releases/`. Un play de rescate
  (`block`/`rescue`) puede volver a apuntar `current` a ella y reiniciar.
- **Capacidad**: con `serial: 1` y 3 instancias, el sistema funciona al 66 %
  durante el despliegue. Dimensiona para aguantar una instancia menos.
