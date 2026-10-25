# API con JWT mal verificado (alg:none)

> Auth / tokens · OWASP A07 · doble vía (red / blue) · arquetipo HTB
> fácil/media "JWT que confía en el header del propio token"

## Escenario

La API escucha en `http://127.0.0.1:8080`:

- `POST /login` (user, password) → devuelve un JWT con tu rol.
- `GET /me` (Bearer token) → quién eres.
- `GET /admin` (Bearer token) → panel admin con la flag; solo rol `admin`.

El verificador lee el campo `alg` del propio token para decidir cómo
comprobar la firma. El secreto de firma solo lo conoce el proceso `app`
(`/srv/app/.env`, que no puedes leer). No hay ningún usuario `admin` con el
que loguearte: el rol de `ana` y `luis` es `user`.

Usuarios: `ana`/`Primavera2024`, `luis`/`Verano.2024`. Eres `analista`, sin sudo.

## Dos formas de resolverlo

### 🔴 RED — captura la flag
Consigue que `/admin` te acepte con rol `admin` y lee la flag:

```bash
echo 'TCLAB{...}' > ~/flag.txt
bash /opt/lab/check.sh red
```

### 🔵 BLUE — arregla la vulnerabilidad
Edita `/srv/app/app.py` para que la verificación **no** dependa del `alg` del
token. El login de `ana` y `/me` deben seguir funcionando; un token forjado
no debe entrar en `/admin`.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```

## Reconocimiento

```bash
T=$(curl -s --data-urlencode user=ana --data-urlencode password=Primavera2024 \
      http://127.0.0.1:8080/login | sed -n 's/^token=//p')
curl -s -H "Authorization: Bearer $T" http://127.0.0.1:8080/me
# mira las 3 partes del token (base64url). ¿qué dice la cabecera "alg"?
echo "$T" | cut -d. -f1 | base64 -d 2>/dev/null
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
