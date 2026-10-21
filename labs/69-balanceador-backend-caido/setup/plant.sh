#!/usr/bin/env bash
# Lab 69 (lb-01): nginx reparte en round robin entre 3 backends. app2 da 503 y
# app3 tarda 8 s, y nginx no reintenta ni aparta a los que fallan.
set -e
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/tienda <<'EOF'
upstream tienda {
    server 10.76.69.21:8080;   # app1
    server 10.76.69.22:8080;   # app2
    server 10.76.69.23:8080;   # app3
}

server {
    listen 80 default_server;
    server_name tienda.local;

    location / {
        proxy_pass http://tienda;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # "Que no reintente, que duplica pedidos" (2023)
        proxy_next_upstream off;
    }
}
EOF
ln -sf /etc/nginx/sites-available/tienda /etc/nginx/sites-enabled/tienda
systemctl enable --now nginx

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-6909.txt <<'EOF'
INC-6909 · lb-01 · la tienda falla "a veces"
- 1 de cada 3 peticiones da 503 y otra de cada 3 tarda 8 segundos.
- Desarrollo ya está con app2 (BD) y app3 (GC). Tardarán horas.
- Mientras tanto, el balanceador tiene que proteger a los clientes:
  * Todas las peticiones 200 y en menos de 3 s, aunque haya backends mal.
  * NO saques app2 ni app3 del upstream a mano (ni 'down'): cuando se
    arreglen deben volver a recibir tráfico solos, en 30 s como mucho.
  * Los pedidos son POST: nginx no debe reintentarlos en otro backend
    (el comentario de 2023 tenía su motivo).
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 69 plantado."
