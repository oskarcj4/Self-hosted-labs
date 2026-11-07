# Lab 201 — Debian 12 con systemd real.
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
# git.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*
# Terraform y sus proveedores en un espejo local (/usr/share/terraform/plugins):
# 'terraform init' funciona sin red.
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.11.4/terraform_1.11.4_linux_amd64.zip -o /tmp/tf.zip \
    && python3 -c "import zipfile; zipfile.ZipFile('/tmp/tf.zip').extract('terraform', '/usr/local/bin')" \
    && chmod 0755 /usr/local/bin/terraform && rm -f /tmp/tf.zip \
    && mkdir -p /tmp/m \
    && printf '%s\n' 'terraform {' '  required_providers {' \
         '    kubernetes = { source = "hashicorp/kubernetes", version = "2.35.1" }' \
         '    null       = { source = "hashicorp/null", version = "3.2.3" }' \
         '    local      = { source = "hashicorp/local", version = "2.5.2" }' '  }' '}' > /tmp/m/main.tf \
    && terraform -chdir=/tmp/m providers mirror /usr/share/terraform/plugins \
    && rm -rf /tmp/m
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
