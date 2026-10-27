# Saltar (o blindar) un firewall hasta el SSH interno

> Red/Blue · estilo máquina HTB fácil/media · dos banderas (user + root)
> El popup al iniciar decide cómo juegas.

El nodo de borde `gateway.lab` (hostname `target`) expone una web pública en el
puerto `80`. Detrás del firewall hay dos servicios que **no** deberían verse
desde la red:

- `22` — SSH de mantenimiento → camino a la bandera **user**
- `8080` — consola admin interna (corre como root) → bandera **root**

El firewall pretende dejar solo el `80` y bloquear el resto. Pero dos errores
en sus reglas dejan una vía: se puede llegar al SSH interno desde fuera, y el
SSH es la puerta a la red interna del nodo.

---

## 🔴 Si juegas como RED

No tienes shell en el target. Trabajas desde la **caja atacante** (su terminal
es la que ves) y llegas al target por la red. Localízalo con:

```bash
getent hosts target
```

Objetivo: alcanzar el SSH interno pese al firewall, entrar, y desde dentro
llegar a la consola admin para capturar las dos banderas. Entrégalas en la web
(campos **user** y **root**). No se te da el método: esa es la prueba.

## 🔵 Si juegas como BLUE

Tienes acceso total al target (shell como `analista`). La pregunta es la
inversa: **¿por qué se puede saltar el firewall y cómo lo cierras?**

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
- `:22` (SSH) bloqueado desde fuera,
- `:8080` (consola admin) bloqueado desde fuera.

Pista de criterio (no de exploit): un firewall se construye como **lista
blanca** (política por defecto `DROP` y se abre solo lo necesario), no como
lista negra. Y una regla que no coincide con el tráfico que quiere bloquear
(protocolo o sentido equivocados) no bloquea nada.
