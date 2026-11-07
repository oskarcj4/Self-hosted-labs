#!/usr/bin/env bash
# Casos ocultos del lab 182. Uso: casos.sh SCRIPT  (se ejecuta como analista)
SCRIPT=$1
base=$(mktemp -d /tmp/tc182-XXXX)
trap 'rm -rf "$base"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fallos=0
n=0

repo(){ n=$((n+1)); d="$base/r$n"; mkdir -p "$d"; cd "$d" && git init -q && echo "$1"; }
c(){ echo "$RANDOM" >> f; git add f; git commit -qm "$1" ${2:+-m "$2"}; }
t(){ git tag -a "$1" -m "$1"; }
espera(){ # espera DESCRIPCIÓN SALIDA_ESPERADA CÓDIGO_ESPERADO
  out=$("$SCRIPT" 2>/dev/null); rc=$?
  out=$(echo "$out" | tr -d '[:space:]')
  if [ "$out" = "$2" ] && [ "$rc" = "$3" ]; then echo "OK    $1"
  else echo "FALLO $1: esperado '$2' (código $3), tu script: '$out' (código $rc)"; fallos=$((fallos+1)); fi
}

repo >/dev/null; c "feat: a"; t v1.2.3; c "fix: b"; c "docs: c"
espera "sólo fix desde v1.2.3 -> 1.2.4" 1.2.4 0

repo >/dev/null; c "feat: a"; t v1.2.3; c "fix(x): b"; c "feat(api): c"; c "chore: d"
espera "feat con ámbito -> 1.3.0" 1.3.0 0

repo >/dev/null; c "feat: a"; t v1.2.3; c "feat(api)!: quita /v1"
espera "feat! -> 2.0.0" 2.0.0 0

repo >/dev/null; c "feat: a"; t v3.1.0; c "fix: b" "Detalle.

BREAKING CHANGE: cambia el formato"
espera "BREAKING CHANGE en el cuerpo de un fix -> 4.0.0" 4.0.0 0

repo >/dev/null; c "feat: a"; t v0.4.2; c "refactor!: nueva API"
espera "incompatible en 0.y.z -> 0.5.0" 0.5.0 0

repo >/dev/null; c "feat: a"; t v1.0.0; c "docs: b"; c "ci: c"; c "test: d"
espera "sin commits que publiquen -> nada y código 1" "" 1

repo >/dev/null; c "fix: a"; c "feat: b"
espera "sin etiquetas, parte de 0.0.0 -> 0.1.0" 0.1.0 0

repo >/dev/null; c "a: x"; t v1.9.0; c "b"; t v1.10.0; git tag deploy-prod; c "c"; t release-final; git tag -a v1.2.0 -m old HEAD~2; c "perf: más rápido"
espera "la etiqueta más alta es v1.10.0 (no v1.9.0 ni la más reciente) -> 1.10.1" 1.10.1 0

repo >/dev/null; c "feat: a"; t v2.0.0; c "fix: arreglo"; c "docs: menciona feat: y fix! en el texto"
espera "sólo cuenta el tipo al principio del asunto -> 2.0.1" 2.0.1 0

repo >/dev/null; c "feat: a"; t v1.0.0; c "fixup: x"; c "feature: y"
espera "fixup/feature no son fix/feat -> nada y código 1" "" 1

exit $((fallos > 0))
