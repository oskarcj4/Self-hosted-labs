# Lab 52 — host Linux con su propio Docker Engine (Docker-in-Docker).
# El escenario es un stack Compose que corre DENTRO de este contenedor: nada
# toca el Docker de tu máquina. Las 4 primeras capas son idénticas en los labs
# 39-53: Docker las comparte.
FROM docker:27.5.1-dind
RUN apk add --no-cache bash curl jq python3 sudo nano vim less coreutils \
      procps iproute2 iptables skopeo shadow ncurses findutils grep
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# Imagen base de los servicios del escenario, precargada para no depender de
# Docker Hub al plantar (se importa con 'docker load' al arrancar).
RUN mkdir -p /opt/images \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/python:3.12-alpine \
         docker-archive:/opt/images/python.tar:python:3.12-alpine
RUN addgroup -S docker 2>/dev/null; adduser -D -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && addgroup analista docker \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista \
    && chmod 0440 /etc/sudoers.d/analista
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/boot.sh /opt/lab/boot.sh \
    && install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh
ENTRYPOINT []
CMD ["/opt/lab/boot.sh"]
