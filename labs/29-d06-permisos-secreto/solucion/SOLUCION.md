# Solución — Día 06: Corregir permisos inseguros de un secreto

## 1. Diagnóstico

```bash
ls -la /etc/billing/
# drwxrwxrwx root root  .
# -rw-rw-rw- root root  secret.key
systemctl show billing-api -p User -p Group    # User=billing Group=billing
```

Dos problemas: el fichero es `0666` (todos leen y escriben) y la carpeta es
`0777` (cualquiera podría **sustituir** la clave por otra suya).

## 2. Opción recomendada: root es dueño, el grupo del servicio sólo lee

```bash
sudo chown root:billing /etc/billing/secret.key
sudo chmod 0640 /etc/billing/secret.key
sudo chmod 0755 /etc/billing         # o 0750 root:billing
```

- `root` puede administrarla; el grupo `billing` (el servicio) sólo **lee**;
  el resto, nada.
- El servicio no puede modificar su propia clave: si lo comprometen, no
  puede cambiarla.

Alternativa válida: `chown billing:billing` + `chmod 0400/0600`.

## 3. Verificar

```bash
stat -c '%A %U:%G %n' /etc/billing /etc/billing/secret.key
cat /etc/billing/secret.key                     # Permission denied (como analista)
sudo -u billing cat /etc/billing/secret.key >/dev/null && echo "el servicio la lee"
curl -s http://127.0.0.1:8200/health            # secret loaded
```

## Lecciones

- Mínimo privilegio en ficheros = **quién** necesita **qué** (leer ≠ escribir).
- El permiso de la **carpeta** importa tanto como el del fichero: con `w` en
  la carpeta se puede borrar y reemplazar el fichero aunque no se pueda leer.
- Patrón habitual para secretos de servicio: `root:<grupo-servicio> 0640`.
- Si la clave estuvo expuesta, en un caso real además **se rota**.
