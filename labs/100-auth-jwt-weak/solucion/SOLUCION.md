# Solución — JWT mal verificado (vía BLUE)

> Solo el arreglo. La falsificación (RED) la resuelves tú.

## Causa

El JWT trae en su cabecera el campo `alg`. El verificador lo obedece: si el
token dice `"alg":"none"`, no comprueba firma y confía en el `payload`. El
atacante crea un token con `{"alg":"none"}` y `{"role":"admin"}`, deja la
firma vacía, y `/admin` lo acepta.

Es una de las dos clases clásicas de confusión de algoritmo. La otra es
`alg:RS256`→`HS256`: el servidor verifica una firma RS256 con la clave
pública, pero si acepta `HS256` usa esa clave pública como secreto HMAC, que
es conocido.

## Arreglo

El servidor **fija** el algoritmo; nunca lo lee del token:

```python
if header.get("alg") != "HS256":
    return None
expected = b64u(hmac.new(SECRET, (h_b+"."+p_b).encode(), hashlib.sha256).digest()).decode()
return payload if hmac.compare_digest(expected, s_b) else None
```

Con una librería real: `jwt.decode(token, SECRET, algorithms=["HS256"])` — el
parámetro `algorithms` es obligatorio precisamente por esto.

## Más allá de este fallo

- **Secreto fuerte y fuera del código**: un HS256 con secreto corto se
  rompe por fuerza bruta offline. Aquí el secreto es aleatorio y vive en el
  entorno de `app`.
- **Valida `exp`, `iss`, `aud`**: un token sin caducidad vale para siempre.
- **No metas secretos en el payload**: el payload es legible (solo va
  firmado, no cifrado).

## Lecciones

- La confianza va en el secreto, no en un campo que controla el atacante.
- Fija `algorithms` en la verificación. `alg:none` y RS256→HS256 nacen de no
  hacerlo.
- Firmado ≠ cifrado: cualquiera lee el contenido de un JWT.
