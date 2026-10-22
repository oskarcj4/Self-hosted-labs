# Solución — Lab 80

```bash
# 1) Tiempo de lectura de la petición
sudo a2enmod reqtimeout
sudo tee /etc/apache2/mods-enabled/reqtimeout.conf >/dev/null <<'EOF'
<IfModule reqtimeout_module>
    RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
</IfModule>
EOF

# 2) Timeout y KeepAlive
sudo sed -i 's/^Timeout .*/Timeout 30/' /etc/apache2/apache2.conf
sudo sed -i 's/^KeepAliveTimeout .*/KeepAliveTimeout 5/' /etc/apache2/apache2.conf

# 3) mod_evasive
sudo a2enmod evasive
sudo tee /etc/apache2/mods-enabled/evasive.conf >/dev/null <<'EOF'
<IfModule mod_evasive20.c>
    DOSHashTableSize    3097
    DOSPageCount        5
    DOSSiteCount        100
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   60
    DOSLogDir           "/var/log/apache2"
</IfModule>
EOF

# 4) Validar y aplicar
sudo apache2ctl -t
sudo service apache2 restart
```

Comprobar:

```bash
bash /opt/lab/check.sh
```

## Lecciones

- **Capas**: reqtimeout (conexiones lentas) + Timeout/KeepAlive bajos (no regalar
  tiempo) + mod_evasive (frenar repetición por IP).
- mod_evasive frena a un atacante por IP, **no** a un flood distribuido: para eso
  hacen falta reverse proxy / WAF / CDN (labs 82 y 83).
- Mide antes y después con `ab`; el hardening sin medición es fe, no ingeniería.
- Valida siempre (`apache2ctl -t`) antes de recargar: una config rota en plena
  tormenta de tráfico es peor que el ataque.
