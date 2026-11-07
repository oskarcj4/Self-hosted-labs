# Lab 174 — Debian 12 con systemd real.
# Las 3 primeras capas son idénticas a las de los labs 24-38, 54+, 137, 143 y 157: Docker las comparte.
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
# Escáneres: trivy (CVEs, con su base de datos ya descargada: funciona sin red)
# y semgrep (análisis estático con reglas locales). Más git.
ENV TRIVY_CACHE_DIR=/opt/trivy-cache TRIVY_SKIP_DB_UPDATE=true TRIVY_SKIP_JAVA_DB_UPDATE=true \
    TRIVY_OFFLINE_SCAN=true TRIVY_NO_PROGRESS=true TRIVY_SKIP_VERSION_CHECK=true \
    SEMGREP_SEND_METRICS=off SEMGREP_ENABLE_VERSION_CHECK=0
RUN apt-get update && apt-get install -y --no-install-recommends git python3-venv python3-pytest \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v0.74.0/trivy_0.74.0_Linux-64bit.tar.gz \
      | tar xz -C /usr/local/bin trivy \
    && TRIVY_SKIP_DB_UPDATE=false TRIVY_OFFLINE_SCAN=false trivy image --download-db-only --no-progress \
    && chmod -R a+rwX /opt/trivy-cache \
    && python3 -m venv /opt/semgrep && /opt/semgrep/bin/pip install --no-cache-dir semgrep==1.99.0 \
    && ln -s /opt/semgrep/bin/semgrep /usr/local/bin/semgrep \
    && printf '%s\n' 'export TRIVY_CACHE_DIR=/opt/trivy-cache' 'export TRIVY_SKIP_DB_UPDATE=true' \
      'export TRIVY_SKIP_JAVA_DB_UPDATE=true' 'export TRIVY_OFFLINE_SCAN=true' 'export TRIVY_NO_PROGRESS=true' \
      'export TRIVY_SKIP_VERSION_CHECK=true' 'export SEMGREP_SEND_METRICS=off' 'export SEMGREP_ENABLE_VERSION_CHECK=0' \
      > /etc/profile.d/escaneres.sh
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
