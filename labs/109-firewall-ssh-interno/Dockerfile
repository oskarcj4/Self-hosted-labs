# Lab 109 — target: firewall que se puede saltar hasta el SSH interno.
# Estilo máquina HTB fácil/media. El firewall debería dejar solo la web (80) y
# bloquear SSH (22) y la consola admin interna (8080). Dos errores lo dejan
# saltar: la política por defecto es permisiva y la regla que debía tapar SSH
# está mal escrita. Banderas user (vía SSH) y root (vía consola interna).
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 iptables iproute2 procps curl ncat sudo openssh-server \
      grep file vim-tiny nano less ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# iptables-legacy: en contenedor es el backend fiable bajo Docker Desktop.
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# analista: shell en modo blue (arreglar el firewall).
# soporte: cuenta de mantenimiento accesible por SSH (credencial de fábrica).
# svc: dueño de la consola admin interna (8080), que corre como root aparte.
RUN useradd -m -s /bin/bash analista && echo 'analista:analista' | chpasswd \
    && useradd -m -s /bin/bash soporte  && echo 'soporte:soporte'   | chpasswd \
    && useradd -r -s /usr/sbin/nologin svc
COPY setup/ /opt/lab/setup/
COPY check.sh check-blue.sh /opt/lab/
COPY RETO.md /RETO.md
RUN chmod 0755 /opt/lab/*.sh /opt/lab/setup/*.sh /opt/lab/setup/**/*.sh 2>/dev/null; true
CMD ["bash", "/opt/lab/setup/boot.sh"]
