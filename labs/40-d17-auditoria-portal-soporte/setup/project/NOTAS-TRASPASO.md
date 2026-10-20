# Portal de soporte — notas de traspaso

(escritas por el equipo anterior; última revisión: hace un año)

- Imagen: `support/portal:2.2`
- Publicado en el puerto **8080** del host.
- Los adjuntos van a un volumen con nombre, montado **sólo lectura** en el contenedor.
- La app corre con el usuario `portal` (sin privilegios).
- No lleva secretos: las credenciales están en el gestor de secretos.

Arranque (por si hay que recrearlo):

```bash
docker run -d --name support-portal -p 8080:8000 \
  -v portal-uploads:/app/uploads:ro --user portal support/portal:2.2
```
