// Prueba de referencia del check (50 VUs, 20 s).
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  scenarios: {
    black_friday: { executor: 'constant-vus', vus: 50, duration: '20s' },
  },
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
  summaryTrendStats: ['avg', 'p(95)', 'max'],
};

export default function () {
  const cat = String(Math.floor(Math.random() * 300)).padStart(3, '0');
  http.get('http://127.0.0.1:8080/productos');
  http.get(`http://127.0.0.1:8080/buscar?categoria=cat-${cat}`);
  sleep(0.5);
}
