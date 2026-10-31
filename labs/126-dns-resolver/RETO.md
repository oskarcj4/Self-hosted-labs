# DNS: ¿quién te está respondiendo?

> Redes · dig · @resolver · dig -x · resolv.conf · DNSSEC

## Escenario

Un usuario de `puesto-126` dice que `portal.empresa.lab` "se ve distinto"
y le vuelve a pedir la contraseña. Desde otros puestos va bien
(`~/ticket/DNS-126.txt`). El DNS oficial de la empresa es `10.126.0.53`:
valida DNSSEC y la zona `empresa.lab` está firmada.

Todo empieza por una pregunta: **¿a quién le está preguntando este equipo?**

## Objetivos

1. Averigua qué resolver usa el puesto y qué responde para el portal.
   Pregunta lo mismo directamente al DNS oficial con `dig @10.126.0.53`.
2. Averigua el nombre del equipo `10.126.0.25` (resolución inversa).
3. Rellena `~/dns.txt`:
   ```
   resolver_actual=<IP>
   portal_falso=<IP>
   portal_real=<IP>
   nombre_25=<nombre>
   ```
4. Corrige `/etc/resolv.conf` para usar sólo el DNS oficial y comprueba
   que el sistema (no sólo `dig`) resuelve bien: `getent hosts`.
5. Guarda en `~/dnssec.txt` una consulta `dig +dnssec` del portal contra el
   DNS oficial en la que se vea que la respuesta está **validada**.

## Comandos que te pueden servir

```bash
cat /etc/resolv.conf
dig portal.empresa.lab                 # mira la línea ";; SERVER:"
dig @10.126.0.53 portal.empresa.lab
dig -x 10.126.0.25 @10.126.0.53 +short
dig +dnssec portal.empresa.lab @10.126.0.53   # flags: ... ad  → validada
getent hosts portal.empresa.lab
```

> `dig` pregunta directamente al servidor; `getent`, `ping` o el navegador
> pasan por la configuración del sistema (`/etc/nsswitch.conf`,
> `/etc/hosts`, `/etc/resolv.conf`).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
