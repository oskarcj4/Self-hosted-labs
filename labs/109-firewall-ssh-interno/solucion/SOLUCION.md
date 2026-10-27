# Solución — Firewall que se salta hasta el SSH interno (vía BLUE)

> Solo el blindaje. La explotación (RED) la resuelves tú.

## Por qué se podía saltar

El firewall declaraba "solo 80; 22 y 8080 cerrados", pero dos errores lo
vaciaban y dejaban el SSH interno al alcance de cualquiera desde fuera:

1. **Política por defecto `ACCEPT` (lista negra).** Con la cadena `INPUT` en
   `ACCEPT`, todo lo que no coincida con un `DROP` explícito **entra**. Basta
   olvidar un puerto —o que su regla falle— para exponerlo. Un firewall se
   construye al revés: política `DROP` y se abre solo lo necesario (lista
   blanca).

2. **La regla de SSH no coincidía con el tráfico de SSH.** Estaba escrita como
   `-p udp --dport 22 -j DROP`, pero SSH es **TCP**. Esa regla nunca evalúa un
   paquete TCP a 22, así que no bloquea nada. Combinado con la política
   `ACCEPT`, el `22/tcp` quedaba abierto a la red.

Con el `22` abierto, el atacante entra por SSH (credencial de fábrica sin
rotar) y, ya **dentro del nodo**, alcanza la consola admin del `8080` por
`localhost` —que el firewall sí bloquea desde fuera, pero no desde dentro— y
que además no pide autenticación. De ahí la bandera root.

## Arreglo

Lista blanca: política `DROP` y un único `ACCEPT` para el `80`. El `22` y el
`8080` quedan bloqueados por la política por defecto, sin reglas frágiles.

```sh
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

Aplica y comprueba:

```bash
fw-reload
bash /opt/lab/check.sh
```

## Más allá del lab

- **Lista blanca, no lista negra.** `DROP` por defecto. Enumerar lo que se
  bloquea siempre deja huecos; enumerar lo que se permite, no.
- **Defensa en capas.** El firewall de red no sustituye a que el servicio no
  escuche en `0.0.0.0` si solo lo necesita `localhost`. La consola admin del
  `8080` debería atarse a `127.0.0.1` **y** pedir autenticación, no fiarse de
  "solo se alcanza desde dentro".
- **SSH expuesto = credenciales importan.** Rota las credenciales de fábrica,
  usa claves en vez de contraseña y restringe el origen.
- **Prueba las reglas con el paquete del atacante**, no leyéndolas: una regla
  con el protocolo o el sentido equivocados parece proteger y no protege (como
  hace el validador de este lab).

## Lecciones

- La política por defecto es la decisión más importante del firewall.
- Una regla que no coincide con el tráfico que quiere bloquear es decoración.
- El firewall no es el único control: bind local + autenticación + rotación.
