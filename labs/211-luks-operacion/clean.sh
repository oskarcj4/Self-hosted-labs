#!/usr/bin/env bash
# Libera loops, device-mapper y md de ESTE lab (imágenes tc211-*).
for L in $(losetup -a 2>/dev/null | grep "/tc211-" | cut -d: -f1); do
  lsblk -nrpo NAME,TYPE "$L" 2>/dev/null | tac | while read -r n t; do
    [ "$n" = "$L" ] && continue
    for m in $(findmnt -rno TARGET -S "$n" 2>/dev/null); do umount -l "$m" 2>/dev/null; done
    case "$t" in
      raid*) mdadm --stop "$n" >/dev/null 2>&1 ;;
      *)     dmsetup remove --force "$(lsblk -dnro NAME "$n" 2>/dev/null)" >/dev/null 2>&1 ;;
    esac
  done
  for m in $(findmnt -rno TARGET -S "$L" 2>/dev/null); do umount -l "$m" 2>/dev/null; done
  losetup -d "$L" 2>/dev/null
done
exit 0
