# ADR 0008: Separate one-off migration service instead of per-replica migration

## Status
Accepted

## Context
Since Stage 2, `entrypoint.sh` ran `alembic upgrade head` before starting
uvicorn, with an explicit comment warning this would race once multiple
replicas existed. Stage 3 introduces two app replicas (`app1`, `app2`)
behind nginx, making this no longer theoretical.

## Decision
Run migrations as a separate, one-off `migrate` service in
`docker-compose.yml`. `app1` and `app2` no longer run migrations
themselves — they use `command:` to skip straight to `uvicorn`, and wait
for `migrate` to complete successfully via
`depends_on: migrate: condition: service_completed_successfully`.

## Reasoning
- Running a schema migration exactly once, before any replica serves
  traffic, is the only way to guarantee no two processes attempt
  conflicting DDL changes at the same time.
- This also matches how a real Kubernetes deployment handles it: a
  one-off Job (or Helm pre-install hook) runs migrations, and only once it
  succeeds does the actual Deployment roll out replicas. This
  docker-compose setup is a direct, testable preview of that Stage 4
  pattern.

## Trade-off acknowledged
`entrypoint.sh` (the image's default `CMD`) still contains the old
migrate-then-serve behavior — kept for the case of running the container
standalone outside docker-compose. This means the image technically
supports two different behaviors depending on how it's invoked, which is
a bit of duplication to keep in mind. Revisit if this divergence starts
causing confusion.
