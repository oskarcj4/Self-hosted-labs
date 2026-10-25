# Solución — Parche rolling sin downtime

## 1. Qué hay que no romper

```bash
systemctl status nginx shop-a shop-b
curl -s http://127.0.0.1/version
curl -s http://127.0.0.1:8081/version ; curl -s http://127.0.0.1:8082/version
cat /var/lib/tclab/nginx.pid; systemctl show -p MainPID --value nginx
```

nginx es el proceso de larga vida. `restart` cambia el PID maestro y corta
conexiones. `reload` (o no tocarlo) lo deja.

## 2. Un backend, luego el otro

```bash
sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-a/
sudo systemctl restart shop-a
curl -s http://127.0.0.1:8081/version    # 1.2.0 app-a
curl -s http://127.0.0.1/version         # mezcla 1.2.0 y 1.0.0: normal a mitad

sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-b/
sudo systemctl restart shop-b
curl -s http://127.0.0.1:8082/version
```

No hace falta recargar nginx: el upstream no cambia, sólo el proceso detrás.

## 3. Comprobar el parche

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/vuln   # no 200
bash /opt/lab/check.sh
```

## Lecciones

- Rolling = N instancias, parcheas 1/N, miras health, sigues. El LB sigue en pie.
- Reiniciar el proxy es un corte. Recargar o no tocarlo.
- Dejar un nodo viejo "por si acaso" deja la CVE viva en la mitad del tráfico.
