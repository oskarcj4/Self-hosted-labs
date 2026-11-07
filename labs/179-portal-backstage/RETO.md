# Portal interno: el catálogo de software (estilo Backstage)

> Platform engineering · catálogo de software · ownership · catalog-info.yaml · TechDocs

## Escenario

"¿De quién es este servicio?", "¿qué se rompe si cae la base de datos de
pagos?", "¿dónde está su documentación?". Un **portal interno** responde a
esas preguntas desde un **catálogo de software** que vive en git, junto al
código.

El formato es el de **Backstage** (`catalog-info.yaml`, `backstage.io/v1alpha1`):

| kind | Qué es |
|------|--------|
| `Component` | un servicio, una web, una librería |
| `API` | lo que un componente ofrece a otros (`providesApis` / `consumesApis`) |
| `Resource` | infraestructura: bases de datos, colas, buckets |
| `System` | un conjunto de componentes, APIs y recursos que forman un producto |
| `Group` / `User` | equipos y personas: los **owners** |
| `Location` | lista de ficheros que el portal debe cargar |

> **Aviso:** esto **no es Backstage**. Backstage real necesita Node.js,
> PostgreSQL y varios GB, demasiado para un lab. Aquí `catalogo` (validador y
> portal mínimo, en `/usr/local/bin/catalogo`) usa el mismo formato de
> descriptores y las mismas reglas principales. Los ficheros que escribas
> sirven tal cual en un Backstage de verdad.

Hoy nadie se fía del catálogo: tiene errores de formato, dueños que no
existen, APIs fantasma, y el servicio de notificaciones ni aparece.

## Objetivos

1. `catalogo validar ~/plataforma/catalogo` sin errores ni avisos.
2. Group `equipo-logistica` (dentro de `ingenieria`), API `pagos-api` (openapi,
   definición desde `openapi.yaml`), Resource `postgres-pagos` (database).
3. El componente de catálogo de productos con `apiVersion` y nombre válidos.
4. `notificaciones` registrado: owner `plataforma`, system `tienda`,
   lifecycle `production`, type `service`, depende de `envios`, con TechDocs.
5. Todo con commit en git.

## Pistas

```bash
cd ~/plataforma/catalogo
cat CONTRIBUIR.md
catalogo validar .
catalogo entidades .
curl -s localhost:7007/api/entities/component/envios | python3 -m json.tool
```

```yaml
spec:
  definition:
    $text: ./openapi.yaml          # la definición se lee del fichero
  dependsOn: [component:envios]    # dependsOn siempre lleva kind
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
