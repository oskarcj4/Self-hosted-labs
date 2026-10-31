# Firewall con ufw: negar por defecto

> Defensa del host · ufw · default deny · superficie de ataque

## Escenario

`web-113` es un servidor web público, pero desde Internet se ve mucho más que
la web: MySQL (3306), Redis (6379) y un panel de pruebas (8080). ufw está
instalado e **inactivo**, con reglas heredadas de "cuando estábamos probando".
Detalle en `~/ticket/AUDIT-113.txt`.

Un escáner externo pasa cada 15 s y deja lo que ve en `/srv/escaneo/ultimo.txt`:
es tu vista "desde fuera".

## Objetivos

1. Revisa qué escucha y qué ve el exterior **antes** de tocar nada.
2. Limpia las reglas heredadas.
3. Permite **SSH primero**, luego niega todo lo entrante por defecto y abre
   sólo 80 y 443.
4. Activa ufw (y que siga activo tras reiniciar) y verifica desde fuera:
   sólo 22 y 80 abiertos (443 permitido aunque aún no haya nada escuchando).

## Comandos que te pueden servir

```bash
sudo ss -tlnp
cat /srv/escaneo/ultimo.txt
sudo ufw status numbered ; sudo ufw delete <N>
sudo ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp ; sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

> El orden importa: en un servidor real, activar `deny` antes de permitir SSH
> te deja fuera. Aquí el contenedor tiene `NET_ADMIN` (va privilegiado), y su
> firewall sólo afecta a su propia red.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
