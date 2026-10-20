FROM python:3-alpine
ENV DEBUG=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY . /app
EXPOSE 5678
CMD ["python", "-u", "worker.py"]
