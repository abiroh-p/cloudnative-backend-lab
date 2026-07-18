# ADR 0004: Use `create_all()` temporarily instead of Alembic migrations

## Status
Accepted (temporary — see "Revisit" below)

## Context
Alembic is scaffolded (`app/migrations/`) but `main.py` currently calls
`Base.metadata.create_all()` on startup instead of running migrations.

## Decision
Use `create_all()` during initial Stage 1 development. Switch to Alembic
as the *only* way schema changes happen once Stage 2 begins.

## Reasoning
- At this point there's no real data — any schema mistake costs nothing to
  fix by just recreating the table.
- `create_all()` has near-zero ceremony: change the model, restart, done.
  This keeps iteration fast while the schema itself is still being figured
  out.
- Migrations exist to solve a problem `create_all()` can't: safely
  evolving a schema that already has real data, and keeping dev/staging/
  prod schemas from drifting apart. That problem doesn't exist yet.

## Trade-off acknowledged
`create_all()` cannot handle schema changes to an existing table (e.g.
adding a NOT NULL column to a table with existing rows) — it only creates
tables that don't exist yet, it never alters ones that do. Relying on it
past this early stage would silently mask schema drift between
environments.

## Revisit
This decision is explicitly temporary. Once Stage 2 begins (real
persistent data, Key Vault-backed credentials), `create_all()` gets removed
from `main.py` entirely and every schema change goes through
`alembic revision --autogenerate` + `alembic upgrade head`.
