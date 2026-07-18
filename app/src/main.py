# WHY this file is small:
# main.py should just WIRE THINGS TOGETHER — configure logging, create the
# app, mount routers, register startup/shutdown hooks. Business logic lives
# in routers/, DB logic lives in db/. Keeping main.py thin means it stays
# readable as the app grows.

import logging

from fastapi import FastAPI, Request
import time

from src.core.config import settings
from src.core.logging import configure_logging
from src.db.session import Base, engine
from src.routers import items, health

configure_logging(settings.log_level)
logger = logging.getLogger(__name__)

app = FastAPI(title="cloudnative-backend-lab", version="0.1.0")

app.include_router(items.router)
app.include_router(health.router)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    # WHY: request-level logging is the single most useful thing to have
    # once this is deployed — lets you correlate latency/errors per route
    # without adding logging calls inside every endpoint.
    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    logger.info(
        "request_handled",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
        },
    )
    return response


@app.on_event("startup")
def on_startup():
    # NOTE: creating tables directly like this is fine for local dev only.
    # Once Alembic migrations are wired in (next step), this line gets
    # removed — migrations become the ONLY way schema changes happen, so
    # dev/staging/prod never drift from each other.
    Base.metadata.create_all(bind=engine)
    logger.info("app_startup", extra={"environment": settings.environment})


@app.get("/")
def root():
    return {"service": "cloudnative-backend-lab", "status": "running"}
