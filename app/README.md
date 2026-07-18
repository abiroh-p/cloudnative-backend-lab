# app/ — Stage 1: Backend core

A small FastAPI service backed by Postgres. CRUD on a generic `Item`
resource, structured JSON logging, and health endpoints ready for
Kubernetes probes later.

## Running locally

```bash
cd app
cp .env.example .env      # only needed if running uvicorn directly, not via compose
docker compose up --build
```

The app starts on `http://localhost:8000`. Postgres runs alongside it in
its own container — data persists in a named Docker volume (`pgdata`)
across restarts, but `docker compose down -v` wipes it.

## Try it

```bash
# create an item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"name": "first item", "description": "testing the API"}'

# list items
curl http://localhost:8000/items

# health checks
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

FastAPI's interactive docs are also available at
`http://localhost:8000/docs` — useful for exploring the API without
writing curl commands by hand.

## What's deliberately simplified right now

- **`Base.metadata.create_all()` in `main.py`** creates tables directly on
  startup — fine for this early stage since there's no real data to lose
  yet. This gets replaced by Alembic migrations as the only way schema
  changes happen (see `docs/adr/0004-migrations-vs-create-all.md`).
- **Live-reload via bind mount** (`./src:/app/src` in `docker-compose.yml`)
  — convenient for local dev, but this pattern doesn't carry over to the
  AKS deployment in Stage 4, where images are immutable and rebuilt on
  every change.
- **Generic `Item` domain** — the schema is intentionally uninteresting;
  the goal here is proving CRUD, health checks, structured logging, and DB
  connection pooling, not designing a real product.

## What's next (Stage 2)

- Wire up Alembic migrations for real (currently scaffolded but unused)
- Add indexing strategy notes + `EXPLAIN ANALYZE` findings
- Move Postgres to Azure Database for PostgreSQL, credentials via Key Vault
  + managed identity instead of docker-compose env vars
