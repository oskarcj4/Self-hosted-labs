# Resolución guiada · Lab 12

:::piensa Antes de tocar nada
Un log con miles de líneas no se lee: **se resume**. La técnica de este lab sirve para casi cualquier análisis de logs: extraer el campo que te interesa, agruparlo, contarlo y ordenarlo. Lo anómalo aparece arriba (o abajo) por sí solo.
:::

## Paso 1 · Entiende el formato

**Pregúntate:** ¿qué campo de cada línea es el nombre consultado?

**Por qué importa:** si extraes el campo equivocado, todo lo que viene después es ruido.

:::pista Cómo comprobarlo
```bash
head -5 /var/log/dnsquery.log
wc -l /var/log/dnsquery.log
```
Cuenta los campos de una línea. El nombre va justo antes de `IN A`: en `awk` es `$(NF-2)` (dos antes del último).
:::

## Paso 2 · Agrupa por dominio base

**Pregúntate:** `abc123.ejemplo.com` y `xyz789.ejemplo.com` son el mismo destino. ¿Cómo me quedo sólo con `ejemplo.com`?

**Por qué importa:** la exfiltración usa un subdominio **distinto** en cada consulta. Si cuentas nombres completos, cada uno sale una vez y no destaca. Si cuentas el dominio base, destaca muchísimo.

:::pista Cómo hacerlo
```bash
awk '{print $(NF-2)}' /var/log/dnsquery.log \
  | awk -F. '{print $(NF-1)"."$NF}' \
  | sort | uniq -c | sort -rn | head
```
:::

## Paso 3 · Confirma con la forma de los nombres

**Pregúntate:** que un dominio tenga muchas consultas no basta (un CDN también). ¿Qué más lo delata? La **longitud** y el aspecto aleatorio de los subdominios.

:::pista Cómo comprobarlo
```bash
grep '<dominio-sospechoso>' /var/log/dnsquery.log | head
```
Subdominios largos, únicos, con aspecto de base32/hex = datos codificados dentro del nombre.
:::

## Paso 4 · Bloquea y documenta

:::pista Cómo hacerlo
```bash
echo "address=/<dominio>/0.0.0.0" | sudo tee -a /etc/dns-blocklist.conf
echo "Dominio de exfiltracion: <dominio>" > ~/hallazgos.txt
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Patrón universal de análisis**: `extraer | agrupar | sort | uniq -c | sort -rn | head`.
- **Señales de túnel DNS**: volumen alto hacia un dominio, subdominios largos y únicos, alta entropía, dominio recién registrado.
- **Siguiente pregunta**: ¿qué máquina hacía las consultas y qué datos ha sacado? Busca el proceso que las origina.
- Prevención: resolver DNS central con registro, límites de tasa y listas de bloqueo (RPZ).

## Si te atascas

- La lista sale vacía o rara: revisa con `head` qué campo imprime el primer `awk`.
