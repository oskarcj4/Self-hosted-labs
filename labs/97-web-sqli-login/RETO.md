# Portal con SQLi en el login

> Web · OWASP A03 Injection · doble vía (red / blue) · basado en el arquetipo
> de las máquinas HTB fáciles de "login bypass por SQLi"

## Escenario

El portal interno de SogetiCorp escucha en `http://127.0.0.1:8080`. El login
construye la consulta SQL **concatenando** el usuario y la clave. El código
corre como el usuario `app`; tú eres `analista` y **no tienes sudo**: la flag
(`TCLAB{...}`) solo vive en la base de datos `app.db`, que no puedes leer a
mano. Tienes que pasar por la aplicación.

Usuarios legítimos de prueba (para no romperlos al arreglar):

| usuario | clave          | rol  |
|---------|----------------|------|
| ana     | Primavera2024  | user |
| luis    | Verano.2024    | user |

El usuario `admin` existe, su clave es aleatoria y su fila guarda la flag.

## Dos formas de resolverlo

Resuelves el lab por **cualquiera** de las dos (la que valide, lo cierra):

### 🔴 RED — captura la flag
Explota la inyección en el login hasta sacar la fila de `admin` (o extraer su
`flag`). Cuando la tengas, pégala en `~/flag.txt`:

```bash
echo 'TCLAB{...}' > ~/flag.txt
bash /opt/lab/check.sh red
```

### 🔵 BLUE — arregla la vulnerabilidad
Edita `/srv/app/app.py` para que la consulta use **parámetros** (no strings),
recarga y comprueba que:
- `ana` / `Primavera2024` sigue entrando,
- una inyección de bypass ya **no** autentica ni filtra la flag.

```bash
nano /srv/app/app.py
app-reload          # reinicia la app (espera ~2s)
app-logs            # últimas líneas del log si algo peta
bash /opt/lab/check.sh blue
```

## Pistas de reconocimiento

```bash
curl -s http://127.0.0.1:8080/ | head
curl -s --data-urlencode "user=ana" --data-urlencode "password=Primavera2024" \
     http://127.0.0.1:8080/login
# ¿qué pasa si el usuario lleva una comilla?
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh      # vale red O blue; si pasa, destruye el lab
```
