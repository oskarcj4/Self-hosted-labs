# Verificar paquetes antes de instalar

> Operaciones · cadena de suministro · GPG · SHA256SUMS · CI

## Escenario

Estás en `ci-01`, un runner de CI. Hay que instalar `kvtool` desde el mirror
interno de artefactos... pero el mirror tuvo un acceso no autorizado esta
semana. Lee `~/ticket/CHG-7702.txt`.

| Máquina            | IP          |
|--------------------|-------------|
| `ci-01`            | 10.76.77.10 (esta terminal) |
| `artifacts.interno`| 10.76.77.20 (mirror HTTP)   |

No te fíes de lo que sirve el mirror. El fabricante publica la **huella** de
su clave en su web (un canal independiente), y está en el ticket. Esa huella
es tu única ancla de confianza.

## Objetivos

1. Instala en `/usr/local/bin/kvtool` la versión más reciente que sea
   **auténtica** (firmada por el fabricante).
2. Un instalador reutilizable `/usr/local/bin/install-tool.sh <versión>` que:
   - baje `tar.gz`, `SHA256SUMS` y `SHA256SUMS.asc` de
     `${ARTIFACTS_URL:-http://artifacts.interno/kvtool}/<versión>/`;
   - verifique la firma de `SHA256SUMS` **sólo** contra la clave del
     fabricante (su huella, fijada en el runner — no la que diga el mirror);
   - verifique el **SHA-256** del `tar.gz` contra `SHA256SUMS`;
   - si algo falla, salga con error **sin** tocar el kvtool instalado.

El validador probará tu instalador contra el mirror real y contra mirrors
locales manipulados (vía `ARTIFACTS_URL`).

## Comandos que te pueden servir

```bash
curl -s http://artifacts.interno/kvtool/ ; curl -s http://artifacts.interno/kvtool/LATEST
curl -sO http://artifacts.interno/kvtool/KEYS.asc
gpg --show-keys KEYS.asc                      # ¿qué claves trae? ¿qué huella?
# importa a un llavero propio y fija SÓLO la huella del fabricante:
export GNUPGHOME=$(mktemp -d)
gpg --import KEYS.asc
gpg --verify SHA256SUMS.asc SHA256SUMS         # ¿con qué clave está firmado?
sha256sum -c SHA256SUMS
```

Pista: `gpg --verify` dice OK si la firma es válida para *cualquier* clave
importada. No basta: comprueba que la clave firmante es **la huella del
fabricante**. Mira `gpg --verify --status-fd=1 ...` (`VALIDSIG <huella>`).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
