# Panel con credenciales por defecto y errores verbosos

> HTB-style · red/blue · Web · OWASP A05/A07

`gateway.lab` expone un panel de borde. Dos cosas mal:

1. El panel admin (`/panel`) acepta una **contraseña por defecto**.
2. El endpoint `/debug` devuelve el **traceback completo** cuando algo falla, y
   ese traceback arrastra contexto sensible del proceso.

---

## 🔴 Modo RED (sin acceso al servidor)

No tienes shell en el objetivo. Solo su IP/puerto público. Objetivo:

- **Bandera USER**: entra en el panel admin.
- **Bandera ROOT**: haz que el servicio hable de más por sus errores.

Envía cada bandera por la web del lab cuando la tengas.

> El panel y el objetivo no exponen ttyd en modo red: solo HTTP en el puerto
> publicado.

---

## 🔵 Modo BLUE (acceso total, analista)

Tienes shell como `analista`. **Cierra las dos fugas sin romper el panel**:

- Cambia la contraseña del panel por una fuerte (12+ caracteres aleatorios).
- Calla los errores verbosos para que `/debug` no filtre nada.
- El panel debe seguir funcionando con la contraseña nueva.

Config editable: `/etc/panel/config.json`. Aplica cambios con `app-reload`.

```bash
cat /etc/panel/config.json
nano /etc/panel/config.json      # panel_pass + verbose_errors
app-reload
bash /opt/lab/check.sh
```

Pista: `/srv/app/app.py` es legible; mira cómo usa cada clave de la config.
