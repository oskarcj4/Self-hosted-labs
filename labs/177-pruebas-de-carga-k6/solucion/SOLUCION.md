# Solución — Pruebas de carga con k6

## La prueba (`~/carga/prueba.js`)

```javascript
export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '10s', target: 50 },
    { duration: '20s', target: 50 },
    { duration: '5s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
    'http_req_duration{ruta:buscar}': ['p(95)<300'],
  },
};
```

## Cuellos de botella

| # | Cuello | Evidencia | Arreglo |
|---|--------|-----------|---------|
| 1 | `HTTPServer` atiende una petición cada vez | p95 de `/productos` en segundos; un solo hilo; CPU libre | `ThreadingHTTPServer` |
| 2 | `/buscar` sin índice: `SCAN` de 300 000 filas | tras 1, `/buscar` sigue lento; CPU al 100 % | `CREATE INDEX ... ON productos(categoria)` |

Tras los dos arreglos: p95 de unas decenas de ms con 50 VUs y 0 % de errores.

## Por qué

- Con un usuario, ningún cuello se nota: 20 ms de espera o 40 ms de búsqueda
  están bien. Con 50, se suman en cola.
- Arreglar el 1 hizo **visible** el 2: antes, las peticiones ni llegaban a
  buscar a la vez.

## Más allá del lab

- `k6 run --out experimental-prometheus-rw` para ver la prueba en Grafana junto a las métricas del servicio (lab 171).
- Pruebas de resistencia (soak): carga media durante horas, para fugas de memoria o de conexiones (lab 173).
- Ten en cuenta el GIL de Python: con CPU de verdad, más procesos (gunicorn con workers) en lugar de hilos.
