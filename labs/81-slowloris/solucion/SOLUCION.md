# Solución — Lab 81

```bash
sudo a2enmod reqtimeout
sudo tee /etc/apache2/mods-enabled/reqtimeout.conf >/dev/null <<'EOF'
<IfModule reqtimeout_module>
    RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
</IfModule>
EOF
sudo apache2ctl -t
sudo service apache2 restart
```

Comprobar (opcional, para verlo):

```bash
python3 /opt/lab/slowtest.py 150 30   # "conexiones vivas" cae a ~0
bash /opt/lab/check.sh
```

## Lecciones

- Slowloris agota **workers**, no ancho de banda: la defensa es cortar a quien no
  envía su petición a un ritmo mínimo (`MinRate`).
- `mod_reqtimeout` es la mitigación nativa: `header=` para las cabeceras,
  `body=` para el cuerpo.
- Un reverse proxy con buffering (nginx, lab 83) delante de Apache absorbe estas
  conexiones lentas por diseño.
- El mismo probador que usas para atacar sirve para **verificar** la mitigación:
  medir es parte de la defensa.
