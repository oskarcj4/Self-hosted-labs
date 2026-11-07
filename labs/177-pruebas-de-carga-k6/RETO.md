# Pruebas de carga con k6

> SRE · rendimiento · k6 · stages · thresholds · cuellos de botella

## Escenario

El catálogo (`~/catalogo`) va perfecto con un usuario. Marketing espera **50
usuarios a la vez** en el Black Friday. El objetivo de servicio es **p95 <
300 ms** y **menos de 1 % de errores**.

La única prueba que existe (`~/carga/ejemplo.js`) lanza un usuario durante 10
segundos: no demuestra nada.

Conceptos de k6:

- **VU** (usuario virtual): un bucle que ejecuta la función `default` una y otra vez.
- **stages**: cómo sube y baja el número de VUs en el tiempo.
- **thresholds**: criterios de aprobado; si uno falla, `k6 run` sale con código ≠ 0.
  Por eso sirve en un pipeline.
- **tags**: separar métricas por ruta para ver *cuál* es la lenta.

Un cuello de botella esconde al siguiente: cuando quitas el primero, aparece otro.

## Objetivos

1. `~/carga/prueba.js` con etapas hasta 50 VUs, umbrales `p(95)<300` y
   `rate<0.01`, y peticiones a `/productos` y `/buscar?categoria=cat-NNN`.
2. `~/carga/informe.txt`: cada cuello de botella, su evidencia y su arreglo.
3. Cuellos arreglados (app en `~/catalogo`).
4. Tu prueba pasa sus umbrales. El check lanza además su propia prueba de 50 VUs.

## Pistas

```bash
k6 run ~/carga/ejemplo.js
k6 run ~/carga/prueba.js
top -H -p "$(systemctl show -p MainPID --value catalogo)"     # mientras corre la prueba
sqlite3 ~/catalogo/catalogo.db "EXPLAIN QUERY PLAN SELECT count(*) FROM productos WHERE categoria='cat-001'"
```

```javascript
export const options = {
  stages: [{ duration: '10s', target: 50 }, { duration: '20s', target: 50 }],
  thresholds: { http_req_duration: ['p(95)<300'], http_req_failed: ['rate<0.01'] },
};
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
