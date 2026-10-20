"""Tienda: ROLE=shop sirve la web (:8080) y las métricas (:9100);
ROLE=scraper lee las métricas de shop cada 5 s (como haría Prometheus)."""
import os
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "shop")


def serve(port, text):
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            body = text().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()


if ROLE == "shop":
    metrics = lambda: (  # noqa: E731
        "# Métricas internas de la tienda\n"
        'shop_build_info{version="4.2.0",db_host="pg-prod-01.interno",admin_path="/gestion-x7"} 1\n'
        "shop_orders_total 18234\n"
        "shop_customers_total 5120\n"
        'shop_payment_errors_total{gateway="redsys"} 17\n')
    threading.Thread(target=serve, args=(9100, metrics), daemon=True).start()
    serve(8080, lambda: "Tienda Norte — bienvenido\n")
else:
    while True:
        try:
            body = urllib.request.urlopen("http://shop:9100/metrics", timeout=3).read().decode()
            status = f"ok {int(time.time())} {len(body.splitlines())} lineas\n"
        except Exception as e:  # noqa: BLE001
            status = f"error {int(time.time())} {e}\n"
        with open("/tmp/last-scrape", "w") as f:
            f.write(status)
        time.sleep(5)
