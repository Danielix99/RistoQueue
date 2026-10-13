"""RistoQueue API - riceve gli ordini del ristorante e li mette in coda su Redis."""
import os
import sys
import uuid
import json
import time

import redis
from flask import Flask, jsonify, request

REDIS_HOST = os.environ.get("REDIS_HOST")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
API_KEY = os.environ.get("API_KEY")
QUEUE_NAME = os.environ.get("QUEUE_NAME", "orders")
APP_VERSION = os.environ.get("APP_VERSION", "dev")
PORT = int(os.environ.get("PORT", "8080"))


def create_app(redis_client=None):
    app = Flask(__name__)
    r = redis_client or redis.Redis(host=REDIS_HOST, port=REDIS_PORT,
                                    socket_connect_timeout=2, decode_responses=True)

    @app.get("/healthz")
    def healthz():
        # liveness: il processo risponde
        return jsonify(status="ok")

    @app.get("/readyz")
    def readyz():
        # readiness: Redis raggiungibile
        try:
            r.ping()
            return jsonify(status="ready")
        except redis.RedisError as exc:
            return jsonify(status="not-ready", error=str(exc)), 503

    @app.post("/orders")
    def create_order():
        if request.headers.get("X-Api-Key") != API_KEY:
            return jsonify(error="unauthorized"), 401
        body = request.get_json(silent=True) or {}
        if not body.get("dish"):
            return jsonify(error="campo 'dish' obbligatorio"), 400
        order = {"id": str(uuid.uuid4()), "dish": body["dish"],
                 "table": body.get("table", 0), "ts": time.time()}
        r.rpush(QUEUE_NAME, json.dumps(order))
        r.incr("stats:received")
        return jsonify(order), 201

    @app.get("/stats")
    def stats():
        return jsonify(
            version=APP_VERSION,
            queue=QUEUE_NAME,
            queued=r.llen(QUEUE_NAME),
            received=int(r.get("stats:received") or 0),
            processed=int(r.get("stats:processed") or 0),
        )

    return app


if __name__ == "__main__":
    missing = [v for v in ("REDIS_HOST", "API_KEY") if not os.environ.get(v)]
    if missing:
        print(f"ERRORE: variabili d'ambiente mancanti: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    create_app().run(host="0.0.0.0", port=PORT)
