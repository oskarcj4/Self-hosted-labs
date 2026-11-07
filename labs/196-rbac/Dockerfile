# Lab 196 — Debian 12 con systemd real + k3s (Kubernetes de un nodo) DENTRO del
# contenedor: nada toca tu máquina. Las 3 primeras capas son idénticas a las de
# los labs 24-38, 54+ y 157, y las 2 siguientes a las de los labs de Kubernetes
# (161+): Docker las comparte.
FROM debian:12
ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus \
      python3 iproute2 procps psmisc lsof file acl \
      curl ca-certificates sudo nano vim-tiny less \
      nginx-light cron openssh-server logrotate \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl disable nginx cron ssh >/dev/null 2>&1 || true
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista \
    && chmod 0440 /etc/sudoers.d/analista
# Kubernetes ligero: k3s (trae kubectl, crictl y ctr), sus imágenes de sistema
# (airgap: arranca sin red) y Helm.
RUN apt-get update && apt-get install -y --no-install-recommends \
      skopeo zstd jq git bash-completion iptables \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://github.com/k3s-io/k3s/releases/download/v1.31.4%2Bk3s1/k3s" \
         -o /usr/local/bin/k3s && chmod 0755 /usr/local/bin/k3s \
    && for b in kubectl crictl ctr; do ln -s k3s /usr/local/bin/$b; done \
    && mkdir -p /var/lib/rancher/k3s/agent/images \
    && curl -fsSL "https://github.com/k3s-io/k3s/releases/download/v1.31.4%2Bk3s1/k3s-airgap-images-amd64.tar.zst" \
         -o /var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar.zst \
    && curl -fsSL https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz \
       | tar xz -C /usr/local/bin --strip-components=1 linux-amd64/helm
# Imágenes de las cargas de trabajo: k3s las importa solo al arrancar.
RUN cd /var/lib/rancher/k3s/agent/images \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/busybox:1.36 docker-archive:busybox.tar:busybox:1.36 \
    && skopeo copy --override-os linux --override-arch amd64 \
         docker://docker.io/library/nginx:1.27-alpine docker-archive:nginx.tar:nginx:1.27-alpine
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && install -m 0644 /opt/lab/setup/k8s-profile.sh /etc/profile.d/k8s.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service \
          /opt/lab/setup/k3s.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service k3s.service
CMD ["/sbin/init"]
