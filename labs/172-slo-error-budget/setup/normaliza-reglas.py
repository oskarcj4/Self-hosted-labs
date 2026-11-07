#!/usr/bin/env python3
"""Copia las reglas del alumno quitando annotations y dejando sólo la etiqueta
severity en las alertas, para que los tests ocultos no dependan de los textos."""
import sys, yaml
src, dst = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(src, encoding="utf-8")) or {}
for g in doc.get("groups") or []:
    for r in g.get("rules") or []:
        if "alert" in r:
            r.pop("annotations", None)
            sev = (r.get("labels") or {}).get("severity")
            r["labels"] = {"severity": sev} if sev else {}
            if not r["labels"]:
                r.pop("labels")
yaml.safe_dump(doc, open(dst, "w", encoding="utf-8"), allow_unicode=True, sort_keys=False)
