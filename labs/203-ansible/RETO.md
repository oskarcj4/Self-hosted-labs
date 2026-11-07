# Ansible: de script a rol

> Ansible · roles · idempotencia · handlers · `group_vars`/`host_vars` · `--check --diff`

## Escenario

`~/ansible/desplegar.yml` configura los dos servidores web de la tienda
(`web1` y `web2`). Es un script de shell con YAML alrededor: cada tarea es
un `shell:`, así que **todas** salen como cambiadas en cada ejecución. Además
reinicia nginx aunque no haya cambiado nada y añade otra línea al
`/etc/motd` cada vez. Ya se ha ejecutado dos veces y se nota.

La gracia de Ansible es la idempotencia: describes el estado deseado y lo
ejecutas cuantas veces quieras. Si nada ha cambiado, no toca nada. Si
alguien ha cambiado algo a mano, lo detecta (`--check --diff`) y lo corrige.

## Objetivos

1. Pasarlo a un rol `roles/web` con tasks, handlers, templates y defaults, usando sólo módulos (sin `shell`/`command`).
2. Una segunda ejecución seguida debe dar `changed=0`.
3. nginx sólo se reinicia mediante un handler, cuando cambia su configuración.
4. Variables por niveles: el puerto en `defaults`, el entorno en `group_vars` y el canario `web2` en `host_vars`.
5. El aviso del motd una sola vez y el usuario `despliegue`.

Los detalles están en `~/TAREA.txt`.

## Pistas

```bash
cd ~/ansible
ansible-playbook desplegar.yml            # mira el PLAY RECAP: changed=
ansible-playbook desplegar.yml --check --diff
ansible web -m ansible.builtin.setup -a 'filter=ansible_hostname'
ansible-doc ansible.builtin.template
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
