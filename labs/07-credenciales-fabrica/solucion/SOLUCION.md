# Solución — Lab 07

## 1. Confirmar las credenciales de fábrica

```bash
cat /etc/webadmin/credentials
# username=admin / password=admin
curl -s "http://127.0.0.1:8080/?u=admin&p=admin"   # -> LOGIN OK
```

## 2. Cambiar a una contraseña fuerte

```bash
NEW=$(openssl rand -base64 18)      # p.ej. 24 caracteres aleatorios
echo "$NEW"                         # guárdala en tu gestor
sudo sed -i "s/^password=.*/password=$NEW/" /etc/webadmin/credentials
cat /etc/webadmin/credentials
```

Comprueba que las de fábrica ya no sirven:

```bash
curl -s "http://127.0.0.1:8080/?u=admin&p=admin"   # -> LOGIN FAIL
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- Las credenciales por defecto son la vía de entrada #1 a dispositivos IoT. Mirai
  escaneaba internet probando ~60 pares usuario/contraseña de fábrica.
- Fuerza mínima: longitud (12+), aleatoriedad, y nunca reutilizar.
- Mejor aún: desactivar cuentas por defecto, exigir cambio en el primer arranque,
  y no exponer paneles de administración a internet.
