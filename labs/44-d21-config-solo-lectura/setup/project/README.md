# edge — API gateway

- Configuración: `config/routes.conf` (una ruta por línea: `prefijo upstream`).
- Se monta en el contenedor en `/etc/gateway`.
- Al arrancar, el gateway guarda una caché en `GATEWAY_CACHE_DIR`
  (por defecto, la propia carpeta de configuración).
- Salud: `curl http://localhost:8080/health`
