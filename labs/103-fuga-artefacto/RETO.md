# Panel con fuga de artefacto de build (y modo debug)

> Red/Blue · estilo máquina HTB fácil · dos banderas (user + root)
> El popup al iniciar decide cómo juegas.

El nodo `gateway.lab` (hostname `target`) expone un panel web en el puerto
`8080`. Detrás hay dos descuidos de despliegue:

- un **artefacto de build** olvidado en el webroot → bandera **user**
- un **modo depuración** que quedó activado → bandera **root**

---

## 🔴 Si juegas como RED

No tienes shell en el target. Trabajas desde la **caja atacante** (su terminal
es la que ves) y llegas al panel por HTTP. Localiza el objetivo:

```bash
getent hosts target
curl -s http://target:8080/
```

Objetivo: capturar las dos banderas y entregarlas en la web (campos **user** y
**root**). No se te da el método: esa es la prueba.

## 🔵 Si juegas como BLUE

Tienes acceso total al target (shell como `analista`). La pregunta es la
inversa: **¿cómo cierras las dos fugas sin romper lo legítimo?**

La configuración del panel está en `/etc/panel/config.json`. Edítala, aplica y
comprueba:

```bash
cat /etc/panel/config.json
nano /etc/panel/config.json
app-reload          # recarga el panel (sudo acotado)
bash /opt/lab/check.sh
```

El validador hace peticiones HTTP al panel y exige:

- la web pública (`/`) sigue respondiendo 200,
- `/backup/` y el `.bak` ya **no** se descargan,
- `/admin` **sin** token queda denegado (sin modo debug),
- `/admin` **con** el token legítimo sigue funcionando (no mates el endpoint,
  solo cierra la fuga).

Pista de criterio (no de exploit): un backup del código no vive en el webroot,
y el modo depuración no viaja a producción.
