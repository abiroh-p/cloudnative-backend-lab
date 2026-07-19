# ADR 0011: Fix Alembic migrations never fetching from Key Vault

## Status
Accepted

## Context
`migrations/env.py` built the database connection URL directly from
`settings.postgres_password` without ever calling `resolve_secrets()` —
that function was only invoked in `main.py`. Locally, this went unnoticed:
`.env` usually had a real working password sitting around from earlier
manual testing, so migrations connected successfully by coincidence, not
by correct design.

## Decision
Call `resolve_secrets()` explicitly in `migrations/env.py`, before
building the connection URL — mirroring the same explicit call already
made in `main.py`.

## Reasoning
This gap was discovered while preparing Stage 4 (AKS). In Kubernetes,
there is no local `.env` fallback at all — the migration Job's only path
to a working password is the Key Vault fetch. Without this fix, the
migration Job would have failed immediately on first deployment with an
authentication error, and the root cause (a missing function call, not a
Kubernetes or networking problem) would have been genuinely confusing to
track down under deployment pressure.

## Lesson
"Works locally" and "works correctly" are not the same claim. This
function call was optional in every environment tested so far purely by
coincidence (a real password happened to already be present). Moving to
an environment with zero fallback (AKS) turned a latent gap into a
guaranteed failure — which is exactly the value of testing in
increasingly production-like environments before treating something as
done.
