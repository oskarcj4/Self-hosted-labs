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
159 Pipeline completo (test/build/escaneo/publicar/desplegar/rollback) ·
160 Monorepo (construir/desplegar solo lo que cambió) · 161 CrashLoopBackOff ·
162 Pods en Pending · 163 Requests y límites (QoS) · 164 Helm · 165 NetworkPolicies

## Tanda 3 — Kubernetes + IaC (★) · labs 166–172
166 Escalado (HPA/KEDA) · 167 Argo CD fuera de sincronía · 168 Terraform lock/drift ·
169 Módulos reutilizables · 170 OpenTelemetry · 171 Métricas RED · 172 SLO y presupuesto de error

## Tanda 4 — Observabilidad, seguridad y confiabilidad (★) · labs 173–179
173 Verde, pero fallando · 174 Escaneo en el pipeline (Trivy/Semgrep) · 175 Vault ·
176 Backup/restauración PostgreSQL (PITR) · 177 Pruebas de carga (k6) ·
178 Incidente completo (postmortem) · 179 Portal Backstage

## Tanda 5 — labs 180–186
180 Automatizar con Python y Bash (★) · 181 Apagado limpio (SIGTERM/PID 1) ·
182 Versionado y releases (SemVer) · 183 Compose para un VPS · 184 Imágenes multiarquitectura (buildx) ·
185 Logs para producción · 186 Pruebas inestables (flaky)

## Tanda 6 — labs 187–193 (normales)
187 Pipeline lento · 188 Runners propios · 189 Ambientes de vista previa · 190 Feature flags ·
191 Rollback con cambio de base de datos · 192 Service sin tráfico · 193 cert-manager

## Tanda 7 — labs 194–200 (normales)
194 Kustomize · 195 StatefulSets · 196 RBAC · 197 Mantenimiento de nodos (drain/PDB) ·
198 Jobs y CronJobs · 199 Actualizar versión de Kubernetes · 200 App of Apps

## Tanda 8 — labs 201–207
201 Estado remoto (backend) · 202 Pruebas de infraestructura · 203 Ansible · 204 Logs con Loki ·
205 Alertas con ruido · 206 Detección en ejecución (Falco, ▲) · 207 Backup de Kubernetes (Velero)

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
