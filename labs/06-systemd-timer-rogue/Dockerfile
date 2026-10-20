FROM debian:12
ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv \
      procps grep curl ca-certificates sudo \
      nano vim-tiny less \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista
COPY setup/plant.sh /opt/lab/plant.sh
COPY setup/beacon.sh /opt/lab/.beacon.sh
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
COPY setup/ttyd.service /etc/systemd/system/ttyd.service
COPY setup/labsetup.service /etc/systemd/system/labsetup.service
RUN chmod +x /opt/lab/plant.sh /opt/lab/.beacon.sh /opt/lab/check.sh \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
