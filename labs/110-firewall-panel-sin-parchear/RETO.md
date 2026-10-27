# Cruzar (o parchear) un firewall por un panel sin actualizar

> Red/Blue · estilo máquina HTB fácil/media · dos banderas (user + root)
> El popup al iniciar decide cómo juegas.

El appliance de borde `gateway.lab` (hostname `target`) tiene el **firewall
bien configurado**: lista blanca, política por defecto `DROP`, y solo expone la
web pública (`80`) y su panel de administración (`10000`). La zona interna
(`22` SSH, `8080` consola admin) está de verdad protegida.

Aquí no hay una regla floja que saltar. El fallo es otro: el software del panel
(**Webmin 1.920**) está **sin parchear** y tiene un CVE conocido con exploit
público. Por ahí se cruza el firewall hasta ejecución de código en el appliance.

---

## 🔴 Si juegas como RED

No tienes shell en el target. Trabajas desde la **caja atacante** (su terminal
es la que ves) y llegas al target por la red. Localízalo con:

```bash
getent hosts target
```

Objetivo: identificar el servicio del `10000` y su versión, localizar el CVE
público y aprovecharlo para ejecutar código en el appliance y capturar las dos
banderas. Entrégalas en la web (campos **user** y **root**). No se te da el
método: esa es la prueba. No estás inventando nada — es una versión vieja con
exploit documentado.

## 🔵 Si juegas como BLUE

Tienes acceso total al target (shell como `analista`). El firewall no se toca:
está bien. La pregunta es **por qué se puede cruzar y cómo lo cierras**.

La respuesta es **actualizar** el panel. El paquete parcheado ya está en el
appliance:

```bash
webmin-update                 # aplica Webmin 1.930 (parcheado) y reinicia
cat /usr/share/webmin/version # comprueba la versión
bash /opt/lab/check.sh
```

El validador exige:

- el firewall sigue correcto (web `:80` y panel `:10000` arriba; `:22` y
  `:8080` bloqueados desde fuera),
- el panel sigue sirviendo en `:10000` (no vale "arreglarlo" apagándolo),
- la versión de Webmin es `>= 1.930` (parcheada),
- el exploit del CVE ya **no** consigue ejecutar código.

Pista de criterio (no de exploit): un firewall correcto no protege de un
servicio que sí dejas entrar si ese servicio está sin parchear. Gestión de
parches = parte del perímetro.
