FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

WORKDIR /app

COPY requirements.txt ./requirements.txt
RUN python -m pip install --upgrade pip && \
    python -m pip install -r requirements.txt

COPY app ./app
COPY scripts ./scripts

RUN mkdir -p /data && \
    useradd --create-home --uid 10001 sports-terminal && \
    chown -R sports-terminal:sports-terminal /app /data

USER sports-terminal

ENV SPORTS_TERMINAL_DB_PATH=/data/sports_terminal.db \
    SPORTS_TERMINAL_CORS_ORIGINS=http://localhost:5000 \
    SPORTS_TERMINAL_ENFORCE_AUTH=true \
    SPORTS_TERMINAL_RATE_LIMITS=true

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"

CMD ["sh", "-c", "uvicorn app.main_launch:app --host 0.0.0.0 --port ${PORT} --workers ${WEB_CONCURRENCY:-2}"]
