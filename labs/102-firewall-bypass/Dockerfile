# Lab 102 — target: firewall mal configurado (se puede saltar). Estilo HTB.
# Dos servicios internos que el firewall debería bloquear, pero dos reglas
# erróneas dejan pasar al atacante. Banderas user (9001) y root (9002).
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 iptables iproute2 procps curl ncat sudo \
      grep file vim-tiny nano less ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# iptables-legacy: en contenedor es el backend fiable bajo Docker Desktop.
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# analista: shell en modo blue. svc: dueño del servicio de usuario (9001).
RUN useradd -m -s /bin/bash analista && echo 'analista:analista' | chpasswd \
    && useradd -r -s /usr/sbin/nologin svc
COPY setup/ /opt/lab/setup/
COPY check.sh check-blue.sh /opt/lab/
COPY RETO.md /RETO.md
RUN chmod 0755 /opt/lab/*.sh /opt/lab/setup/*.sh /opt/lab/setup/**/*.sh 2>/dev/null; true
CMD ["bash", "/opt/lab/setup/boot.sh"]
