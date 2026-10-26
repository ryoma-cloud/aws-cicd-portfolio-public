FROM python:3.13-slim
WORKDIR /app
COPY requirements.lock /app/requirements.lock
RUN pip install --no-cache-dir -r requirements.lock
COPY common /app/common
COPY web /app/web
COPY migrations /app/migrations
COPY tools /app/tools
COPY certs /app/certs
ENV PYTHONPATH=/app DB_SSLROOTCERT=/app/certs/global-bundle.pem PYTHONDONTWRITEBYTECODE=1
USER 65532:65532
EXPOSE 8080
CMD ["gunicorn","--bind=0.0.0.0:8080","--workers=1","--threads=2","--worker-tmp-dir=/dev/shm","--error-logfile=-","web.app:app"]
