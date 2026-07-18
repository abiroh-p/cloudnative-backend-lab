# WHY this file exists:
# Plain text logs ("INFO: something happened") are fine to read in a
# terminal, but useless once you have real infrastructure — Grafana Loki,
# Azure Monitor, and every log aggregation tool expect JSON so they can
# filter/query on fields (e.g. "show me all logs where status_code >= 500").
# Structured logging from day one means Stage 6 observability work plugs in
# without rewriting how the app logs.

import logging
import json
import sys
from datetime import datetime, timezone


class JSONFormatter(logging.Formatter):
    _RESERVED = set(logging.LogRecord(
        "", 0, "", 0, "", (), None
    ).__dict__.keys()) | {"message", "asctime"}

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        for key, value in record.__dict__.items():
            if key not in self._RESERVED:
                log_entry[key] = value

        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry, default=str)


def configure_logging(level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers = [handler]   # replace default handlers, avoid duplicate logs
    root_logger.setLevel(level)

    # Quiet down noisy third-party loggers so our own logs aren't drowned out
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
