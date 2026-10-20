FROM python:3.12-alpine
# Token de la pasarela de notificaciones (se puede cambiar con --build-arg)
ARG NOTIFY_TOKEN=ntf_live_2c8e5a17f9b4
ENV NOTIFY_TOKEN=$NOTIFY_TOKEN
WORKDIR /app
COPY app.py .
RUN echo "$NOTIFY_TOKEN" > /app/.token
CMD ["python", "-u", "app.py"]
