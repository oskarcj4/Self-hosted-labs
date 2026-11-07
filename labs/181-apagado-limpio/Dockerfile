# Lab 181 — host Linux con su propio Docker Engine (Docker-in-Docker).
# Las 2 primeras capas son idénticas a las de los labs 39-53, 142 y 152: Docker las comparte.
FROM docker:27.5.1-dind
RUN apk add --no-cache bash curl jq python3 sudo nano vim less coreutils       procps iproute2 skopeo shadow ncurses findutils grep
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64       -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# Imagen base precargada (se importa con 'docker load' al arrancar): así el
# alumno construye sin depender de la red. Misma capa que el lab 152.
RUN mkdir -p /opt/images \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/python:3.12-slim-bookworm \
         docker-archive:/opt/images/python-slim.tar:python:3.12-slim-bookworm
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
    && chmod 0755 /opt/lab/check.sh
ENTRYPOINT []
CMD ["/opt/lab/boot.sh"]
