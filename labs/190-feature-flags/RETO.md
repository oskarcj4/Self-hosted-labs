# Feature flags

> DevOps · despliegue progresivo · feature flags · interruptor de emergencia · deuda de flags

## Escenario

Separar **desplegar** de **activar**: el código nuevo va a producción
apagado y se enciende poco a poco. Aquí se intentó con variables de entorno
en la unidad de systemd, y tiene estos problemas:

- Cambiar un flag es editar la unidad y **reiniciar**: hay corte, y en una
  emergencia se tarda.
- El "20 %" es `random()` **en cada petición**: el mismo usuario ve el
  checkout nuevo, recarga y ve el viejo, con el carrito a medias.
- `BANNER_NAVIDAD_2023` lleva dos años apagado y su código sigue ahí. Cada
  flag olvidado es una rama de código que nadie prueba.

## Objetivos

Flags en `/etc/tienda/flags.json`:

```json
{"nuevo_checkout": {"activo": true, "porcentaje": 20, "usuarios": ["u-interna"]}}
```

1. `activo: false` lo apaga para todos (interruptor de emergencia).
2. Los usuarios de la lista siempre lo ven.
3. El porcentaje es **estable por usuario**, con un hash del flag y el
   usuario. Subir del 20 al 50 % no quita a nadie.
4. Los cambios se aplican en ≤ 5 s, sin reiniciar.
5. Si el fichero está roto, se mantiene la última configuración buena.
6. El flag de Navidad y su código desaparecen.

## Pistas

```bash
curl 'localhost:8080/checkout?usuario=u-42'
systemctl cat tienda
```

```python
h = hashlib.sha256(f"{flag}:{usuario}".encode()).digest()
cubeta = int.from_bytes(h[:8], "big") % 100       # 0..99, siempre igual para ese usuario
os.stat(ruta).st_mtime_ns                          # ¿ha cambiado el fichero?
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
