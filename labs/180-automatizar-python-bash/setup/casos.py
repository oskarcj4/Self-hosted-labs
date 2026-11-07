#!/usr/bin/env python3
"""Casos ocultos del lab 180. Uso: casos.py bash SCRIPT | casos.py python SCRIPT
Imprime una línea "OK ..." o "FALLO ..." por caso."""
import datetime, gzip, json, os, random, shutil, subprocess, sys, tempfile, time

RUNAS = ["runuser", "-u", "analista", "--"] if hasattr(os, "geteuid") and os.geteuid() == 0 else []


def run(cmd, cwd=None, timeout=20):
    # HOME de pruebas: un script que hace "cd $DIR" sin DIR acabaría en HOME.
    casa = sandbox()
    open(os.path.join(casa, "no-borrar.txt"), "w").write("x")
    pre = ["env", f"HOME={casa}"] if RUNAS else []
    r = subprocess.run(RUNAS + pre + cmd, cwd=cwd or casa, capture_output=True, text=True, timeout=timeout)
    if not os.path.exists(os.path.join(casa, "no-borrar.txt")):
        r.returncode = 99
        r.stderr += " ¡el script ha borrado ficheros de HOME!"
    return r


def sandbox():
    d = tempfile.mkdtemp(prefix="tc180-")
    os.chmod(d, 0o777)
    return d


def res(ok, msg):
    print(("OK    " if ok else "FALLO ") + msg)
    return ok


def backups(d, seed):
    rnd = random.Random(seed)
    d0 = datetime.date(2026, 8, 20) + datetime.timedelta(days=rnd.randint(0, 9))
    n = rnd.randint(45, 60)
    fechas = [d0 + datetime.timedelta(days=i) for i in range(n)]
    rnd.shuffle(fechas)
    for f in fechas[: n - 3]:                       # faltan algunos días (huecos)
        p = os.path.join(d, f"db-{f}.tar.gz")
        open(p, "wb").write(b"x")
        t = rnd.randint(1_600_000_000, 1_790_000_000)
        os.utime(p, (t, t))
    otros = ["db-2026-09-15 (copia).tar.gz", "LEEME.txt", "db-2026-09-1.tar.gz", "db-2026-09-16.tar.gz.part",
             "notas importantes.txt", "-rf"]
    for o in otros:
        open(os.path.join(d, o), "w").write("no tocar")
    validas = sorted(f for f in fechas[: n - 3])
    keep = set(validas[-7:]) | {f for f in validas if f.day == 1}
    borrar = sorted(f"db-{f}.tar.gz" for f in validas if f not in keep)
    quedan = sorted([f"db-{f}.tar.gz" for f in keep] + otros)
    for x in os.listdir(d):
        os.chmod(os.path.join(d, x), 0o666)
    return borrar, quedan


def lineas_salida(out, prefijo):
    return sorted(l[len(prefijo):].strip() for l in out.splitlines() if l.startswith(prefijo))


def casos_bash(script):
    ok = True
    # 1. dry-run
    d = sandbox(); borrar, quedan = backups(d, 1)
    antes = sorted(os.listdir(d))
    r = run(["bash", script, d, "--dry-run"])
    ok &= res(r.returncode == 0 and sorted(x for x in os.listdir(d) if x != ".rotar.lock") == antes and lineas_salida(r.stdout, "borraría:") == borrar,
              f"--dry-run lista los {len(borrar)} que borraría y no borra nada")
    # 2. de verdad
    r = run(["bash", script, d])
    ok &= res(r.returncode == 0 and sorted(x for x in os.listdir(d) if x != ".rotar.lock") == quedan
              and lineas_salida(r.stdout, "borrado:") == borrar,
              "borra justo lo que sobra: conserva 7 más recientes por fecha + días 01 + ficheros ajenos")
    # 3. otra tanda distinta (huecos y fechas distintas)
    d2 = sandbox(); borrar2, quedan2 = backups(d2, 7)
    r = run(["bash", script, d2])
    ok &= res(r.returncode == 0 and sorted(x for x in os.listdir(d2) if x != ".rotar.lock") == quedan2,
              "segundo conjunto de backups con huecos")
    # 4. sin argumento / argumento malo, ejecutado desde un directorio con ficheros
    c = sandbox(); backups(c, 3); antes = sorted(os.listdir(c))
    r1 = run(["bash", script], cwd=c)
    r2 = run(["bash", script, os.path.join(c, "no-existe")], cwd=c)
    r3 = run(["bash", script, os.path.join(c, "LEEME.txt")], cwd=c)
    ok &= res(r1.returncode == 2 and r2.returncode == 2 and r3.returncode == 2 and sorted(os.listdir(c)) == antes
              and r1.stderr.strip() != "",
              "sin DIR o con DIR inválido: código 2, mensaje en stderr y no borra nada")
    # 5. cerrojo
    d3 = sandbox(); backups(d3, 5); antes = sorted(os.listdir(d3))
    lock = os.path.join(d3, ".rotar.lock")
    p = subprocess.Popen(RUNAS + ["flock", lock, "sleep", "6"])
    time.sleep(0.8)
    t = time.time(); r = run(["bash", script, d3]); dt = time.time() - t
    p.wait()
    ok &= res(r.returncode == 3 and dt < 4 and sorted(x for x in os.listdir(d3) if x != ".rotar.lock")
              == sorted(x for x in antes if x != ".rotar.lock"),
              "con el cerrojo ocupado: código 3 al momento y sin tocar nada")
    return ok


