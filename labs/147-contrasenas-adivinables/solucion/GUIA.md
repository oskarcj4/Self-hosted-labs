# Resolución guiada · Lab 147

:::piensa Tres frentes
**Política** (que nadie pueda poner una contraseña débil), **segundo factor**
(que la contraseña no baste para entrar) y **contención** (las cuentas que ya
tienen una contraseña débil, fuera hasta que se reseteen). La política no
revisa las contraseñas que ya existen: sin bloquear, las débiles siguen ahí.
:::

**El plan:** (1) política de contraseñas, (2) segundo factor en SSH,
(3) bloquear las cuentas débiles y (4) documentar.

## Paso 1 · La política de contraseñas

:::pista Cómo hacerlo
```bash
sudo nano /etc/security/pwquality.conf
```
Deja (sin `#` delante):
```
minlen = 12
minclass = 3
```
- `minlen = 12`: longitud mínima.
- `minclass = 3`: al menos 3 de las 4 clases (minúsculas, mayúsculas, dígitos,
  otros símbolos).

Esa configuración la usa el módulo de PAM `pam_pwquality` cuando alguien
cambia su contraseña. Comprueba que está activo:
```bash
grep -n pam_pwquality /etc/pam.d/common-password
```
**PAM** es la capa de Linux que decide cómo se autentica cada servicio
(`login`, `sshd`, `passwd`…). `common-password` se usa al cambiar contraseñas.

**Qué deberías ver:** una línea `password requisite pam_pwquality.so retry=3`.
`requisite`: si este módulo dice que no, el cambio se rechaza.
:::

## Paso 2 · Segundo factor en SSH

**Pregúntate:** ¿cómo exiges en una misma sesión "llave SSH **y** un código
TOTP"?

:::pista Cómo hacerlo
Primero, que el PAM de `sshd` pida el código:
```bash
echo 'auth required pam_google_authenticator.so nullok' | sudo tee -a /etc/pam.d/sshd
```
`pam_google_authenticator` comprueba códigos TOTP (los de 6 dígitos que da una
app del móvil). `nullok` deja entrar sin código a quien todavía no ha
configurado el suyo, para que pueda hacerlo; en producción se quita después.

Luego, que `sshd` encadene los métodos:
```bash
sudo nano /etc/ssh/sshd_config
```
```
UsePAM yes
KbdInteractiveAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
PasswordAuthentication no
```

| Directiva | Qué hace |
|---|---|
| `UsePAM yes` | `sshd` usa PAM, y por tanto el módulo de TOTP. |
| `KbdInteractiveAuthentication yes` | Permite el modo "pregunta-respuesta", que es como PAM pide el código. |
| `AuthenticationMethods publickey,keyboard-interactive` | Con coma: hay que pasar **los dos**, en ese orden. |
| `PasswordAuthentication no` | La contraseña sola ya no sirve. |

```bash
sudo sshd -t
```
`sshd -t` comprueba la configuración sin aplicarla. **Qué deberías ver:**
nada (sin errores).
:::

## Paso 3 · Contén lo ya comprometido

:::pista Cómo hacerlo
```bash
sudo passwd -l elliot mobley romero
sudo passwd -S elliot
```
`passwd -l` bloquea la contraseña; `passwd -S` muestra el estado.

**Qué deberías ver:** `elliot L …` (*locked*).
:::

## Paso 4 · Documenta

```bash
echo 'cuentas_debiles=elliot,mobley,romero' > ~/hallazgos.txt
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- La política previene lo nuevo; el bloqueo neutraliza lo viejo. Son cosas
  distintas.
- Un segundo factor sólo tras la contraseña sigue siendo frágil: lo robusto es
  llave pública + TOTP, sin contraseña.
- Comprueba las contraseñas contra listas de filtradas al fijarlas (por
  ejemplo, `pam_pwquality` con `dictcheck` o servicios tipo *Have I Been
  Pwned*).

## Si te atascas

- **`sshd -t` da error con `AuthenticationMethods`:** los métodos van
  separados por coma, sin espacios, y la directiva en la parte global del
  fichero (antes de cualquier `Match`).
- **`passwd -S` no muestra `L`:** usaste `chage` o `passwd -e` (caducar no es
  bloquear).
- **Las líneas no hacen efecto:** puede haber otra igual más arriba en
  `sshd_config`; en sshd gana el **primer** valor que lee.
