# RistoQueue
Il ristorante "Da Mario" ha un sistema per gestire gli ordini della cucina:

```
  cameriere ──POST /orders──▶  API (Flask)  ──RPUSH──▶  Redis  ──BLPOP──▶  Worker (x N)
                               GET /stats  ◀───────────── contatori ◀────────┘
```

Il codice applicativo è **già scritto e funzionante** (`app/`). Il vostro lavoro è portarlo in produzione:
containerizzarlo, deployarlo su Kubernetes e automatizzare tutto con una pipeline e con Ansible.

## Obiettivo

L'esercizio è superato quando, su un cluster **kind** creato sul PC di uno di voi, questo comando termina con successo:

```bash
./tests/acceptance.sh
```

e la pipeline non segnala problemi.
Leggete `tests/acceptance.sh`: è la definizione precisa di "fatto". Non va modificato.

## Squadra e ruoli

Siete in tre e ognuno ha un ruolo e una **carta ruolo** personale, consegnata da me.
Ogni carta contiene requisiti del cliente che **solo quella persona conosce** e che gli altri due
servono per completare la propria parte. Nessuno può finire da solo.

| Ruolo | Possiede (CODEOWNERS) |
|---|---|
| **A — Container Engineer** | `app/**/Dockerfile`, `.dockerignore`, `docker-compose.yml`, `scripts/build.sh` |
| **B — Kubernetes Engineer** | `k8s/`, `scripts/deploy.sh` |
| **C — Automation Engineer** | `pipeline`, `ansible/` |

## Regole

1. Ognuno modifica **solo i file che possiede**.
4. I segreti **non entrano mai** in git, nemmeno per un commit poi cancellato (il test controlla tutta la storia).
5. Il codice in `app/*.py` e `tests/` **non si tocca**. Se pensate che ci sia un problema, si risolve con la configurazione.
6. Alla fine ognuno spiega **un componente che non ha scritto lui**.

## Comodità

```bash
# test unitari (non serve Redis)
pip install -r tests/requirements.txt && pytest -q tests/

# lanciare l'app a mano
redis-server &
cd app/api && REDIS_HOST=localhost API_KEY=prova python app.py      # http://localhost:8080
cd app/worker && REDIS_HOST=localhost python worker.py
```

### Riferimento rapido dell'applicazione

| Componente | Variabili d'ambiente | Endpoint / note |
|---|---|---|
| API | `REDIS_HOST`*, `REDIS_PORT`, `API_KEY`*, `QUEUE_NAME`, `APP_VERSION`, `PORT` (8080) | `GET /healthz`, `GET /readyz`, `POST /orders` (header `X-Api-Key`), `GET /stats` |
| Worker | `REDIS_HOST`*, `REDIS_PORT`, `QUEUE_NAME`, `PROCESS_DELAY` | nessuna porta; `python healthcheck.py` esce 0 se il worker è vivo |

