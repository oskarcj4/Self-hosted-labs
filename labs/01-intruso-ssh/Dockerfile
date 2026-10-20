FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      procps iproute2 net-tools lsof psmisc file \
      cron openssh-server \
      vim-tiny nano less grep curl \
      sudo ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Terminal web (ttyd): se descarga el binario estatico en el build.
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista
COPY setup/plant.sh /opt/lab/plant.sh
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN chmod +x /opt/lab/plant.sh /opt/lab/check.sh
# Al arrancar: planta el escenario y sirve la terminal web en :7681.
CMD /opt/lab/plant.sh; exec ttyd -p 7681 -W -t fontSize=14 bash -lc 'su - analista'
