# Día 02 — Quitar un puerto público innecesario

> 30 días de DevSecOps · Linux · Exposición e higiene web

## Escenario

`shop-web-01` sirve la tienda en el puerto **80**. Hace meses se hizo una
prueba de compatibilidad con la app móvil antigua y nginx quedó escuchando
**también en el 8080**. La prueba terminó, pero el puerto sigue abierto a
todo el mundo: superficie de ataque gratis.

## Objetivos

1. Haz que **nada escuche en el puerto 8080**.
2. El cambio debe ser **persistente**: la configuración de nginx no puede
   volver a abrir el 8080 al recargar o reiniciar (`nginx -T` es la verdad).
3. La tienda debe seguir funcionando en el **puerto 80**, accesible desde la
   red: índice, `/css/style.css` y `/health`.
4. nginx debe quedar con configuración válida y activo.

> Pista: cuando un puerto "no se va", es que está declarado en **más de un sitio**.

## Comandos que te pueden servir

```bash
sudo ss -tlnp | grep -E ':(80|8080)\b'
sudo nginx -T | grep -n listen        # configuración efectiva completa
ls -la /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -i http://$(hostname -I | awk '{print $1}')/health
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
