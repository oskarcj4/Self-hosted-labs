#!/usr/bin/env bash
# Planta el escenario del Lab 18: firewall abierto (política ACCEPT, sin reglas).
set -e
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true
echo "Lab 18 plantado. Entra como analista y lee /RETO.md"
