# Lab 74 — host Linux con su propio Docker Engine (Docker-in-Docker).
# El escenario (una imagen de app que hay que escanear) vive DENTRO de este
# contenedor: no toca el Docker de tu máquina. Las 4 primeras capas son
# idénticas a los labs 39-53/71: Docker las comparte.
FROM docker:27.5.1-dind
RUN apk add --no-cache bash curl jq python3 sudo nano vim less coreutils \
      procps iproute2 iptables skopeo shadow ncurses findutils grep
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# Imágenes base del escenario, precargadas para no depender de Docker Hub:
#  - la vieja (python 3.12 sobre Alpine 3.18): llena de CVEs.
#  - la actual (python 3.12-alpine): la de la solución.
RUN mkdir -p /opt/images \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/python:3.12.0-alpine3.18 \
         docker-archive:/opt/images/python-vieja.tar:python:3.12.0-alpine3.18 \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/python:3.12-alpine \
         docker-archive:/opt/images/python-actual.tar:python:3.12-alpine
RUN addgroup -S docker 2>/dev/null; adduser -D -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && addgroup analista docker \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista \
    && chmod 0440 /etc/sudoers.d/analista
# Grype (escáner de vulnerabilidades), con versión fijada y checksum verificado.
# No nos fiamos del instalador remoto: bajamos binario + checksums y comparamos.
ARG GRYPE_VERSION=0.104.1
ARG GRYPE_SHA256=2cb820b6c81f88fd6aff3fb4ca5a7161e9ab70af0f27fc5e99cd16deb987cd5f
RUN cd /tmp \
    && curl -fsSLO https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_amd64.tar.gz \
    && echo "${GRYPE_SHA256}  grype_${GRYPE_VERSION}_linux_amd64.tar.gz" | sha256sum -c - \
    && tar -xzf grype_${GRYPE_VERSION}_linux_amd64.tar.gz grype \
    && install -m 0755 grype /usr/local/bin/grype \
    && rm -rf /tmp/grype*
# Base de datos de vulnerabilidades, horneada para poder escanear SIN red.
ENV GRYPE_DB_CACHE_DIR=/opt/grype/db \
    GRYPE_DB_AUTO_UPDATE=false \
    GRYPE_DB_VALIDATE_AGE=false
RUN grype db update && grype db status
RUN printf 'export GRYPE_DB_CACHE_DIR=/opt/grype/db\nexport GRYPE_DB_AUTO_UPDATE=false\nexport GRYPE_DB_VALIDATE_AGE=false\n' \
      > /etc/profile.d/grype.sh
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/boot.sh /opt/lab/boot.sh \
    && install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh
ENTRYPOINT []
CMD ["/opt/lab/boot.sh"]
