FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 openssl procps grep \
      vim-tiny nano less curl \
      sudo ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista
COPY setup/plant.sh /opt/lab/plant.sh
COPY setup/panel.py /opt/lab/panel.py
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN chmod +x /opt/lab/plant.sh /opt/lab/check.sh
CMD /opt/lab/plant.sh; exec ttyd -p 7681 -W -t fontSize=14 bash -lc 'su - analista'
