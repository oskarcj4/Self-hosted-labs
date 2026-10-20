# Día 03 — Restringir la interfaz de administración a localhost

> 30 días de DevSecOps · Linux · Exposición e higiene web

## Escenario

En `ops-01` corre `ops-admin`, un panel interno capaz de reiniciar servicios y
exportar la base de datos. Lo abrieron "temporalmente" a todas las interfaces
para depurar y nadie lo cerró. El portal público (nginx en el puerto 80) debe
seguir accesible; el panel sólo debe usarse **desde la propia máquina**
(por ejemplo con un túnel SSH).

## Objetivos

1. Haz que `ops-admin` escuche **sólo en `127.0.0.1:9090`**, cambiando su
   configuración (no con un parche temporal).
2. El servicio debe seguir **activo y habilitado**, y responder con
   `curl http://127.0.0.1:9090/`.
3. Desde la red (la IP del host) el panel **no** debe ser accesible por
   **ninguna vía**. Revisa también si algo lo está re-publicando.
4. El portal público debe seguir respondiendo en el puerto 80.

## Comandos que te pueden servir

```bash
sudo ss -tlnp | grep 9090
systemctl cat ops-admin
cat /etc/ops-admin/admin.conf
sudo nginx -T | grep -n -A3 location
IP=$(hostname -I | awk '{print $1}'); curl -s http://$IP:9090/ ; curl -s http://$IP/admin/
```

> Probar contra `localhost` no demuestra nada sobre la exposición: prueba
> siempre contra la IP de la red.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
