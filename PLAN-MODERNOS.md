# Plan de implementación — Labs modernos (Cloud native / DevOps / SRE)

Origen: sección "Hoja de ruta ampliada" de `CATALOGO.md`. Se implementan de
**7 en 7**, modernos/prioritarios primero: primero todos los **★** prioritarios,
luego los normales, luego los **▲** avanzados o dependientes del entorno.

Excluidos (ya implementados): `El pipeline que ayer pasaba` → lab 140,
`Rollback <2 min` → lab 141, `Imagen de 1.2 GB con CVEs` → lab 142.
Mr. Robot (labs 143–151): completos y probados, en stand-by (sin commit).

Numeración: labs 152–224 (73 labs, 11 tandas). Pista nueva prevista: **O**
(DevOps/Cloud native moderno). Las tandas de Kubernetes/GitOps usan un clúster
ligero dentro del contenedor (k3d/kind sobre Docker-in-Docker); los ▲ que
dependen del kernel de Docker Desktop (eBPF, Falco) se marcan como "mejor
esfuerzo".

Estado por lab: ⬜ pendiente · 🟡 en curso · ✅ hecho y probado.

Nota: a petición del autor se intercalaron 2 labs de almacenamiento (montar
disco y disco cifrado LUKS) en la Tanda 1; Pipeline completo y Monorepo bajaron
a la Tanda 2 y todo lo posterior corre +2. Numeración final: 152–226.

## Tanda 1 — Imagen/ejecución en producción + almacenamiento · labs 152–158
| Lab | Tema | Estado |
|-----|------|--------|
| 152 | Dockerfile de producción (multi-stage, no root, HEALTHCHECK, labels OCI, .dockerignore) | ✅ 7/7 |
| 153 | Configuración por ambiente (misma imagen, solo variables; 12-factor) | ✅ 5/5 |
| 154 | Tres health checks (startup, liveness, readiness con dependencias) | ✅ 6/6 |
| 155 | Montar un disco (losetup, mkfs.ext4, mount, fstab) | ✅ 5/5 |
| 156 | Disco cifrado con LUKS (cryptsetup luksFormat, dm-crypt, mapper) | ✅ 4/4 |
| 157 | Migraciones sin downtime (expand/contract con Alembic) | ✅ 6/6 |
| 158 | Revisión antes de salir (checklist go-live) | ✅ 6/6 |

## Tanda 2 — CI y Kubernetes núcleo (★) · labs 159–165
Kubernetes: k3s v1.31 de un nodo dentro del contenedor (systemd + `k3s.service`,
snapshotter `native`, imágenes airgap y de cargas precargadas: arranca sin red).
Andamiaje común idéntico en todos los labs k8s (mismas capas de Docker).

| Lab | Tema | Estado |
|-----|------|--------|
| 159 | Pipeline completo (test/gitleaks/build por SHA/registro/deploy con rollback) | 🟡 escrito, falta probar en Docker |
| 160 | Monorepo (construir solo lo que cambió) | 🟡 lógica probada 7/7 en local; falta probar en Docker |
| 161 | CrashLoopBackOff (OOMKilled, liveness, ConfigMap) | 🟡 escrito, falta probar en Docker |
| 162 | Pods en Pending (taint, cpu, nodeSelector, StorageClass) | 🟡 escrito, falta probar en Docker |
| 163 | Requests y límites (QoS, throttling, LimitRange) | 🟡 escrito, falta probar en Docker |
| 164 | Helm (rollback, chart parametrizado, values por ambiente) | 🟡 escrito, falta probar en Docker |
| 165 | NetworkPolicies (default-deny + flujos mínimos) | 🟡 escrito, falta probar en Docker |

## Tanda 3 — Kubernetes + IaC (★) · labs 166–172
Terraform usa el proveedor `kubernetes` contra el k3s del lab, con proveedores
en un espejo local (`terraform init` sin red). Estado remoto del 168: backend
`http` con bloqueo servido por `tf-state-server` (MinIO retiró sus binarios
públicos). Observabilidad (170–172): systemd sin k3s.

| Lab | Tema | Estado |
|-----|------|--------|
| 166 | Escalado con HPA (requests, estabilización, prueba de carga) | 🟡 escrito, falta probar en Docker |
| 167 | Argo CD fuera de sincronía (drift, hotfix a git, selfHeal/prune) | 🟡 escrito, falta probar en Docker |
| 168 | Terraform: lock huérfano, drift e import | 🟡 backend de estado probado con Terraform 1.11 real; falta Docker |
| 169 | Terraform: módulos, validation, for_each, moved | 🟡 módulo y validation probados con `terraform validate`; falta Docker |
| 170 | OpenTelemetry (Collector, service.name, propagación, span lento) | 🟡 propagación probada en local con el SDK 1.29; falta Docker |
| 171 | Métricas RED (Counter/Histogram, scrape, recording rules, Grafana) | 🟡 instrumentación probada en local; falta Docker |
| 172 | SLO y error budget (burn rate multiventana, tests ocultos promtool) | 🟡 tests ocultos probados con promtool 2.55 (solución pasa, reglas ingenuas y de una sola ventana fallan); falta Docker |

