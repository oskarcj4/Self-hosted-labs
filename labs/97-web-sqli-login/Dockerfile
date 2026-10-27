# Lab 97 — app web vulnerable (SQLi en login). Estilo HTB fácil.
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 curl jq procps grep file \
      vim-tiny nano less ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# analista NO tiene sudo: la flag la lee solo el usuario 'app'. Hay que explotar
# (o arreglar) la app, no leer el fichero a mano.
RUN useradd -m -s /bin/bash analista && echo 'analista:analista' | chpasswd \
    && useradd -r -s /usr/sbin/nologin app
COPY setup/ /opt/lab/setup/
COPY check.sh check-red.sh check-blue.sh /opt/lab/
COPY RETO.md /RETO.md
RUN chmod 0755 /opt/lab/*.sh /opt/lab/setup/*.sh
CMD /opt/lab/setup/plant.sh; exec ttyd -p 7681 -W -t fontSize=14 bash -lc 'su - analista'
