#!/usr/bin/env bash
# Lab 203: un "playbook" que en realidad es un script de shell con YAML
# alrededor. Cada ejecución cambia algo, reinicia nginx y duplica líneas.
# La misma imagen corre en el control y en web1/web2: los web sólo arrancan SSH.
set -e
case "$(hostname)" in
  web1|web2)
    systemctl enable --now ssh >/dev/null 2>&1
    echo "Nodo $(hostname) listo (SSH)."
    exit 0;;
esac

H=/home/analista
A=$H/ansible
AN(){ runuser -u analista -- env HOME=$H "$@"; }

# Esperar a que web1 y web2 acepten SSH
for n in $(seq 1 120); do
  AN ssh -o BatchMode=yes -o ConnectTimeout=3 web1 true 2>/dev/null \
    && AN ssh -o BatchMode=yes -o ConnectTimeout=3 web2 true 2>/dev/null && break
  sleep 2
done
AN ssh -o BatchMode=yes web1 true && AN ssh -o BatchMode=yes web2 true

mkdir -p $A
cat > $A/ansible.cfg <<'CFG'
[defaults]
inventory = inventario.ini
interpreter_python = auto_silent
retry_files_enabled = False
stdout_callback = default
CFG
cat > $A/inventario.ini <<'INI'
[web]
web1
web2
INI
cat > $A/desplegar.yml <<'YML'
# "Playbook" heredado: funciona... la primera vez.
- hosts: web
  become: true
  tasks:
    - name: carpeta de la web
      shell: mkdir -p /var/www/tienda

    - name: página
      shell: echo "<h1>tienda</h1>" > /var/www/tienda/index.html

    - name: sitio de nginx
      shell: |
        echo 'server { listen 8080; root /var/www/tienda; }' > /etc/nginx/sites-enabled/tienda

    - name: usuario de despliegue
      shell: useradd -m despliegue || true

    - name: aviso en el motd
      shell: echo 'Servidor gestionado por Ansible, no tocar a mano.' >> /etc/motd

    - name: reiniciar nginx
      shell: systemctl restart nginx
YML
chown -R analista:analista $A
# Ya se ha ejecutado dos veces en producción
(cd $A && AN ansible-playbook desplegar.yml >/dev/null && AN ansible-playbook desplegar.yml >/dev/null)

cat > $H/TAREA.txt <<'TXT'
TAREA · De script disfrazado a rol de Ansible

~/ansible/desplegar.yml "funciona", pero cada vez que se ejecuta cambia todo,
reinicia nginx aunque nada haya cambiado y añade otra línea al /etc/motd
(mira cómo está ya: ssh web1 cat /etc/motd). Nadie se atreve a pasarlo.

Conviértelo en un rol de verdad:

1. roles/web con tasks/, handlers/, templates/ y defaults/; desplegar.yml sólo
   aplica el rol a [web]. Nada de shell/command/raw: módulos de ansible.builtin.
2. Idempotente: la segunda ejecución seguida termina con changed=0 en los dos.
3. nginx sólo se reinicia (o recarga) a través de un handler, cuando cambia su
   configuración. Y queda arrancado y habilitado.
4. La página dice:  tienda en <host> (entorno <entorno>)
     - puerto 8080 por defecto (defaults/main.yml del rol)
     - entorno "prod" para el grupo web (group_vars/web.yml)
     - web2 es el canario: entorno "canario" (host_vars/web2.yml)
5. El aviso del motd aparece UNA vez (arregla las copias que ya hay) y el
   usuario despliegue existe con shell /bin/bash.

El check estropeará web1 a mano y espera que tu playbook lo detecte en
--check --diff y lo deje bien.

  cd ~/ansible && ansible-playbook desplegar.yml
  curl web1:8080

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 203 plantado."
