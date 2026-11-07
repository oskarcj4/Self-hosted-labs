# Resolución guiada · Lab 203

:::piensa ¿Por qué `shell:` siempre sale como "changed"?
Ansible no sabe qué hace tu comando, así que supone que cambió algo. Un
módulo (`file`, `template`, `user`…) compara el estado actual con el
deseado y sólo actúa si difieren. Esa comparación es la idempotencia.
:::

## Paso 1 · Estructura

:::pista Cómo
```
roles/web/
  defaults/main.yml     # puerto: 8080
  tasks/main.yml
  handlers/main.yml
  templates/index.html.j2, tienda.conf.j2
group_vars/web.yml      # entorno: prod
host_vars/web2.yml      # entorno: canario
```
`desplegar.yml` queda en `hosts: web`, `become: true` y `roles: [web]`.
:::

## Paso 2 · Cada `shell:` por su módulo

:::pista Equivalencias
- `mkdir -p` → `ansible.builtin.file` (`state: directory`)
- `echo ... >` → `ansible.builtin.template` o `copy` (`content:`)
- `useradd || true` → `ansible.builtin.user`
- `systemctl restart` en cada pasada → `notify:` en la tarea del sitio, un handler que reinicia, y `service: state=started enabled=true` en las tareas
:::

## Paso 3 · El motd

:::pista Trampa
`lineinfile` comprueba que la línea esté, pero no borra las copias que ya
hay. Gestiona el fichero entero con `copy` y `content:`. Si quieres
conservar el resto del motd, usa `lineinfile` con `state: absent` y luego
añade la línea (cuidado: así deja de ser idempotente).
:::

## Paso 4 · Comprobar

:::pista Cómo
Ejecútalo dos veces y mira `changed=0` en el PLAY RECAP. Luego estropea web1
a mano (`ssh web1 sudo sed -i s/8080/8081/ /etc/nginx/sites-enabled/tienda`)
y ejecuta `--check --diff`: debe enseñarte la diferencia sin tocar nada.
:::

## Cómo actuar en una situación así

- La precedencia de variables, de menor a mayor: `defaults` del rol, `group_vars`, `host_vars`, `vars` del play y `-e`.
- Los handlers se ejecutan al final del play, una vez, sólo si alguien los notificó.
- `ansible-lint` avisa de `command`/`shell` sin `changed_when` y de otras malas prácticas.