## Tanda 4 — Observabilidad, seguridad y confiabilidad (★) · labs 173–179
Todos sobre systemd (sin k3s). El 179 no instala Backstage real (Node.js +
PostgreSQL, varios GB): usa el mismo formato `catalog-info.yaml` con un
validador y un portal mínimos propios, y el RETO lo dice.

| Lab | Tema | Estado |
|-----|------|--------|
| 173 | Verde, pero fallando (fuga del pool, CPUQuota, DNS muerto) | 🟡 escrito, falta probar en Docker |
| 174 | Escaneo en el pipeline (Semgrep + Trivy que bloquean, nosemgrep justificado) | 🟡 escrito; las reglas Semgrep no se han podido probar en Windows; falta Docker |
| 175 | Vault: credenciales dinámicas de PostgreSQL (TTL, política, rotar la filtrada) | 🟡 escrito, falta probar en Docker |
| 176 | PostgreSQL PITR (backup base + WAL, instancia aparte en 5433) | 🟡 escrito, falta probar en Docker |
| 177 | Pruebas de carga con k6 (stages, thresholds, dos cuellos en serie) | 🟡 coste del SCAN frente al índice medido en local; falta Docker |
| 178 | Incidente completo (disco lleno, logrotate, comunicado, postmortem) | 🟡 parser del postmortem probado en local; falta Docker |
| 179 | Portal interno al estilo Backstage (catálogo, ownership, TechDocs) | 🟡 validador, portal y solve probados en local; falta Docker |

## Tanda 5 — labs 180–186
Base systemd (180, 182, 185, 186) o Docker-in-Docker (181, 183, 184: Docker
corre dentro del lab, con las imágenes precargadas en la imagen del lab).

| Lab | Título | Estado |
|-----|--------|--------|
| 180 | Automatizar con Python y Bash (★): rotación de backups y informe robustos | 🟡 casos ocultos probados en local (salvo el lock: no hay flock en Windows); falta Docker |
| 181 | Apagado limpio (SIGTERM / PID 1 / zombis) | 🟡 transformación de la solución probada; falta Docker |
| 182 | Versionado y releases (SemVer + Conventional Commits) | 🟡 10 casos ocultos y release probados en local; falta Docker |
| 183 | Compose para un VPS (puertos, volumen, secrets, healthchecks) | 🟡 revisión estática con `docker compose config` probada (bueno/malo); falta Docker |
| 184 | Imágenes multiarquitectura (buildx, compilación cruzada) | 🟡 lector ELF probado; falta Docker |
| 185 | Logs para producción (JSON, request_id, enmascarado) | 🟡 app de la solución probada en local contra el análisis del check; falta Docker |
| 186 | Tests inestables (orden, azar, hora, puerto) | 🟡 plantado falla y solución pasa en local; mutantes detectados; faketime sin probar (Windows); falta Docker |

## Tanda 6 — labs 187–193 (normales)
187 reutiliza el andamiaje Woodpecker del 159 (DinD) y 189 es DinD; 188, 190 y
191 son systemd; 192 y 193 son k3s (193 con cert-manager v1.16.2 precargado).

| Lab | Título | Estado |
|-----|--------|--------|
| 187 | Pipeline lento (capas, .dockerignore, caché por hash) | 🟡 escrito; falta Docker |
| 188 | Runner de CI propio (usuario, efímero, timeout, sandbox systemd) | 🟡 escrito; falta Docker |
| 189 | Vistas previas por PR (proyecto/imagen/volumen por PR, gc) | 🟡 parseo de gc probado en local; falta Docker |
| 190 | Feature flags (fichero en caliente, hash estable, kill switch) | 🟡 módulo de flags probado en local contra los casos del check; falta Docker |
| 191 | Rollback con cambio de base de datos (expand/contract) | 🟡 migración y SQL de v1/v2 probados en local; falta Docker |
| 192 | Services sin tráfico (selector, targetPort, readiness, puerto con nombre) | ✅ probado en Docker: check inicial falla, solve, check final pasa |
| 193 | cert-manager (ClusterIssuer, dnsNames, Secret, renovación) | ✅ probado en Docker: check inicial falla, solve, check final pasa |

## Tanda 7 — labs 194–200 (normales)
Todos sobre k3s. El 197 levanta un segundo contenedor (`nodo2`, agente k3s
con la misma imagen) para tener dos nodos de verdad. El 199 precarga el
binario y las imágenes de k3s v1.32.0. El 200 reutiliza el andamiaje de
Argo CD del 167.

