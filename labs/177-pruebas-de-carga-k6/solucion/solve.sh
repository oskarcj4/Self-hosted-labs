#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export K6_NO_USAGE_REPORT=true
cat > ~/carga/prueba.js <<'JS'
import http from 'k6/http';
import { check, sleep } from 'k6';

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

export default function () {
  const cat = String(Math.floor(Math.random() * 300)).padStart(3, '0');
  const r1 = http.get('http://127.0.0.1:8080/productos', { tags: { ruta: 'productos' } });
  const r2 = http.get(`http://127.0.0.1:8080/buscar?categoria=cat-${cat}`, { tags: { ruta: 'buscar' } });
  check(r1, { 'productos 200': (r) => r.status === 200 });
  check(r2, { 'buscar 200': (r) => r.status === 200 });
  sleep(0.5);
}
JS
k6 run --quiet ~/carga/prueba.js || true        # antes: umbrales rotos

# Cuello 1: el servidor atiende de una en una.
sed -i 's/from http.server import BaseHTTPRequestHandler, HTTPServer/from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer/; s/^HTTPServer(/ThreadingHTTPServer(/' \
  ~/catalogo/app.py
sudo systemctl restart catalogo
sleep 1
k6 run --quiet ~/carga/prueba.js || true        # mejor, pero /buscar sigue lento

# Cuello 2: /buscar recorre 300 000 filas.
sqlite3 ~/catalogo/catalogo.db "CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(categoria);"
sqlite3 ~/catalogo/catalogo.db "EXPLAIN QUERY PLAN SELECT count(*), avg(precio) FROM productos WHERE categoria = 'cat-001'"

cat > ~/carga/informe.txt <<'TXT'
Cuello 1 · El servidor atiende de una en una (HTTPServer, sin hilos).
  Evidencia: con 50 VUs, p95 de /productos (sólo 20 ms de espera) sube a segundos; la
  latencia crece en línea recta con los VUs y la CPU apenas se usa.
  Arreglo: ThreadingHTTPServer (un hilo por petición): las esperas se solapan.
Cuello 2 · /buscar recorre la tabla entera: sin índice en categoria.
  Evidencia: tras el arreglo 1, /productos va bien y /buscar (tag ruta:buscar) sigue con
  p95 alto; la CPU al 100 %; EXPLAIN QUERY PLAN dice "SCAN productos".
  Arreglo: CREATE INDEX idx_productos_categoria ON productos(categoria); ahora "SEARCH ... USING INDEX".
TXT
k6 run --quiet ~/carga/prueba.js
echo "solve.sh completado."
