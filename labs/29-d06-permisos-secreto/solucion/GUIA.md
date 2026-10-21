# Resolución guiada · Día 06

:::piensa Antes de tocar nada
"Asegurar" un fichero no es quitarle todos los permisos: es dárselos **sólo a quien los necesita**. La pregunta no es "¿cómo lo cierro?" sino **"¿quién necesita leerlo, quién necesita escribirlo y quién nada?"**. Si respondes eso, el `chmod` sale solo.
:::

## Paso 1 · ¿Cómo está ahora?

**Pregúntate:** ¿qué permisos tienen el fichero **y la carpeta**? ¿Por qué importa la carpeta?

**Por qué importa:** con escritura en la carpeta, cualquiera puede **borrar y sustituir** el fichero por otro suyo, aunque no pueda leer el original.

:::pista Cómo comprobarlo
```bash
ls -la /etc/billing/
stat -c '%A %U:%G %n' /etc/billing /etc/billing/secret.key
```
:::

## Paso 2 · ¿Quién lo necesita?

**Pregúntate:** ¿con qué usuario y grupo corre el servicio que lee la clave?

:::pista Cómo comprobarlo
```bash
systemctl show billing-api -p User -p Group
id billing
```
:::

## Paso 3 · Diseña los permisos

Responde en una tabla antes de escribir comandos:

| Quién | Necesita | Permiso |
|---|---|---|
| root | administrarla | dueño |
| servicio (`billing`) | leerla | grupo, sólo lectura |
| resto | nada | ninguno |

:::pista Cómo hacerlo
```bash
sudo chown root:billing /etc/billing/secret.key
sudo chmod 0640 /etc/billing/secret.key
sudo chmod 0755 /etc/billing
```
`0640` = dueño lee/escribe, grupo lee, otros nada. Ventaja: el servicio **no puede modificar su propia clave**, aunque lo comprometan.
:::

## Paso 4 · Prueba como cada actor

**Pregúntate:** ¿cómo demuestro que funciona para el servicio y falla para un usuario normal?

```bash
cat /etc/billing/secret.key                              # como analista: denegado
sudo -u billing cat /etc/billing/secret.key >/dev/null && echo "servicio OK"
curl -s http://127.0.0.1:8200/health
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Diseña desde los actores**: quién lee, quién escribe, quién nada.
- **Revisa la cadena de carpetas**, no sólo el fichero (`namei -l <ruta>`).
- **Prueba con el usuario real del servicio** (`sudo -u`), no como root.
- Si estuvo expuesta, en un caso real se **rota**: no sabes quién la leyó.

## Si te atascas

- El servicio dice que no puede leerla: el grupo del fichero no coincide con el del servicio, o falta `r` para el grupo.
