# Solución — Día 03: Restringir la interfaz de administración a localhost

## 1. Diagnóstico

```bash
sudo ss -tlnp | grep 9090        # 0.0.0.0:9090 users:(("ops-admin",...))
systemctl cat ops-admin          # ExecStart=... /opt/ops-admin/admin.py
cat /etc/ops-admin/admin.conf    # BIND_ADDR=0.0.0.0
```

## 2. Escuchar sólo en loopback

```bash
sudo sed -i 's/^BIND_ADDR=.*/BIND_ADDR=127.0.0.1/' /etc/ops-admin/admin.conf
sudo systemctl restart ops-admin
sudo ss -tlnp | grep 9090        # 127.0.0.1:9090
```

## 3. La segunda puerta: nginx

Aunque el panel ya escucha en loopback, nginx **también** está en la máquina,
así que puede llegar a `127.0.0.1:9090` y re-publicarlo:

```bash
IP=$(hostname -I | awk '{print $1}')
curl -s http://$IP/admin/        # ¡sigue mostrando el panel!
sudo nginx -T | grep -n -A3 'location /admin/'
```

Quita ese `location` de `/etc/nginx/sites-available/ops`:

```bash
sudo sed -i '/# Acceso cómodo al panel/,/^    }/d' /etc/nginx/sites-available/ops
sudo nginx -t && sudo systemctl reload nginx
```

## 4. Verificar desde la red y en local

```bash
curl -s --max-time 2 http://$IP:9090/ || echo "9090 cerrado desde la red"
curl -s http://$IP/admin/ | head -1     # ya no es el panel
curl -s http://127.0.0.1:9090/          # el panel sigue vivo en local
curl -s http://$IP/                     # portal público OK
```

Para usarlo desde tu portátil: `ssh -L 9090:127.0.0.1:9090 usuario@ops-01`
y abre `http://localhost:9090`.

## Lecciones

- Bind a `127.0.0.1` es la primera barrera: el servicio deja de existir para la red.
- Un **reverse proxy** en la misma máquina se salta esa barrera: revisa
  `proxy_pass` hacia puertos locales.
- Cambia la **configuración**, no sólo el proceso en marcha: si no, vuelve al reiniciar.
