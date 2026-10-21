# Resolución guiada · Lab 07

:::piensa Antes de tocar nada
Las credenciales de fábrica no son un secreto: están en el manual, en internet y en las listas de cualquier bot. Un dispositivo con `admin/admin` está, en la práctica, **sin contraseña**. Tu objetivo es simple, pero hazlo bien: una contraseña fuerte, generada, no inventada.
:::

## Paso 1 · Localiza y confirma

**Pregúntate:** ¿dónde guarda el panel sus credenciales? ¿Puedo demostrar que las de fábrica funcionan?

**Por qué importa:** confirmar el problema antes de arreglarlo te permite después **demostrar** que está arreglado.

:::pista Cómo comprobarlo
```bash
cat /etc/webadmin/credentials
curl -s "http://127.0.0.1:8080/?u=admin&p=admin"
```
:::

## Paso 2 · ¿Qué es una contraseña fuerte?

**Pregúntate:** ¿qué hace que una contraseña resista a un ataque? Longitud y **aleatoriedad**. Una palabra con números al final no es aleatoria.

**Por qué importa:** si la inventas tú, sigue patrones humanos. Si la genera el sistema, no.

:::pista Cómo generarla
```bash
openssl rand -base64 18
```
18 bytes aleatorios → 24 caracteres. Guárdala en un gestor de contraseñas.
:::

## Paso 3 · Cámbiala sin romper el formato

**Pregúntate:** ¿qué formato tiene el fichero? Si lo rompes, el panel puede dejar de funcionar o volver a valores por defecto.

:::pista Cómo hacerlo
```bash
NEW=$(openssl rand -base64 18)
sudo sed -i "s|^password=.*|password=$NEW|" /etc/webadmin/credentials
cat /etc/webadmin/credentials
```
Uso `|` como separador de `sed` porque base64 puede contener `/`.
:::

## Paso 4 · Demuestra que está arreglado

```bash
curl -s "http://127.0.0.1:8080/?u=admin&p=admin"    # debe fallar
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Inventario**: ¿qué otros equipos (cámaras, routers, impresoras) siguen con credenciales de fábrica?
- **Contraseñas generadas**, nunca inventadas; guardadas en un gestor.
- **Reduce exposición**: un panel de administración no debería ser accesible desde internet.
- Mejor aún: desactivar cuentas por defecto y exigir el cambio en el primer arranque.

## Si te atascas

- `sed` da error con la contraseña: cambia el separador a `|` como en el ejemplo.
- El validador dice "débil": revisa que tiene 12+ caracteres y no es una palabra común.
