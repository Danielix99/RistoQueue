FROM python:3.12-slim AS builder

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY app/worker/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

ARG GIT_SHA=unknown
ENV VERSION=${GIT_SHA} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --gid 10001 app \
 && useradd --uid 10001 --gid 10001 --create-home app

WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/worker ./

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python /app/healthcheck.py || exit 1

USER 10001:10001

CMD ["python", "worker.py"]
