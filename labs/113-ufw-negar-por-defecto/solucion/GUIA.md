# Resolución guiada · Lab 113

:::piensa Antes de tocar nada
"Negar por defecto" significa que la lista de lo permitido es corta y explícita.
Y en un servidor remoto, la primera regla que escribes es la que te deja seguir
dentro: SSH.
:::

## Paso 1 · ¿Qué está expuesto?

**Pregúntate:** ¿qué puertos escuchan en todas las interfaces y cuáles deberían ser sólo internos?

:::pista Cómo comprobarlo
```bash
sudo ss -tlnp
sudo ufw status verbose
```
`0.0.0.0:` o `*:` significa "accesible desde fuera".
:::

## Paso 2 · ¿Qué ve el atacante?

**Pregúntate:** lo que importa es lo que se ve desde fuera, no desde localhost. ¿Dónde está el informe del escáner externo?

:::pista Dónde mirar
`cat /srv/escaneo/ultimo.txt` (ticket en `~/ticket/AUDIT-113.txt`). Se actualiza cada 15 s.
:::

## Paso 3 · Política y excepciones

**Pregúntate:** ¿en qué orden pones las reglas para no cortarte el acceso?

:::pista Cómo hacerlo
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status numbered
```
:::

## Paso 4 · Confirma desde fuera

**Pregúntate:** ¿cómo sabes que funciona? Espera a la siguiente pasada del escáner.

:::pista Cómo comprobarlo
```bash
sleep 20; cat /srv/escaneo/ultimo.txt
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **SSH primero, `enable` después.** En un servidor real, ten una consola fuera de banda.
- **Servicios internos escuchando en 127.0.0.1** además del firewall: dos capas.
- **Comprueba desde fuera.** `ufw status` dice lo que configuraste, no lo que se ve.

## Si te atascas

- Sigue saliendo un puerto interno: mira `ufw status numbered` y borra un `allow` sobrante con `ufw delete N`.
- `ufw enable` pide confirmación: responde `y` o usa `--force`.
