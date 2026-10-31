# Solución — Secretos en disco y cambios recientes

## Qué pasaba

- Contraseña de base de datos en `config/database.yml`, API key en
  `src/payments.py`, claves AWS exportadas en `scripts/deploy.sh`.
- En las últimas horas apareció la cuenta `soporte2` con shell y un fichero
  `.cache/notas.txt` con la contraseña copiada.

## Arreglo

```bash
cd /srv/app
grep -rnEi "password|api_key|secret|passw|token|AKIA" . > ~/secretos.txt
find . -type f -mtime -1 > ~/recientes.txt

sudo usermod -L -s /usr/sbin/nologin soporte2
sudo nano .env               # mueve aquí DB_PASSWORD, API_KEY, AWS_*
sudo chown app:app .env && sudo chmod 600 .env
sudo sed -i 's|password: "Tienda#Prod2024"|password: <%= ENV["DB_PASSWORD"] %>|' config/database.yml
sudo sed -i 's|^API_KEY = .*|import os\nAPI_KEY = os.environ["API_KEY"]|' src/payments.py
sudo sed -i '/^export AWS_/d; /203.0.113.80/d' scripts/deploy.sh
sudo rm -f .cache/notas.txt
bash /opt/lab/check.sh
```

## Más allá del lab

- Rota todos los secretos encontrados: no sabes quién los leyó.
- Pasa `gitleaks` por el repositorio (lab 134) para ver si también están en el historial.
- Revisa `auth.log` para saber cómo se creó `soporte2`.
