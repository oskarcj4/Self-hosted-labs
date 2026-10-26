# Lab 104 — target: panel con fuga de artefacto de build + modo debug. Estilo HTB.
# Dos vías de red: un backup del código en el webroot (bandera user) y un
# /admin en modo debug que no pide token (bandera root).
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 iproute2 procps curl ca-certificates sudo \
      grep file vim-tiny nano less \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# analista: shell en modo blue. svc: dueño del servicio web.
RUN useradd -m -s /bin/bash analista && echo 'analista:analista' | chpasswd \
    && useradd -r -s /usr/sbin/nologin svc
COPY setup/ /opt/lab/setup/
COPY check.sh check-blue.sh /opt/lab/
COPY RETO.md /RETO.md
RUN chmod 0755 /opt/lab/*.sh /opt/lab/setup/*.sh 2>/dev/null; true
CMD ["bash", "/opt/lab/setup/boot.sh"]
