#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/despliegue

# 1. HAProxy con health checks (y recarga sin cortar conexiones).
sudo python3 - <<'PY'
import re
p = "/etc/haproxy/haproxy.cfg"
s = open(p).read()
s = s.replace("    balance roundrobin\n",
              "    balance roundrobin\n"
              "    option httpchk GET /salud\n"
              "    http-check expect status 200\n"
              "    default-server inter 1s fall 2 rise 2\n"
              "    retries 2\n"
              "    option redispatch\n")
s = re.sub(r"^(\s*server web\d 127\.0\.0\.1:800\d)[ \t]*$", r"\1 check", s, flags=re.M)
open(p, "w").write(s)
PY
sudo haproxy -c -q -f /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy

# 2. Playbook: de una en una, drain, health check, versión correcta, vuelta al balanceador.
cat > deploy.yml <<'YML'
# Despliegue de la tienda sin cortes.  Uso:  ansible-playbook deploy.yml -e version=v3
- name: Desplegar la tienda (rolling, una instancia cada vez)
  hosts: web
  become: true
  serial: 1                 # de una en una
  max_fail_percentage: 0    # si falla una, no se toca ninguna más
  vars:
    version: v2
    base: "/srv/web/{{ inventory_hostname }}"
    hap: "socat stdio {{ haproxy_socket }}"

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
      retries: 20
      delay: 0.5
      changed_when: false

  tasks:
    - name: Descomprimir la release
      ansible.builtin.unarchive:
        src: "/opt/releases/web-{{ version }}.tar.gz"
        dest: "{{ base }}/releases/"
        remote_src: true
        owner: web
        group: web
        creates: "{{ base }}/releases/{{ version }}/app.py"

    - name: Apuntar current a la nueva release
      ansible.builtin.file:
        src: "{{ base }}/releases/{{ version }}"
        dest: "{{ base }}/current"
        state: link
        force: true

    - name: Reiniciar la instancia
      ansible.builtin.systemd:
        name: "web@{{ inventory_hostname }}"
        state: restarted

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
      retries: 20
      delay: 0.5
      changed_when: false
YML
ansible-playbook deploy.yml --syntax-check >/dev/null
ansible-playbook deploy.yml -e version=v2
trafico 60
echo "solve.sh completado."
