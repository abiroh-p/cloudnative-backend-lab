#!/bin/sh
# WHY this script exists:
# The app should never start serving traffic on top of a database schema
# that isn't up to date. Running "alembic upgrade head" before uvicorn
# starts guarantees that. "set -e" means: if the migration fails, this
# script exits immediately — the app container fails to start rather than
# running against a broken/half-migrated schema.
#
# NOTE: this script is still the default CMD for the image (used if you
# run this container standalone, outside docker-compose). As of Stage 3,
# docker-compose.yml no longer relies on this script's automatic migration
# for app1/app2 — it overrides `command:` to skip straight to uvicorn, and
# runs migrations exactly once via a separate `migrate` service instead.
# See docs/adr/0008-separate-migration-service.md for why — this was
# exactly the race condition warned about below, now resolved for real
# rather than deferred.
#
# ORIGINAL NOTE (now resolved, kept for context):
# this pattern works fine for a single instance. Once you run MULTIPLE
# replicas, having every replica try to run migrations on startup risks a
# race condition (two pods altering the schema at once). The real-world
# fix is to run migrations as a separate one-off step BEFORE the
# replicas start, not inside every instance's own startup.

set -e

alembic upgrade head
exec uvicorn src.main:app --host 0.0.0.0 --port 8000
