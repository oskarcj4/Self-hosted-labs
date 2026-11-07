#!/usr/bin/env bash
# Lab 188: un runner de CI propio instalado "rápido": corre como root, reutiliza
# el mismo directorio para todos los trabajos, pasa su entorno (con el token del
# registro) a cada job, no tiene límite de tiempo y acepta cualquier etiqueta.
set -e
mkdir -p /opt/runner /etc/runner /srv/ci

cat > /opt/runner/runner.py <<'PY'
#!/usr/bin/env python3
"""Runner de CI mínimo: ejecuta los trabajos JSON que aparecen en <base>/cola.

Trabajo: {"id": "123", "etiquetas": ["linux"], "script": "make test"}
Resultado en <base>/resultados/<id>.json: estado (ok|fallo|timeout|rechazado), rc, salida.
Configuración: /etc/runner/runner.ini, sección [runner]:
  base             directorio de trabajo del runner (cola/, resultados/, trabajo/)
  espacio_efimero  si: un directorio nuevo por trabajo, borrado al terminar
                   no: todos los trabajos en <base>/trabajo
  timeout          segundos por trabajo (0 = sin límite)
  etiquetas        etiquetas que acepta este runner, separadas por comas (* = todas)
  heredar_entorno  si: el job recibe el entorno del runner; no: sólo PATH, HOME y CI_*
"""
import configparser, json, os, pathlib, shutil, signal, subprocess, tempfile, time

cfg = configparser.ConfigParser()
cfg.read("/etc/runner/runner.ini")
c = cfg["runner"]
BASE = pathlib.Path(c.get("base", "/srv/ci"))
COLA, RES, RECH, TRABAJO = BASE / "cola", BASE / "resultados", BASE / "rechazados", BASE / "trabajo"
EFIMERO = c.getboolean("espacio_efimero", False)
TIMEOUT = c.getint("timeout", 0)
ETIQ = {e.strip() for e in c.get("etiquetas", "*").split(",") if e.strip()}
HEREDAR = c.getboolean("heredar_entorno", True)
for d in (COLA, RES, RECH, TRABAJO):
    d.mkdir(parents=True, exist_ok=True)
print(f"runner: uid={os.getuid()} efimero={EFIMERO} timeout={TIMEOUT} "
      f"etiquetas={','.join(sorted(ETIQ))} heredar_entorno={HEREDAR}", flush=True)


def resultado(jid, **datos):
    tmp = RES / f".{jid}.tmp"
    tmp.write_text(json.dumps({"id": jid, **datos}))
    tmp.rename(RES / f"{jid}.json")


while True:
    for f in sorted(COLA.glob("*.json"), key=lambda p: p.stat().st_mtime):
        try:
            job = json.loads(f.read_text())
            jid = str(job["id"])
        except Exception:
            f.rename(RECH / f.name)
            continue
        if "*" not in ETIQ and not set(job.get("etiquetas", [])) <= ETIQ:
            f.rename(RECH / f.name)
            resultado(jid, estado="rechazado", rc=None, salida="etiquetas no admitidas")
            print(f"job {jid}: rechazado (etiquetas {job.get('etiquetas')})", flush=True)
            continue
        f.unlink()
        ws = pathlib.Path(tempfile.mkdtemp(prefix=f"job-{jid}-", dir=TRABAJO)) if EFIMERO else TRABAJO
        env = dict(os.environ) if HEREDAR else {"PATH": "/usr/local/bin:/usr/bin:/bin", "LANG": "C.UTF-8"}
        env.update(HOME=str(ws), CI_JOB_ID=jid, CI_WORKSPACE=str(ws))
        t0, estado = time.time(), "ok"
        p = subprocess.Popen(["bash", "-c", job.get("script", "")], cwd=ws, env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            out, _ = p.communicate(timeout=TIMEOUT or None)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)       # el job y todo lo que lanzó
            out, _ = p.communicate()
            estado = "timeout"
        if estado == "ok" and p.returncode != 0:
            estado = "fallo"
        resultado(jid, estado=estado, rc=p.returncode, segundos=round(time.time() - t0, 1),
                  salida=out.decode(errors="replace")[-4000:])
        print(f"job {jid}: {estado} rc={p.returncode}", flush=True)
        if EFIMERO:
            shutil.rmtree(ws, ignore_errors=True)
    time.sleep(0.5)
PY
chmod 755 /opt/runner/runner.py

cat > /etc/runner/runner.ini <<'INI'
[runner]
base = /srv/ci
espacio_efimero = no
timeout = 0
etiquetas = *
heredar_entorno = si
INI

TOKEN="reg_$(tr -dc 'a-z0-9' < /dev/urandom | head -c 32)"
echo "$TOKEN" > /opt/lab/.token
chmod 600 /opt/lab/.token
cat > /etc/systemd/system/runner.service <<U
[Unit]
Description=Runner de CI propio
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/runner/runner.py
Environment=REGISTRY_TOKEN=$TOKEN
Restart=always

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now runner

# Datos de analista que un job no debería poder leer.
echo "Contraseña del NAS de la oficina: Oficina-2026" > /home/analista/notas.txt
chmod 644 /home/analista/notas.txt
chown analista:analista /home/analista/notas.txt

# Herramienta para mandar trabajos a la cola.
cat > /usr/local/bin/ci-job <<'SH'
#!/usr/bin/env bash
# ci-job 'script' [etiqueta,etiqueta]   -> encola un trabajo y espera el resultado
set -u
ID="m$(date +%s)$RANDOM"
ETQ=$(printf '%s' "${2:-linux}" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().split(",")))')
python3 -c 'import json,sys;print(json.dumps({"id":sys.argv[1],"etiquetas":json.loads(sys.argv[2]),"script":sys.argv[3]}))' \
  "$ID" "$ETQ" "$1" | sudo tee /srv/ci/cola/.$ID > /dev/null && sudo mv /srv/ci/cola/.$ID /srv/ci/cola/$ID.json
echo "encolado $ID; esperando..."
for _ in $(seq 1 120); do
  sudo test -e /srv/ci/resultados/$ID.json && { sudo python3 -m json.tool /srv/ci/resultados/$ID.json; exit; }
  sleep 1
done
echo "sin resultado en 120 s"
SH
chmod 755 /usr/local/bin/ci-job

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Runner propio

El runner de CI de la empresa (runner.service, /opt/runner/runner.py,
/etc/runner/runner.ini) ejecuta el código de CUALQUIER pull request,
también de forks. Ahora mismo, un PR malicioso puede:
  - leerlo todo como root (y escribir donde quiera),
  - leer el token del registro (está en el entorno del runner),
  - dejar ficheros en el espacio de trabajo para el siguiente job,
  - leer /home/analista y dejar cosas en /tmp del servidor,
  - quedarse corriendo para siempre (minar, por ejemplo).

Endurécelo sin romperlo:
  1. Usuario de sistema propio (ci-runner), nunca root.
  2. Espacio de trabajo efímero, un directorio por job que se borra al terminar.
  3. Los jobs no heredan el entorno del runner, y el token sale de la unidad
     (que lee todo el mundo) a un fichero 0600 con EnvironmentFile.
  4. Timeout de 60 s como máximo.
  5. Sólo etiquetas linux y x64.
  6. Sandbox de systemd: NoNewPrivileges, PrivateTmp, ProtectSystem (full o strict),
     ProtectHome, y un MemoryMax.

Prueba con:  ci-job 'id; env; pwd; ls -la'
Comprueba:   bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 188 plantado."
