#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
H=/home/analista
echo "== Lab 204 · Logs con Loki — comprobación =="
echo "  (mirando lo que ha llegado a Loki en los últimos 30 s)"
curl -sf http://127.0.0.1:3100/ready >/dev/null || { echo "  [✗] Loki no responde en :3100."; exit 1; }
sleep 5
python3 - "$H/consultas" <<'PY'
import json, re, sys, time, urllib.parse, urllib.request, os, collections
L = "http://127.0.0.1:3100/loki/api/v1/"
FIN = time.time_ns(); INI = FIN - 30 * 10**9
cons = sys.argv[1]
ok_n = fail_n = 0
def ok(m):
    global ok_n; ok_n += 1; print(f"  [✓] {m}")
def no(m):
    global fail_n; fail_n += 1; print(f"  [✗] {m}")
def api(path, **q):
    url = L + path + "?" + urllib.parse.urlencode(q)
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"status": "error", "error": e.read().decode(errors="replace")[:200]}
    except Exception as e:
        return {"status": "error", "error": str(e)}
def lineas(q, limit=5000):
    d = api("query_range", query=q, start=INI, end=FIN, limit=limit, direction="forward")
    if d.get("status") != "success": return None, d.get("error", "")
    out = []
    for s in d["data"]["result"]:
        for _, l in s["values"]: out.append((s["stream"], l))
    return out, ""

# 1) Series recientes: cardinalidad de etiquetas
d = api("series", **{"match[]": '{app=~".+"}', "start": INI, "end": FIN})
series = d.get("data", []) if d.get("status") == "success" else []
apps = {s.get("app") for s in series}
valores = collections.defaultdict(set)
for s in series:
    for k, v in s.items(): valores[k].add(v)
altas = {k: len(v) for k, v in valores.items() if len(v) > 10}
if {"pagos", "catalogo"} <= apps:
    ok("Llegan logs recientes de pagos y de catálogo.")
else:
    no(f"En los últimos 30 s sólo llegan las apps {sorted(a for a in apps if a)} (faltan pagos y/o catálogo).")
sin_nivel = [s for s in series if not s.get("nivel")]
if series and not altas and not sin_nivel and len(series) <= 20:
    ok(f"{len(series)} streams con etiquetas de baja cardinalidad ({', '.join(sorted(valores))}), todos con nivel.")
else:
    det = ", ".join(f"{k}={n} valores" for k, n in altas.items())
    no(f"Etiquetas: {len(series)} streams; alta cardinalidad: {det or 'no'}; streams sin etiqueta nivel: {len(sin_nivel)}.")

# 2) Tarjetas
pg, err = lineas('{app="pagos"}')
if pg is None or not pg:
    no(f"No hay líneas recientes de pagos para revisar las tarjetas. {err}")
else:
    completas = [l for _, l in pg if re.search(r"\d{13,19}", l)]
    masc = [l for _, l in pg if re.search(r"tarjeta=\*+\d{4}\b", l)]
    if not completas and len(masc) >= len(pg) // 2:
        ok(f"Tarjetas enmascaradas en Loki ({len(masc)} de {len(pg)} líneas con tarjeta=****NNNN, ninguna completa).")
    else:
        no(f"Tarjetas: {len(completas)} líneas con el número completo; {len(masc)} con el formato tarjeta=****NNNN.")

# 3) Multiline en catálogo
ct, err = lineas('{app="catalogo"}')
if not ct:
    no(f"No hay líneas recientes del catálogo. {err}")
else:
    sueltas = [l for _, l in ct if re.match(r"^(\s+File |Traceback|\s{4}\S|ValueError)", l)]
    errores = [l for _, l in ct if " ERROR catalogo" in l]
    completas = [l for l in errores if "Traceback" in l and "ValueError" in l and "\n" in l]
    if errores and not sueltas and len(completas) == len(errores):
        ok(f"Cada error del catálogo llega con su traza en una sola entrada ({len(errores)} errores).")
    else:
        no(f"Trazas: {len(sueltas)} líneas de traza sueltas; {len(completas)}/{len(errores)} errores con la traza dentro.")

# 4) Consultas
def leer(n):
    try: return open(os.path.join(cons, n), encoding="utf-8").read().strip()
    except OSError: return None
q = leer("pagos-lentos.logql")
if not q:
    no("Falta ~/consultas/pagos-lentos.logql.")
else:
    suyo, e1 = lineas(q)
    ref, _ = lineas('{app="pagos"} | json | duration_ms > 1000')
    def dur(l):
        try: return float(json.loads(l).get("duration_ms", 0))
        except Exception:
            m = re.search(r'"duration_ms":\s*(\d+)', l); return float(m.group(1)) if m else 0
    if suyo is None:
        no(f"pagos-lentos.logql no es una consulta válida: {e1}")
    elif suyo and ref and len(suyo) == len(ref) and all(dur(l) > 1000 for _, l in suyo):
        ok(f"pagos-lentos.logql devuelve las {len(suyo)} líneas de pagos con duration_ms > 1000.")
    else:
        no(f"pagos-lentos.logql devuelve {len(suyo)} líneas (esperaba {len(ref or [])}, todas de pagos con duration_ms > 1000).")
q = leer("errores-por-app.logql")
if not q:
    no("Falta ~/consultas/errores-por-app.logql.")
else:
    t = FIN
    def vec(qq):
        d = api("query", query=qq, time=t)
        if d.get("status") != "success" or d["data"]["resultType"] != "vector": return None, d.get("error", d.get("data", {}).get("resultType"))
        return {r["metric"].get("app"): round(float(r["value"][1])) for r in d["data"]["result"]}, ""
    suyo, e2 = vec(q)
    ref, _ = vec('sum by (app) (count_over_time({app=~".+", nivel=~"(?i)error"}[1m]))')
    if suyo is None:
        no(f"errores-por-app.logql no devuelve un vector (¿es una consulta de métrica?): {e2}")
    elif ref and suyo == ref and {"pagos", "catalogo"} <= set(suyo):
        ok(f"errores-por-app.logql: {suyo}.")
    else:
        no(f"errores-por-app.logql da {suyo}; esperaba {ref} (por app, entradas de nivel error en 1m; si acabas de reiniciar promtail, espera un minuto).")

print("---------------------------------------")
print(f"Resultado: {ok_n} superados, {fail_n} pendientes.")
if fail_n == 0:
    print("🎉 Logs útiles: pocas etiquetas, nada sensible y cada error de una pieza.")
sys.exit(1 if fail_n else 0)
PY
