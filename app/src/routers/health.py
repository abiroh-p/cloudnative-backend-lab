# WHY a dedicated health router now, even with no orchestrator yet:
# Kubernetes liveness/readiness probes (Stage 4) need an endpoint to hit.
# Building it now, and testing it locally, means Stage 4 is just pointing
# an existing, proven endpoint at a probe config — not writing new app code
# under deployment pressure.
#
# The two checks are deliberately different:
# - /health/live  : is the process running at all? No dependencies checked.
#                   Kubernetes uses this to decide "should I restart this pod?"
# - /health/ready : can this instance actually serve traffic right now
#                   (e.g. is the DB reachable)? Kubernetes uses this to decide
#                   "should I send this pod traffic?" — a pod can be alive
#                   but not ready (e.g. still warming up, or DB is down).

import logging

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from src.db.session import engine

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/health", tags=["health"])


@router.get("/live")
def liveness():
    return {"status": "alive"}


@router.get("/ready")
def readiness():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception as e:
        logger.error("readiness_check_failed", extra={"error": str(e)})
        return JSONResponse(status_code=503, content={"status": "not_ready", "detail": str(e)})
