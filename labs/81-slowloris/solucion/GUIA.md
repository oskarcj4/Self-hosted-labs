# Resolución guiada · Lab 81

:::piensa Antes de tocar nada
Slowloris no te gana por fuerza, sino por **paciencia**: mantiene abiertas conexiones a medio enviar hasta agotar los workers. La defensa no es "más potencia", es **impaciencia del servidor**: si una petición no avanza a un ritmo mínimo, se corta. Eso es exactamente lo que hace `mod_reqtimeout`.
:::

## Paso 1 · Reproduce el ataque (para entenderlo)

```bash
python3 /opt/lab/slowtest.py 150 30
# verás "conexiones vivas: 150" mantenido: el servidor las aguanta esperando
# en otra terminal, mientras corre:
curl -m 5 http://127.0.0.1/     # puede tardar o fallar
```

## Paso 2 · Habilita mod_reqtimeout

**Pregúntate:** ¿cuánto tiempo es razonable que tarde un cliente real en enviar sus cabeceras? Segundos, no minutos.

:::pista Cómo hacerlo
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
:::

## Paso 3 · Comprueba que ya no aguanta conexiones lentas

```bash
python3 /opt/lab/slowtest.py 150 30
# ahora "conexiones vivas" cae a ~0: Apache corta a los lentos
curl -m 5 http://127.0.0.1/     # responde al instante
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- `mod_reqtimeout` cubre **slow headers** y **slow body**. Para el *slow read*
  (el cliente lee la respuesta gota a gota) necesitas límites de salida o un
  reverse proxy que absorba (lab 83).
- Un **reverse proxy** (nginx) delante de Apache mitiga Slowloris casi solo:
  nginx **bufferiza** la petición completa antes de pasarla, así que las
  conexiones lentas las aguanta nginx (event-driven), no los workers de Apache.
- No pongas `MinRate` tan alto que mates a móviles en redes malas.
- Mide siempre con el probador antes y después; "parece que va mejor" no es una
  métrica.
