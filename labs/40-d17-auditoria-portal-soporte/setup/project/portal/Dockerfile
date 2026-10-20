FROM python:3.12-alpine
ENV PORTAL_ENV=prod \
    ZENDESK_API_TOKEN=zd_8Hq2LmX4vR7tP9kW3nB6
WORKDIR /app
COPY app.py .
RUN mkdir -p /app/uploads
EXPOSE 8000
CMD ["python", "-u", "app.py"]