| Lab | Título | Estado |
|-----|--------|--------|
| 194 | Kustomize (base + overlays, configMapGenerator, selector inmutable) | ✅ probado en Docker: check inicial falla, solve, check final pasa |
| 195 | StatefulSets (headless, volumeClaimTemplates, identidad estable) | ✅ probado en Docker: check inicial falla, solve, check final pasa |
| 196 | RBAC con mínimo privilegio (CI, app sin token, monitor de clúster) | ✅ probado en Docker: check inicial falla, solve, check final pasa |
| 197 | Mantenimiento de nodos (drain sin --force, PDB, pod suelto; 2 nodos) | ✅ probado en Docker (2 nodos): check inicial falla, solve, check final pasa |
| 198 | Jobs y CronJobs (Forbid, deadlines, backoffLimit, ttl, timeZone, suspend) | 🟡 ediciones de la solución probadas contra los YAML plantados; falta Docker |
| 199 | Actualizar Kubernetes 1.31→1.32 (API eliminada, backup SQLite, sha256) | ✅ probado en Docker: check inicial falla, solve, check final pasa |
| 200 | App of Apps (Argo CD, raíz + hijas en git, alta/baja por commit) | 🟡 escrito; falta Docker |

## Tanda 8 — labs 201–207 (normales)
201 Estado remoto (backend) · 202 Pruebas de infraestructura · 203 Ansible · 204 Logs con Loki ·
205 Alertas con ruido · 206 Detección en ejecución (Falco, ▲) · 207 Backup de Kubernetes (Velero)

El 201 y el 202 usan Terraform con el proveedor local. El 203 levanta tres
contenedores (control, web1 y web2) con la misma imagen.

| Lab | Título | Estado |
|-----|--------|--------|
| 201 | Estado remoto de Terraform (backend http con auth y lock, secreto rotado) | ✅ probado en Docker: check inicial falla, solve, check 7/7 |
| 202 | Pruebas de infraestructura (terraform test, mutantes, ci/test.sh) | ✅ probado en Docker: check inicial falla, solve, check 6/6 (6 mutantes detectados) |
| 203 | Ansible: de script a rol (idempotencia, handlers, vars por nivel, deriva) | ✅ probado en Docker: check inicial falla, solve, check 9/9 |
| 204 | Logs con Loki (cardinalidad, tarjetas enmascaradas, multiline, LogQL) | ✅ probado en Docker: check inicial falla, solve, check 6/6 |

## Tanda 9 — labs 208–214
208 Costos con OpenCost · 209 Plantillas reutilizables de CI (▲) · 210 Actualizaciones automáticas (Renovate, ▲) ·
211 Canary con Argo Rollouts (▲) · 212 De Ingress a Gateway API (▲) · 213 Promoción entre ambientes (▲) ·
214 Secretos en GitOps (SOPS/ESO, ▲)

## Tanda 10 — labs 215–221 (▲)
215 OpenTofu · 216 Trazas con Tempo · 217 eBPF (▲ kernel) · 218 SBOM · 219 Firmar imágenes (cosign) ·
220 Política como código (Kyverno/OPA) · 221 Caos controlado (Toxiproxy)

## Tanda 11 — labs 222–226 (▲)
222 Camino estándar (golden path) · 223 Servir un modelo (Ollama+FastAPI) ·
224 RAG en producción (pgvector) · 225 Observabilidad de LLM · 226 Agente con permisos mínimos

## Pista P — Discos, volúmenes y montajes · labs 205–212 (a petición del autor)
Se intercalaron antes de la Tanda 8: **los labs 205–226 del plan que siguen pendientes pasan a 213–234** (Alertas con ruido = 213 … Agente con permisos mínimos = 234).
Base systemd + loop/dm/md; cada lab trae `clean.sh` (libera loop, device-mapper y md en el kernel de la VM al apagar).

| Lab | Tema | Estado |
|-----|------|--------|
| 205 | Ampliar un EBS con partición ext4 (growpart, kpartx -u, resize2fs) | ✅ probado en Docker: 3/6 → 6/6 |
| 206 | Más espacio con LVM + XFS (pvresize, vgextend, lvextend -r) | ✅ probado en Docker: 2/6 → 6/6 |
| 207 | /etc/fstab roto (findmnt --verify, mount -a, nofail) | ✅ probado en Docker: 1/7 → 7/7 |
| 208 | Disco externo sin restricciones (nosuid, nodev, noexec) | ✅ probado en Docker: 2/14 → 11/11 |
| 209 | /tmp, /var/tmp y /dev/shm sin exec (tmpfs, bind, evidencia) | ✅ probado en Docker: 1/12 → 12/12 |
| 210 | df lleno, du vacío (montaje que oculta, lsof +L1) | ✅ probado en Docker: 3/7 → 7/7 |
| 211 | Bóveda LUKS: rotar claves, cabecera, crypttab | ✅ probado en Docker: 1/7 → 10/10 |
| 212 | RAID1 degradado (mdadm --add, mdadm.conf) | ✅ probado en Docker: 2/6 → 6/6 |
