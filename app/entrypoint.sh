#!/bin/sh
# WHY this script exists:
# The app should never start serving traffic on top of a database schema
# that isn't up to date. Running "alembic upgrade head" before uvicorn
# starts guarantees that. "set -e" means: if the migration fails, this
# script exits immediately — the app container fails to start rather than
# running against a broken/half-migrated schema.
#
# NOTE for later (Stage 4 / AKS): this pattern works fine for a single
# instance. Once you run MULTIPLE replicas, having every replica try to run
# migrations on startup risks a race condition (two pods altering the
# schema at once). The real-world fix is to run migrations as a separate
# one-off Kubernetes Job or init step BEFORE the deployment rolls out, not
# inside every pod's own startup. We'll address that explicitly in Stage 4
# — flagging it now so it's not a surprise later.

set -e

alembic upgrade head
exec uvicorn src.main:app --host 0.0.0.0 --port 8000
