# Lab 187 — host Linux con su propio Docker Engine (Docker-in-Docker), un
# registro de imágenes local y Woodpecker CLI (pipelines, backend local).
# Nada toca el Docker de tu máquina. Las 3 primeras capas son idénticas a las
# del lab 152 y la cuarta, del 159: Docker las comparte.
FROM docker:27.5.1-dind
RUN apk add --no-cache bash curl jq python3 sudo nano vim less coreutils \
      procps iproute2 skopeo shadow ncurses findutils grep
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
RUN mkdir -p /opt/images \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/python:3.12-slim-bookworm \
         docker-archive:/opt/images/python-slim.tar:python:3.12-slim-bookworm
# Registro local (registry:2), Woodpecker CLI y gitleaks (escaneo de secretos).
RUN apk add --no-cache git py3-yaml \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/registry:2 docker-archive:/opt/images/registry.tar:registry:2 \
    && curl -fsSL https://github.com/woodpecker-ci/woodpecker/releases/download/v2.8.3/woodpecker-cli_linux_amd64.tar.gz \
       | tar xz -C /usr/local/bin woodpecker-cli \
    && curl -fsSL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz \
       | tar xz -C /usr/local/bin gitleaks \
    && chmod 0755 /usr/local/bin/woodpecker-cli /usr/local/bin/gitleaks \
    && git config --system safe.directory '*'
# Dependencias de la app en wheels (sin red): python-dateutil, six, asn1crypto.
RUN apk add --no-cache py3-pip \
    && python3 -m pip download --no-deps --only-binary=:all: -d /opt/wheels \
         python-dateutil==2.9.0.post0 six==1.16.0 asn1crypto==1.5.1
RUN adduser -D -s /bin/bash analista \
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
    && install -m 0755 /opt/lab/setup/ci-run /usr/local/bin/ci-run \
    && install -m 0755 /opt/lab/setup/ci-logs /usr/local/bin/ci-logs \
    && chmod 0755 /opt/lab/check.sh
ENTRYPOINT []
CMD ["/opt/lab/boot.sh"]
