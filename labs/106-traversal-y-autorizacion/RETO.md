# Visor de documentos con path traversal y bypass de autorización

> HTB-style · red/blue · Web · OWASP A01 (Broken Access Control)

`docs.lab` sirve documentos. Dos cosas mal:

1. `/download?file=...` no valida la ruta: con `../` se sale de `/srv/docs` y lee
   otros ficheros del servidor (**path traversal**).
2. `/admin` se fía de la cabecera `X-Admin` que manda el **cliente**: cualquiera
   se declara administrador (**broken access control**).

---

## 🔴 Modo RED (sin acceso al servidor)

No tienes shell. Solo su HTTP (8080). Objetivo:

- **Bandera USER**: lee el fichero privado que está fuera de `/srv/docs`.
- **Bandera ROOT**: entra en `/admin`.

Envía cada bandera por la web del lab.

> En modo red el target no expone ttyd: solo el HTTP del puerto publicado.

---

## 🔵 Modo BLUE (acceso total, analista)

Shell como `analista`. **Cierra las dos cosas sin romper la descarga legítima**:

- `/download` solo debe servir ficheros dentro de `/srv/docs`.
- `/admin` no debe fiarse de la cabecera `X-Admin`.
- La descarga de `readme.txt` debe seguir funcionando.

Config editable: `/etc/panel/config.json` (`sanitize_path`, `trust_admin_header`).
Aplica con `app-reload`.

```bash
cat /etc/panel/config.json
cat /srv/app/app.py          # mira cómo usa cada clave
nano /etc/panel/config.json
app-reload
bash /opt/lab/check.sh
```
