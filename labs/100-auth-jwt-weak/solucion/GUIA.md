# Resolución guiada · Lab 100 (vía BLUE)

:::piensa ¿Quién decide cómo se comprueba un token?
Un JWT trae dentro una cabecera que dice con qué algoritmo se firmó (`alg`).
Pero el token lo puede fabricar cualquiera. Si el servidor deja que **el
token** le diga cómo verificarlo, el atacante elegirá la opción más cómoda
para él. El algoritmo es una decisión del servidor, no un dato que se lee del
token.
:::

Esta guía resuelve la vía **BLUE** (arreglar). La captura (RED) es tuya: los
pasos 1 y 2 te dan todo lo que necesitas entender.

**El plan:** (1) conseguir un token y ver qué lleva dentro, (2) encontrar el
fallo en el verificador, (3) fijar el algoritmo en el servidor y (4) comprobar.

## Paso 1 · ¿Qué es un JWT por dentro?

**Objetivo:** ver que un JWT no es una caja negra: es texto legible con una
firma al final.

:::pista Cómo hacerlo
Pide un token como `ana` y guárdalo en una variable:
```bash
T=$(curl -s --data-urlencode user=ana --data-urlencode password=Primavera2024 \
      http://127.0.0.1:8080/login | sed -n 's/^token=//p')
echo "$T"
```
- La API responde `token=eyJ…`. `sed -n 's/^token=//p'` quita el `token=`
  del principio e imprime sólo esa línea (`-n` = no imprimas nada salvo lo que
  marque `p`).
- `T=$(…)` guarda el resultado en la variable `T` para no copiarlo a mano.

**Qué deberías ver:** tres bloques separados por puntos:
`cabecera.payload.firma`. Los dos primeros son JSON codificado en
**base64url**, una variante de base64 que cambia `+/` por `-_` y quita el
relleno `=` del final. Por eso `base64 -d` a secas a veces falla con
`invalid input`. Esta función lo decodifica bien:
```bash
b64url(){ python3 -c 'import sys,base64; s=sys.argv[1]; print(base64.urlsafe_b64decode(s+"="*(-len(s)%4)).decode())' "$1"; }
b64url "$(echo "$T" | cut -d. -f1)"     # cabecera
b64url "$(echo "$T" | cut -d. -f2)"     # payload
```
- `cut -d. -f1` parte el token por los puntos y se queda con el trozo 1.
- `"="*(-len(s)%4)` añade los `=` que faltan hasta que la longitud sea
  múltiplo de 4, que es lo que exige el decodificador.

**Qué deberías ver:** `{"alg": "HS256", "typ": "JWT"}` y
`{"user": "ana", "role": "user"}`. El rol va **en el propio token**: lo único
que impide cambiarlo es la firma.
:::

## Paso 2 · ¿Dónde se verifica la firma?

**Objetivo:** encontrar qué hace el servidor con ese campo `alg`.

**Pregúntate:** ¿hay algún valor de `alg` con el que el servidor no compruebe
la firma?

:::pista Cómo comprobarlo
```bash
grep -n -A14 'def verify' /srv/app/app.py
```
```python
alg = header.get("alg")
if alg == "none":
    return payload
```
`alg: none` existe en el estándar JWT para tokens **sin firma** (pensado para
casos donde la integridad ya la garantiza otra capa). Este verificador lo
acepta: si la cabecera dice `none`, devuelve el payload sin mirar la firma.
Quien fabrique un token con `"alg":"none"` y el rol que quiera, entra. Esa es
la idea de la vía RED.
:::

## Paso 3 · El servidor fija el algoritmo

**Objetivo:** que sólo valga un token firmado con HS256 y con el secreto del
servidor, diga lo que diga su cabecera.

:::pista Cómo hacerlo
```bash
nano /srv/app/app.py
```
En `verify`, sustituye desde `alg = header.get("alg")` hasta el `return None`
final por:
```python
    if header.get("alg") != "HS256":
        return None
    expected = b64u(hmac.new(SECRET, (h_b + "." + p_b).encode(),
                             hashlib.sha256).digest()).decode()
    if hmac.compare_digest(expected, s_b):
        return payload
    return None
```

| Pieza | Qué hace |
|---|---|
| `header.get("alg") != "HS256"` | Rechaza cualquier token que no diga exactamente el algoritmo que el servidor usa. `none` queda fuera. |
| `hmac.new(SECRET, cabecera.payload, sha256)` | Recalcula la firma con el secreto del servidor. Si alguien cambia un solo carácter del payload (por ejemplo, `role`), la firma ya no coincide. |
| `hmac.compare_digest(a, b)` | Compara las dos firmas en **tiempo constante**. Con `==`, la comparación se para en el primer carácter distinto, y midiendo cuánto tarda un atacante puede ir adivinando la firma carácter a carácter. |

```bash
app-reload        # reinicia la app (~2 s)
app-logs          # si algo falla, aquí verás el error de Python
```
:::

## Paso 4 · Comprueba

```bash
curl -s -H "Authorization: Bearer $T" http://127.0.0.1:8080/me
bash /opt/lab/check.sh blue
```
`-H "Authorization: Bearer $T"` añade la cabecera con la que la API espera
recibir el token.

**Qué deberías ver:** `user=ana role=user` (lo legítimo sigue funcionando) y
el check confirmando que un token `alg:none` y uno con la firma manipulada ya
no entran.

## Cómo actuar en una situación así

- Con una librería real, el parámetro de algoritmos es **obligatorio** por
  esto mismo: `jwt.decode(token, SECRET, algorithms=["HS256"])`.
- La otra confusión clásica: un servidor que firma con **RS256** (clave
  privada / pública) y acepta también **HS256**. El atacante firma con HS256
  usando la clave **pública**, que es pública, y el servidor lo da por bueno.
- Valida también `exp` (caducidad), `iss` y `aud`. Un token sin caducidad vale
  para siempre.
- **Firmado no es cifrado:** cualquiera lee el payload, como has hecho en el
  paso 1. No metas secretos ahí.

## Si te atascas

- **`/me` responde `token invalido` también con el token de ana:** revisa la
  indentación del bloque nuevo (4 espacios dentro de la función) y que el
  `return payload` esté dentro del `if compare_digest`.
- **La variable `T` está vacía:** el login falló o la app no estaba en marcha.
  Repite el `curl` del paso 1 sin el `$(…)` para ver qué responde.
