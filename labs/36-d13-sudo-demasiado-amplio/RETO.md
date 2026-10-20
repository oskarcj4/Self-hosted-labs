# Día 13 — Reducir un sudo demasiado amplio

> 30 días de DevSecOps · Linux · Secretos y limpieza de políticas

## Escenario

Hace 14 meses el pipeline de despliegue fallaba al rotar los logs y alguien
dio al usuario `deploy` sudo total "temporalmente". Nunca se quitó. Lo único
que `deploy` necesita es ejecutar como root:

```bash
sudo /usr/local/sbin/rotate-app-logs
```

## Objetivos

1. `deploy` sólo puede ejecutar como root **`/usr/local/sbin/rotate-app-logs`**,
   sin contraseña (el pipeline no es interactivo). Nada más.
2. `deploy` no debe pertenecer a grupos administrativos (`sudo`, `admin`, `wheel`).
3. `deploy` ya no puede, p.ej., `sudo cat /etc/shadow`.
4. Cuidado con la trampa: si `deploy` puede **modificar** el script que
   ejecuta como root, sigue siendo root. El script debe ser de root y no
   escribible por otros.
5. La configuración de sudo debe seguir siendo válida (`visudo -c`).

## Comandos que te pueden servir

```bash
sudo -l -U deploy                       # qué puede hacer deploy
id deploy ; ls -l /etc/sudoers.d/ /usr/local/sbin/rotate-app-logs
sudo visudo -f /etc/sudoers.d/40-deploy-temp      # edita con comprobación de sintaxis
sudo gpasswd -d deploy sudo
sudo runuser -u deploy -- sudo -n /usr/local/sbin/rotate-app-logs   # probar como deploy
```

> Edita sudoers **siempre** con `visudo`: un error de sintaxis en
> `/etc/sudoers.d/` puede dejarte sin sudo a ti también.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
