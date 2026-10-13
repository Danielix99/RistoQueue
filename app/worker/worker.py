"""RistoQueue Worker - preleva gli ordini dalla coda Redis e li "cucina"."""
import os
import sys
import json
import time
import socket
import pathlib

import redis

REDIS_HOST = os.environ.get("REDIS_HOST")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
QUEUE_NAME = os.environ.get("QUEUE_NAME", "orders-queue")
PROCESS_DELAY = float(os.environ.get("PROCESS_DELAY", "0.5"))
WORKER_ID = os.environ.get("WORKER_ID", socket.gethostname())
HEARTBEAT_FILE = pathlib.Path(os.environ.get("HEARTBEAT_FILE", "/tmp/heartbeat"))


def heartbeat():
    HEARTBEAT_FILE.write_text(str(time.time()))


def process_one(r, timeout=5):
    """Preleva e processa un ordine. Ritorna l'ordine o None se la coda e' vuota."""
    item = r.blpop(QUEUE_NAME, timeout=timeout)
    if item is None:
        return None
    order = json.loads(item[1])
    time.sleep(PROCESS_DELAY)
    r.incr("stats:processed")
    r.hset(f"processed_by:{WORKER_ID}", order["id"], order["dish"])
    print(f"[{WORKER_ID}] piatto pronto: {order['dish']} (tavolo {order['table']})", flush=True)
    return order


def main():
    if not REDIS_HOST:
        print("ERRORE: variabile d'ambiente REDIS_HOST mancante", file=sys.stderr)
        sys.exit(1)
    r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    print(f"[{WORKER_ID}] in ascolto sulla coda '{QUEUE_NAME}'", flush=True)
    while True:
        heartbeat()
        try:
            process_one(r)
        except redis.RedisError as exc:
            print(f"[{WORKER_ID}] Redis non raggiungibile: {exc}", file=sys.stderr, flush=True)
            time.sleep(2)


if __name__ == "__main__":
    main()
