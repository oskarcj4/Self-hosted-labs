# Lab 142 — host Linux con su propio Docker Engine (Docker-in-Docker).
# La imagen de la API se construye y corre DENTRO de este contenedor: nada toca
# el Docker de tu máquina. Las 2 primeras capas son idénticas a las de los
# labs 39-53: Docker las comparte.
FROM docker:27.5.1-dind
RUN apk add --no-cache bash curl jq python3 sudo nano vim less coreutils \
      procps iproute2 iptables skopeo shadow ncurses findutils grep
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# Imágenes base precargadas (se importan con 'docker load' al arrancar):
# la de compilación de Go (Debian completo, ~800 MB) y distroless static.
RUN mkdir -p /opt/images \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/golang:1.22.5-bookworm \
         docker-archive:/opt/images/golang.tar:golang:1.22.5-bookworm \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://gcr.io/distroless/static-debian12:nonroot \
         docker-archive:/opt/images/distroless.tar:gcr.io/distroless/static-debian12:nonroot
# trivy (escáner de CVEs) con su base de datos descargada, y syft (SBOM).
ENV TRIVY_CACHE_DIR=/opt/trivy-cache
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v0.74.0/trivy_0.74.0_Linux-64bit.tar.gz \
      | tar xz -C /usr/local/bin trivy \
    && curl -fsSL https://github.com/anchore/syft/releases/download/v1.18.1/syft_1.18.1_linux_amd64.tar.gz \
      | tar xz -C /usr/local/bin syft \
    && trivy image --download-db-only --no-progress \
    && chmod -R a+rwX /opt/trivy-cache
RUN printf '%s\n' 'export TRIVY_CACHE_DIR=/opt/trivy-cache' 'export TRIVY_SKIP_DB_UPDATE=true' \
      'export TRIVY_SKIP_JAVA_DB_UPDATE=true' 'export TRIVY_OFFLINE_SCAN=true' 'export TRIVY_NO_PROGRESS=true' \
      'export TRIVY_SKIP_VERSION_CHECK=true' \
      > /etc/profile.d/trivy.sh
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
