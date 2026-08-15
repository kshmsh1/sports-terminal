FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --create-home --uid 10001 sports-terminal

COPY requirements.txt ./requirements.txt
RUN python -m pip install --upgrade pip && \
    python -m pip install -r requirements.txt

COPY app ./app
COPY scripts ./scripts
COPY migrations ./migrations
COPY start_production.sh ./start_production.sh

RUN chmod 0555 /app/start_production.sh && \
    chown -R sports-terminal:sports-terminal /app

USER sports-terminal

ENV SPORTS_TERMINAL_ENV=production \
    SPORTS_TERMINAL_AUTO_MIGRATE=false \
    SPORTS_TERMINAL_ENFORCE_AUTH=true \
    SPORTS_TERMINAL_RATE_LIMITS=true \
    SPORTS_TERMINAL_RATE_LIMIT_BACKEND=database \
    SPORTS_TERMINAL_BILLING_MODE=disabled \
    SPORTS_TERMINAL_HSTS=true

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"

CMD ["/app/start_production.sh"]
