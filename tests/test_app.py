"""Test unitari: girano senza Redis vero grazie a fakeredis.
Lancio:  pip install -r tests/requirements.txt && pytest -q tests/
"""
import os
import sys
import pathlib

import fakeredis
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "app" / "api"))
sys.path.insert(0, str(ROOT / "app" / "worker"))

os.environ.setdefault("API_KEY", "test-key")
os.environ.setdefault("QUEUE_NAME", "orders")
os.environ.setdefault("PROCESS_DELAY", "0")

import app as api  # noqa: E402
import worker  # noqa: E402


@pytest.fixture
def r():
    return fakeredis.FakeRedis(decode_responses=True)


@pytest.fixture
def client(r):
    return api.create_app(redis_client=r).test_client()


def test_healthz(client):
    assert client.get("/healthz").status_code == 200


def test_order_requires_api_key(client):
    assert client.post("/orders", json={"dish": "carbonara"}).status_code == 401


def test_order_flow(client, r):
    resp = client.post("/orders", json={"dish": "carbonara", "table": 4},
                       headers={"X-Api-Key": "test-key"})
    assert resp.status_code == 201
    worker.QUEUE_NAME = api.QUEUE_NAME
    assert worker.process_one(r, timeout=1)["dish"] == "carbonara"
    stats = client.get("/stats").get_json()
    assert stats["processed"] == 1 and stats["queued"] == 0
