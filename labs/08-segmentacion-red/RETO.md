# Lab 08 — Segmentación: el puerto interno expuesto a todos

Inspirado en los casos del casino (termómetro de la pecera) y de Target (HVAC):
un sistema sin importancia alcanza la red interna porque **nadie segmentó**.

## Escenario

`edge-08` expone a internet su web pública en el puerto **80** (correcto) pero,
por un error de firewall, también deja abierto a cualquiera el panel de
administración interno en el puerto **9000** (incorrecto). Ese panel sólo debería
ser accesible desde la propia máquina (loopback). Arregla las reglas de
`iptables`.

## Objetivos

1. **Audita las reglas de entrada** y encuentra la regla que acepta `tcp/9000`
   desde cualquier origen.
2. **Quita esa regla permisiva.**
3. **Añade una regla que BLOQUEE `tcp/9000`** desde orígenes externos
   (DROP o REJECT).
4. **Deja intacto el puerto 80** (la web pública debe seguir accesible).

## Comandos que te pueden servir

```bash
sudo iptables -S INPUT                              # lista las reglas actuales
curl -s localhost:9000 >/dev/null && echo "9000 responde"
sudo iptables -D INPUT -p tcp --dport 9000 -j ACCEPT   # borra la regla mala
sudo iptables -A INPUT -p tcp --dport 9000 -j DROP     # bloquea el puerto interno
```

> Regla de segmentación: cada servicio accesible sólo desde donde debe serlo. Un
> panel de administración no se expone a internet "porque es cómodo".

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
