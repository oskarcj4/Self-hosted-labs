# Imagen base compartida por los labs: un servidor Linux "víctima/auditor"
# con las herramientas de respuesta a incidentes y recon preinstaladas.
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      procps iproute2 net-tools lsof \
      cron curl wget \
      vim-tiny less nano \
      psmisc file \
      ca-certificates \
      iputils-ping dnsutils \
      python3 python3-pip \
      openssh-server \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Usuario no-root para trabajar (sudo disponible para los pasos de erradicación)
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista

WORKDIR /root
