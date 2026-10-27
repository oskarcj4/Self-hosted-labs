# GHSA-tc96-acme-tool · acme/tool comprometida

**Severidad:** crítica · **Publicado:** hace 2 horas

Un atacante obtuvo un token con permisos de escritura en `acme/tool`, subió
un commit que exfiltra `GITHUB_TOKEN` y los secretos del runner, y **movió
los tags** `v1` y `v1.3.1` a ese commit. `main` también apunta a él.

- Versiones afectadas: todo lo que resuelva a `v1`, `v1.3.1` o `main`.
- Última versión buena: **`v1.3.0`**.
- Acción recomendada: fijar `acme/tool` al commit de `v1.3.0` y rotar los
  secretos de cualquier ejecución reciente.

Mirror local de los repos de actions: `/srv/gh/<owner>/<repo>.git`