RUTAS = ["/", "/productos", "/carrito", "/pagar", "/buscar", "/cuenta", "/api/stock"]


def logs(d, seed):
    rnd = random.Random(seed)
    total = err = desc = 0
    cuenta = {}
    fich = []
    for k, gz in enumerate([False, True, False]):
        lines = []
        for i in range(rnd.randint(300, 600)):
            if rnd.random() < 0.02:
                lines.append(rnd.choice(["basura sin formato", "", '10.0.0.1 - - [x] "GET" 200',
                                         "2026/11/06 10:00:01 [error] 12#12: upstream timed out"]))
                desc += 1
                continue
            r = rnd.choice(RUTAS)
            q = f"?id={rnd.randint(1, 999)}&x=1" if rnd.random() < 0.4 else ""
            st = rnd.choice([200] * 12 + [201, 301, 404, 499, 500, 502, 503, 504])
            ua = rnd.choice(["Mozilla/5.0 (X11; Linux x86_64)", "curl/8.5.0", "k6/0.55 (https://k6.io/)"])
            m = rnd.choice(["GET", "GET", "POST"])
            lines.append(f'10.1.{k}.{i % 250} - - [06/Nov/2026:1{k}:{i % 60:02d}:{i % 60:02d} +0000] '
                         f'"{m} {r}{q} HTTP/1.1" {st} {rnd.randint(0, 9000)} "-" "{ua}"')
            total += 1
            if 500 <= st <= 599:
                err += 1
                cuenta[r] = cuenta.get(r, 0) + 1
        p = os.path.join(d, f"access-{k}.log" + (".gz" if gz else ""))
        data = "\n".join(lines) + "\n"
        if gz:
            with gzip.open(p, "wt") as f:
                f.write(data)
        else:
            open(p, "w").write(data)
        os.chmod(p, 0o644)
        fich.append(p)
    tasa = round(err / total, 4) if total else 0
    top = [{"ruta": r, "n": n} for r, n in sorted(cuenta.items(), key=lambda x: (-x[1], x[0]))[:5]]
    return fich, {"total": total, "errores_5xx": err, "tasa": tasa, "top": top, "descartadas": desc}


def casos_python(script):
    ok = True
    d = sandbox()
    fich, esperado = logs(d, 11)
    r = run(["python3", script] + fich + ["--umbral", "0.5"])
    try:
        got = json.loads(r.stdout)
    except ValueError:
        got = None
    if got is None:
        return res(False, f"la salida no es JSON válido: {r.stdout[:120]!r} {r.stderr[-200:]!r}")
    for k in ("total", "errores_5xx", "descartadas"):
        ok &= res(got.get(k) == esperado[k], f"{k} = {esperado[k]} (tu script: {got.get(k)})")
    ok &= res(isinstance(got.get("tasa"), (int, float)) and abs(got["tasa"] - esperado["tasa"]) < 1e-9,
              f"tasa = {esperado['tasa']} (tu script: {got.get('tasa')})")
    ok &= res(got.get("top") == esperado["top"], f"top 5 de rutas con 5xx, sin query string, orden correcto")
    ok &= res(r.returncode == 0, "con la tasa por debajo del umbral, código 0")
    r = run(["python3", script] + fich[:1] + ["--umbral", "0.01"])
    ok &= res(r.returncode == 1, "con la tasa por encima del umbral, código 1")
    r = run(["python3", script, os.path.join(d, "no-existe.log")])
    ok &= res(r.returncode == 2, "fichero inexistente: código 2")
    vacio = os.path.join(d, "vacio.log"); open(vacio, "w").close(); os.chmod(vacio, 0o644)
    r = run(["python3", script, vacio])
    try:
        v = json.loads(r.stdout)
        ok &= res(r.returncode == 0 and v.get("total") == 0 and v.get("tasa") == 0, "log vacío: total 0, tasa 0, código 0")
    except ValueError:
        ok &= res(False, "log vacío: total 0, tasa 0, código 0")
    return ok


if __name__ == "__main__":
    tipo, script = sys.argv[1], sys.argv[2]
    try:
        bueno = casos_bash(script) if tipo == "bash" else casos_python(script)
    except subprocess.TimeoutExpired:
        bueno = res(False, "el script tardó demasiado (¿espera algo?)")
    finally:
        for x in os.listdir(tempfile.gettempdir()):
            if x.startswith("tc180-"):
                shutil.rmtree(os.path.join(tempfile.gettempdir(), x), ignore_errors=True)
    sys.exit(0 if bueno else 1)
