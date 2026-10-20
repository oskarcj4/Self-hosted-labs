# Solución — Día 10: Frontera de escritura de logs

## 1. Diagnóstico

```bash
ls -la /var/log/payments/
# drwxrwxrwx root root  .
# -rw-rw-rw- root root  transactions.log
# -rw-r--r-- root root  transactions.log.1    <- rotado, con tokens
cat /etc/logrotate.d/payments                 # create 0666 root root
sudo logrotate -d /etc/logrotate.d/payments   # "parent directory has insecure permissions"
```

## 2. La carpeta y los logs existentes

```bash
sudo chown payments:payments /var/log/payments
sudo chmod 0750 /var/log/payments
sudo chown payments:payments /var/log/payments/transactions.log*
sudo chmod 0640 /var/log/payments/transactions.log*
```

- `payments` escribe; su grupo (para lectores autorizados) lee; el resto, nada.
- Si un equipo de soporte debe leerlos, mételos en un grupo (p.ej. `adm`) y usa
  ese grupo, nunca "otros".

## 3. logrotate

```bash
sudo sed -i 's/^\(\s*\)create .*/\1create 0640 payments payments/' /etc/logrotate.d/payments
sudo logrotate -d /etc/logrotate.d/payments    # sin errores
sudo logrotate -f /etc/logrotate.d/payments    # rota de verdad
ls -l /var/log/payments/                       # el nuevo .log: -rw-r----- payments payments
```

(Con la carpeta en `0777`, logrotate se negaba a rotar: carpetas escribibles por
cualquiera permiten ataques con enlaces simbólicos durante la rotación.)

## 4. Verificar

```bash
sleep 3; sudo tail -1 /var/log/payments/transactions.log   # sigue escribiendo
cat /var/log/payments/transactions.log                      # Permission denied (analista)
curl -s http://127.0.0.1:8600/                              # paymentsd ok
```

## Lecciones

- La frontera es: **el servicio escribe, unos pocos leen, el resto nada**.
- Los logs con datos sensibles son tan valiosos como la base de datos.
- Permisos que no sobreviven a logrotate (o a un reinicio) no están arreglados:
  revisa siempre **quién recrea** el fichero (`create` de logrotate, `LogsDirectory=` de systemd, la app…).
