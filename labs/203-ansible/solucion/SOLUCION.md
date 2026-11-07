# Solución — Ansible

`desplegar.yml`:

```yaml
- name: Servidores web de la tienda
  hosts: web
  become: true
  roles:
    - web
```

`roles/web/tasks/main.yml`: `file` (carpeta), `template` (página),
`template` del sitio con `notify: Reiniciar nginx`, `user` (despliegue con
bash), `copy` de `/etc/motd` con `content:` y `service` (started, enabled).

`roles/web/handlers/main.yml`:

```yaml
- name: Reiniciar nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

Plantillas:

```
<h1>tienda en {{ inventory_hostname }} (entorno {{ entorno }})</h1>
```
```
server { listen {{ puerto }}; root {{ web_raiz }}; }
```

Variables: `roles/web/defaults/main.yml` (`puerto: 8080`, `entorno: dev`),
`group_vars/web.yml` (`entorno: prod`) y `host_vars/web2.yml`
(`entorno: canario`).

Resultado: la primera pasada corrige todo (incluido el motd duplicado), la
segunda da `changed=0` y no reinicia nginx. Si alguien cambia el puerto a
mano, `--check --diff` lo enseña, y la siguiente ejecución lo devuelve y
reinicia nginx mediante el handler.

Ficheros completos en `solve.sh`.
