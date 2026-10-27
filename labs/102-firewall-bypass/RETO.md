# Saltar (o blindar) un firewall mal configurado

> Red/Blue · estilo máquina HTB fácil/media · dos banderas (user + root)
> El popup al iniciar decide cómo juegas.

El nodo de borde `gateway.lab` (hostname `target`) expone una web pública en el
puerto `80`. Detrás del firewall hay dos servicios internos que **no** deberían
verse desde la red:

- `9001` — servicio de usuario → bandera **user**
- `9002` — consola admin (corre como root) → bandera **root**

El firewall pretende bloquear ambos y dejar solo el `80`. Pero dos reglas mal
puestas abren una vía.

---

## 🔴 Si juegas como RED

No tienes shell en el target. Trabajas desde la **caja atacante** (su terminal
es la que ves) y llegas al target por la red. Localízalo con:

```bash
getent hosts target
```

Objetivo: alcanzar los servicios internos pese al firewall y capturar las dos
banderas. Entrégalas en la web (campos **user** y **root**). No se te da el
método: esa es la prueba.

## 🔵 Si juegas como BLUE

Tienes acceso total al target (shell como `analista`). La pregunta es la
inversa: **¿cómo evitas que se salte el firewall?**

Las reglas están en `/srv/fw/rules.sh`. Edítalas, aplica y comprueba:

```bash
nano /srv/fw/rules.sh
fw-reload          # re-aplica las reglas (sudo acotado)
fw-show            # muestra la cadena INPUT
bash /opt/lab/check.sh
```

El validador simula el recorrido de la cadena `INPUT` para paquetes que vienen
de fuera (interfaz `eth0`, estado `NEW`) y exige:

- la web pública (`:80`) sigue accesible,
- `:9001` bloqueado, incluso con trucos de puerto de origen,
- `:9002` bloqueado por acceso directo.

Pista de criterio (no de exploit): el reenvío legítimo de respuestas ya lo
cubre la regla de estado `ESTABLISHED,RELATED`; cualquier regla que acepte por
*puerto de origen* o un `ACCEPT` de "depuración" delante de un `DROP` sobran.
