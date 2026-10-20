# 13 · Secretos y credenciales

> Contraseñas, tokens y llaves privadas: qué hace que una credencial sea débil, cómo generar una fuerte, en qué sitios se filtran sin que nadie lo note y qué permisos necesita un fichero que guarda un secreto.

## 1. Qué cuenta como secreto

Cualquier dato que, en manos de otro, le deja actuar como tú o como un servicio:

- Contraseñas de cuentas, de paneles, de bases de datos.
- Tokens de API y de acceso a la nube.
- Llaves privadas: SSH, TLS, WireGuard (módulo [12](#curso/12)).
- Cadenas de conexión que incluyen usuario y contraseña (`postgres://usuario:clave@host/db`).

La pregunta que guía todo el módulo: **¿quién más puede leer esto?**

## 2. Credenciales de fábrica

Muchos dispositivos y aplicaciones salen con un usuario y contraseña por defecto (`admin/admin`, `root/root`, `admin/password`). Esos valores están publicados en manuales y en listas que cualquiera puede descargar. Botnets enteras se construyeron probando sólo esas combinaciones contra millones de dispositivos.

Una contraseña de fábrica no es "débil": es **pública**. Cambiarla es lo primero que se hace al poner algo en marcha.

### Dónde suelen vivir

- Un fichero de configuración de la aplicación (`/etc/<app>/`, `/opt/<app>/`), a menudo con formato `clave=valor`.
- Una base de datos local (SQLite) de la aplicación.
- Variables de entorno del servicio (sección 4).

Para encontrar el fichero de configuración de algo que no conoces: mira el servicio (`systemctl cat`, módulo [08](#curso/08)), la línea de comandos del proceso (`/proc/PID/cmdline`, módulo [06](#curso/06)) y la documentación del paquete (`dpkg -L paquete`).

## 3. Qué hace fuerte a una contraseña

La fuerza depende de cuántas combinaciones tendría que probar alguien, y eso depende de **longitud** y de **aleatoriedad**, no de "parecer complicada":

| Contraseña | Problema |
|---|---|
| `admin`, `123456`, `password` | Están al principio de cualquier diccionario |
| `Admin2026!` | Palabra + año + símbolo: patrón que los diccionarios ya contemplan |
| `P@ssw0rd` | Sustituciones obvias, también contempladas |
| 20 caracteres aleatorios | Inabordable por fuerza bruta |

Las contraseñas de servicios (las que lee un programa, no una persona) no necesitan ser memorizables: que las genere la máquina.

```bash
openssl rand -base64 24          # 24 bytes aleatorios en base64 (32 caracteres)
openssl rand -hex 16             # 32 caracteres hexadecimales
head -c 24 /dev/urandom | base64 # sin openssl
```

`/dev/urandom` es la fuente de aleatoriedad del kernel, apta para criptografía. `$RANDOM` de bash **no** lo es.

> Al cambiar una credencial en un fichero, comprueba después que el formato sigue siendo el que espera la aplicación: sin espacios sobrantes alrededor del `=`, sin comillas si no las usaba, y sin un salto de línea de Windows (`\r`) si editaste desde otro sistema. Y si la aplicación lee el fichero sólo al arrancar, hay que reiniciarla.

## 4. Por dónde se filtran los secretos

Un secreto bien elegido se pierde igual si está en un sitio que otros pueden leer.

| Sitio | Por qué filtra | Cómo comprobarlo |
|---|---|---|
| Ficheros con permisos amplios | `644` deja leer a cualquier usuario de la máquina | `ls -l`, `stat -c '%a %U:%G'` |
| Copias de seguridad | `config.bak`, `.old`, `~` heredan otros permisos o quedan en carpetas públicas | `ls -la` en la carpeta de la app y en el web root |
| Línea de comandos | `programa --password=X` es visible para todos en `ps` | `ps auxww` |
| Historial de shell | Un comando con la contraseña queda en `.bash_history` | `grep` en el historial |
| Variables de entorno | Las ve root y el propio usuario en `/proc/PID/environ`; se heredan a procesos hijos y acaban en logs de errores | `sudo tr '\0' '\n' < /proc/PID/environ` |
| Logs | Una app en modo depuración puede registrar cabeceras o parámetros | `grep -i` en sus logs |
| Repositorios git | Un secreto borrado en el último commit sigue en el historial | `git log -p` |
| Código fuente | Credenciales escritas en el script | `grep -rniE 'pass\|secret\|token\|key'` sobre el código |

Con esta tabla puedes revisar tu propio servidor de forma ordenada. Cuando encuentres un secreto expuesto, el arreglo tiene **dos** partes: quitar la exposición y **rotar** el secreto (cambiarlo), porque no sabes si alguien ya lo leyó.

## 5. Permisos para un fichero de secretos

El objetivo es que sólo lo lea quien lo necesita (módulo [04](#curso/04)):

| Situación | Dueño:grupo | Permisos |
|---|---|---|
| Lo lee un servicio que corre como root | `root:root` | `600` |
| Lo lee un servicio que corre como `app` | `app:app` o `root:app` | `600` o `640` |
| Llave privada TLS o SSH | El usuario que la usa | `600` |
| Carpeta que contiene secretos | Igual que los ficheros | `700` o `750` |

Comprueba también la **ruta completa**: un fichero `600` dentro de una carpeta que otro usuario puede escribir se puede sustituir (`namei -l /ruta/al/fichero`).

Y prueba como el usuario que **no** debería poder leerlo:

```bash
sudo -u nobody cat /ruta/secreto      # debería fallar con Permission denied
sudo -u app cat /ruta/secreto         # el servicio sí debería poder
```

## 6. Ejercicios

1. ¿Por qué `admin/admin` es peor que una contraseña corta pero inventada?
2. Un servicio se lanza con `--db-password=...` en su línea de comandos. ¿Quién puede verla y cómo lo arreglarías?
3. Un fichero de credenciales tiene `-rw-r--r-- root root`. ¿Qué cambia si lo dejas en `600`? ¿Y si el servicio corre como `app`?
4. Encuentras una contraseña en `.bash_history`. Además de borrarla de ahí, ¿qué más haces?

:::solucion Ver respuestas
1. Porque es pública: está en todas las listas de credenciales por defecto, se prueba la primera.
2. Cualquier usuario de la máquina, con `ps`. Pasarla por un fichero con permisos `600` que el servicio lea, o por el mecanismo de credenciales del gestor de servicios.
3. Con `600` sólo root puede leerlo. Si el servicio corre como `app`, dejaría de poder leerlo: hay que dárselo a `app` (dueño) o usar `640` con grupo `app`.
4. Cambiarla (rotarla), porque pudo leerse antes de que la borraras, y revisar dónde más se usaba esa contraseña.
:::

## Chuleta

```bash
openssl rand -base64 24; head -c 24 /dev/urandom | base64
ls -l f; stat -c '%a %U:%G %n' f; namei -l /ruta
chmod 600 f; chown app:app f; chmod 640 f && chgrp app f
sudo -u nobody cat f    # debe fallar
ps auxww; sudo tr '\0' '\n' < /proc/PID/environ
```
