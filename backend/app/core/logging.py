"""
VoltEZ Structured Logging

JSON-formatted structured logging with request context (request_id, user_id).
"""

import logging
import json
import sys
from datetime import datetime, timezone
from typing import Optional, Any


class JSONFormatter(logging.Formatter):
    """
    Formats log records as JSON for structured logging.
    Includes timestamp, level, logger name, message, and any extra fields.
    """

    def format(self, record: logging.LogRecord) -> str:
        log_entry: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Include extra context fields if present
        for field in ("request_id", "user_id", "endpoint", "status_code", "latency"):
            value = getattr(record, field, None)
            if value is not None:
                log_entry[field] = value

        # Include exception info if present
        if record.exc_info and record.exc_info[1]:
            log_entry["exception"] = {
                "type": type(record.exc_info[1]).__name__,
                "message": str(record.exc_info[1]),
            }

        return json.dumps(log_entry, default=str)


def setup_logging(level: int = logging.INFO) -> None:
    """
    Configure the root logger with JSON-formatted output.
    Call once at application startup.
    """
    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Remove existing handlers to avoid duplicates
    root_logger.handlers.clear()

    # Add JSON handler to stdout
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    root_logger.addHandler(handler)

    # Reduce noise from third-party libraries
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """
    Get a named logger instance.
    Use this instead of logging.getLogger() directly for consistency.
    """
    return logging.getLogger(f"voltez.{name}")
