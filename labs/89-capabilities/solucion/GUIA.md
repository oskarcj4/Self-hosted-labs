# Resolución guiada · Lab 89

:::piensa ¿Qué necesita de verdad un servidor HTTP?
Linux no trata a root como un todo: divide sus poderes en unas 40
**capabilities** (`CAP_NET_ADMIN` para tocar la red, `CAP_SYS_ADMIN` para
montar sistemas de ficheros, `CAP_CHOWN`…). Un contenedor recibe por defecto
un puñado de ellas. `cap_add: ALL` se las da todas: es casi `privileged`. La
pregunta no es "¿qué le quito?", sino "¿qué necesita?". Para un Python que
escucha en el 8080, la respuesta es: ninguna.
:::

**El plan:** (1) ver qué privilegios tiene hoy, (2) comprobar que la app no
los usa, (3) dejar `compose.yaml` en cero y (4) verificar que sigue sirviendo.

## Paso 1 · ¿Qué privilegios tiene ahora?

**Objetivo:** ver lo que Docker le ha dado **de verdad** al contenedor, no lo
que crees que pone el fichero.

**Pregúntate:** `compose.yaml` es la intención. ¿Dónde mira Docker la
configuración con la que arrancó el contenedor que está corriendo?

:::pista Cómo hacerlo
```bash
cd ~/caps && cat compose.yaml
docker inspect caps-api-1 --format 'add={{.HostConfig.CapAdd}} drop={{.HostConfig.CapDrop}} sec={{.HostConfig.SecurityOpt}}'
```
`docker inspect` devuelve un JSON enorme con toda la configuración del
contenedor. `--format` usa una plantilla de Go para sacar sólo lo que pides:
`{{.HostConfig.CapAdd}}` es "el campo `CapAdd` dentro de `HostConfig`".

**Qué deberías ver:** `add=[ALL CAP_SYS_ADMIN] drop=[] sec=[]` (Docker
añade el prefijo `CAP_` al guardarlas). Capacidades añadidas: todas.
Quitadas: ninguna. Opciones de seguridad: ninguna.
:::

## Paso 2 · ¿La app usa alguna?

**Objetivo:** confirmar que quitarlas no rompe nada antes de quitarlas.

**Pregúntate:** ¿qué hace el código? ¿Monta algo, toca la red del host,
cambia la hora, abre un puerto por debajo del 1024?

:::pista Cómo comprobarlo
```bash
cat ~/caps/api/app.py
```
Sólo crea un `HTTPServer` en el puerto **8080**. Abrir un puerto por debajo
de 1024 sí necesitaría `CAP_NET_BIND_SERVICE`; por encima, no hace falta
ninguna. No hay `mount`, ni `sysctl`, ni `iptables`. Ninguna capability.
:::

## Paso 3 · Deja el servicio en mínimo privilegio

**Objetivo:** que `compose.yaml` empiece en cero privilegios y lo deje escrito.

**Pregúntate:** ¿basta con borrar `cap_add`?

:::pista Cómo hacerlo
No basta: sin `cap_add` el contenedor sigue con el **conjunto por defecto**
de Docker (unas 14 capabilities, como `CHOWN` o `SETUID`). Hay que quitarlas
todas explícitamente. Edita `compose.yaml`: borra el bloque `cap_add` entero
(y su comentario) y añade dentro del servicio `api`:
```yaml
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

| Opción | Qué hace |
|---|---|
| `cap_drop: [ALL]` | Quita todas las capabilities, incluidas las que Docker da por defecto. |
| `no-new-privileges:true` | Prohíbe que un proceso **gane** privilegios después de arrancar. Sin esto, un binario con bit SUID dentro de la imagen (como `su` o `ping` en algunas) podría volver a subirlos. |

Aplica el cambio:
```bash
docker compose up -d
```
`up -d` compara la configuración nueva con la del contenedor que corre y, si
cambia, lo **recrea**. No hace falta pararlo antes.
:::

## Paso 4 · Comprueba

```bash
docker inspect caps-api-1 --format 'add={{.HostConfig.CapAdd}} drop={{.HostConfig.CapDrop}} sec={{.HostConfig.SecurityOpt}}'
curl -s localhost:8080
bash /opt/lab/check.sh
```
**Qué deberías ver:** `add=[] drop=[ALL] sec=[no-new-privileges:true]` y
`api ok`. Tienes la app funcionando con cero privilegios.

## Cómo actuar en una situación así

- **Empieza en cero** (`cap_drop: ALL`) y añade una sola capability cuando
  un error concreto la pida (por ejemplo `NET_BIND_SERVICE` para el puerto 80).
  Nunca sustituyas `ALL` por una lista igual de ancha "por si acaso".
- `cap_add: ALL` y `privileged: true` son prácticamente lo mismo: revísalos en
  cada code review.
- Si un contenedor necesita root dentro, eso tampoco implica capabilities:
  root sin capabilities puede muy poco fuera de sus propios ficheros.

## Si te atascas

- **El check dice que `compose.yaml` aún tiene `cap_add` o `SYS_ADMIN`:**
  el validador busca esas palabras en todo el fichero, también en comentarios.
  Borra el bloque y su comentario enteros.
- **`docker inspect` sigue mostrando lo viejo:** no ejecutaste `docker compose
  up -d` en `~/caps`, o lo ejecutaste en otra carpeta.
- **`yaml: line N: did not find expected key`:** la indentación. `cap_drop` y
  `security_opt` van al mismo nivel que `ports` (4 espacios).
