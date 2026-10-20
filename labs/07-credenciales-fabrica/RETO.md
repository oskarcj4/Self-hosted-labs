# Lab 07 — Credenciales de fábrica (la lección de Mirai)

## Escenario

La botnet **Mirai** tumbó medio internet en 2016 entrando a dispositivos con
usuario y contraseña **de fábrica** (`admin/admin`, `root/root`…). En
`iot-gw-07` corre un panel de administración que nadie configuró: sigue con las
credenciales por defecto. Tu trabajo es endurecerlo antes de que alguien más lo
encuentre.

## Objetivos

1. **Localiza el archivo de credenciales** del panel y confirma que usa valores
   de fábrica.
2. **Cámbialas por una contraseña fuerte**: mínimo **12 caracteres** y que no sea
   una contraseña común (`admin`, `password`, `123456`, `root`, `default`…).
3. (El usuario puede seguir siendo `admin`; lo que no puede es la contraseña débil.)

## Comandos que te pueden servir

```bash
cat /etc/webadmin/credentials          # formato: username=... / password=...
# genera una contraseña fuerte:
openssl rand -base64 18 2>/dev/null || head -c 18 /dev/urandom | base64
# edítala:
sudo nano /etc/webadmin/credentials
```

> Regla de oro: ningún dispositivo debe salir a producción con credenciales por
> defecto. Y la contraseña va en un gestor, no en un post-it.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
