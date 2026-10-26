// Tráfico de usuarios para el lab 107. No es una prueba de carga pesada:
// 25 usuarios virtuales haciendo checkout + health. Suficiente para que, si
// una migración bloquea la tabla 'pedidos', lo veas morir en tiempo real.
//
//   k6 run /opt/lab/load.js
//
// Mira la columna http_req_failed y las líneas "status 503": mientras el
// firewall de locks de PostgreSQL deje pasar tu migración, siguen en 0.
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 25,
  duration: "90s",
  thresholds: {
    // objetivo de servicio: <1% de errores y p95 < 800ms
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<800"],
  },
};

const BASE = __ENV.BASE || "http://127.0.0.1:8080";

export default function () {
  const r1 = http.post(`${BASE}/checkout`);
  check(r1, { "checkout 201": (r) => r.status === 201 });
  const r2 = http.get(`${BASE}/health`);
  check(r2, { "health 200": (r) => r.status === 200 });
  sleep(0.2);
}
