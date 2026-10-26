# Proxy de estado vulnerable a SSRF

> HTB-style · red/blue · Web · OWASP A10 (SSRF)

`status-proxy.lab` ofrece un comprobador de servicios: `/fetch?url=...` trae una
URL **desde el servidor**. El problema: no restringe el destino, así que se puede
apuntar al **servicio interno de metadatos** que solo escucha en `127.0.0.1:8081`
y que nunca debería verse desde fuera.

---

## 🔴 Modo RED (sin acceso al servidor)

No tienes shell en el objetivo. Solo su IP/puerto público (8080). Objetivo:

- **Bandera USER**: haz que el proxy te traiga `http://127.0.0.1:8081/user`.
- **Bandera ROOT**: lo mismo con `http://127.0.0.1:8081/root`.

El `127.0.0.1` es desde el punto de vista del **target**, no el tuyo.

Envía cada bandera por la web del lab.

> En modo red el target no expone ttyd: solo el HTTP del puerto publicado.

---

## 🔵 Modo BLUE (acceso total, analista)

Shell como `analista`. **Cierra el SSRF sin romper el health legítimo**:

- El proxy debe dejar de alcanzar destinos internos (127.0.0.1, el metadata).
- El health legítimo `http://status.lab:8080/health` debe seguir funcionando.

Config editable: `/etc/panel/config.json` (`restrict_targets`, `allowlist`).
Aplica con `app-reload`.

```bash
cat /etc/panel/config.json
cat /srv/app/app.py          # mira cómo decide /fetch si permite un destino
nano /etc/panel/config.json
app-reload
bash /opt/lab/check.sh
```
