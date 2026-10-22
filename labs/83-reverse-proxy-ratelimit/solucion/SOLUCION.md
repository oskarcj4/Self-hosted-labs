# Solución — Lab 83

```bash
# 1) zona en el contexto http (nginx.conf)
sudo sed -i '/^http {/a \    limit_req_zone $binary_remote_addr zone=web:10m rate=10r/s;\n    limit_req_status 429;' /etc/nginx/nginx.conf

# 2) aplicar el límite en la location, manteniendo el proxy_pass
sudo tee /etc/nginx/sites-available/default >/dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        limit_req zone=web burst=20 nodelay;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# 3) validar y recargar
sudo nginx -t
sudo service nginx reload
```

Probar:

```bash
ab -n 500 -c 50 http://127.0.0.1/     # exceso -> 429/503
bash /opt/lab/check.sh
```

## Lecciones

- El reverse proxy es el borde: filtra antes del backend (token bucket: `rate` +
  `burst`).
- Limita por IP real; si hay CDN/proxy delante, usa `real_ip_header`.
- Un proxy local no sustituye a una CDN cuando el flood satura tu línea de
  entrada: se complementan.
- nginx delante también mitiga Slowloris por el buffering de la petición.
