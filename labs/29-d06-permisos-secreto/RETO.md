# Día 06 — Corregir permisos inseguros de un secreto

> 30 días de DevSecOps · Linux · Permisos e identidad de servicios

## Escenario

`billing-api` firma las facturas con la clave `/etc/billing/secret.key`. Un
escaneo de cumplimiento marca que **cualquier usuario del sistema** puede
leerla y modificarla. Hay que cerrarla… sin tumbar la facturación: el
servicio corre como el usuario `billing` y lee la clave en cada petición.

## Objetivos

1. Ningún permiso para "otros" sobre `/etc/billing/secret.key`.
2. Dueño y grupo acotados (`root` o `billing`) y **sin escritura de grupo**.
3. La carpeta `/etc/billing` no debe ser escribible por todos.
4. Un usuario cualquiera (como `analista`) no debe poder leer la clave.
5. `billing-api` debe seguir funcionando:
   `curl http://127.0.0.1:8200/health` → `secret loaded`.
6. No cambies el contenido de la clave.

## Comandos que te pueden servir

```bash
ls -la /etc/billing/ ; stat /etc/billing/secret.key
systemctl cat billing-api          # ¿con qué usuario/grupo corre?
id billing
sudo chown <dueño>:<grupo> <fichero> ; sudo chmod <modo> <fichero>
sudo -u billing cat /etc/billing/secret.key   # prueba como el servicio
curl -s http://127.0.0.1:8200/health
```

> Si haces `chmod 600` con dueño `root`, la clave queda "segura"… y la
> facturación se cae. Piensa **quién necesita leerla**.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
