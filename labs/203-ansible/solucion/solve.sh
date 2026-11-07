#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/ansible
mkdir -p roles/web/{tasks,handlers,templates,defaults} group_vars host_vars

cat > desplegar.yml <<'YML'
- name: Servidores web de la tienda
  hosts: web
  become: true
  roles:
    - web
YML

cat > roles/web/defaults/main.yml <<'YML'
puerto: 8080
entorno: dev
web_raiz: /var/www/tienda
YML
cat > group_vars/web.yml <<'YML'
entorno: prod
YML
cat > host_vars/web2.yml <<'YML'
entorno: canario
YML

cat > roles/web/tasks/main.yml <<'YML'
- name: Carpeta de la web
  ansible.builtin.file:
    path: "{{ web_raiz }}"
    state: directory
    mode: "0755"

- name: Página
  ansible.builtin.template:
    src: index.html.j2
    dest: "{{ web_raiz }}/index.html"
    mode: "0644"

- name: Sitio de nginx
  ansible.builtin.template:
    src: tienda.conf.j2
    dest: /etc/nginx/sites-enabled/tienda
    mode: "0644"
  notify: Reiniciar nginx

- name: Usuario de despliegue
  ansible.builtin.user:
    name: despliegue
    shell: /bin/bash
    create_home: true

# /etc/motd entero: lineinfile no quitaría las copias que ya hay.
- name: Aviso en el motd
  ansible.builtin.copy:
    dest: /etc/motd
    content: "Servidor gestionado por Ansible, no tocar a mano.\n"
    mode: "0644"

- name: nginx arrancado y habilitado
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
YML

cat > roles/web/handlers/main.yml <<'YML'
- name: Reiniciar nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
YML

cat > roles/web/templates/index.html.j2 <<'J2'
<h1>tienda en {{ inventory_hostname }} (entorno {{ entorno }})</h1>
J2
cat > roles/web/templates/tienda.conf.j2 <<'J2'
# {{ ansible_managed }}
server {
  listen {{ puerto }};
  root {{ web_raiz }};
}
J2

ansible-playbook desplegar.yml
ansible-playbook desplegar.yml | tee /tmp/segunda.txt
grep -E '^web[12] ' /tmp/segunda.txt
curl -s web1:8080; curl -s web2:8080
echo "solve.sh completado."
