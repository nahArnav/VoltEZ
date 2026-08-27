"""
VoltEZ Standardized Error Handling

Custom exceptions and FastAPI exception handlers that produce consistent
error responses matching the API contract:
  { "code": "...", "message": "...", "request_id": "...", "field_errors": [...] }
"""

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# --- Error Response Schema ---


class FieldError(BaseModel):
    field: str
    message: str


class ErrorResponse(BaseModel):
    code: str
    message: str
    request_id: str | None = None
    field_errors: list[FieldError] | None = None


# --- Custom Exceptions ---


class VoltEZError(Exception):
    """Base exception for all VoltEZ application errors."""

    def __init__(
        self,
        code: str = "INTERNAL_ERROR",
        message: str = "An unexpected error occurred.",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        field_errors: list[dict] | None = None,
    ):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.field_errors = field_errors
        super().__init__(self.message)


class NotFoundError(VoltEZError):
    """Resource not found."""

    def __init__(self, resource: str = "Resource", message: str | None = None):
        super().__init__(
            code=f"{resource.upper()}_NOT_FOUND",
            message=message or f"{resource} not found.",
            status_code=status.HTTP_404_NOT_FOUND,
        )


class ConflictError(VoltEZError):
    """Resource conflict (e.g., duplicate, slot already taken)."""

    def __init__(self, code: str = "CONFLICT", message: str = "Resource conflict."):
        super().__init__(
            code=code,
            message=message,
            status_code=status.HTTP_409_CONFLICT,
        )


class ForbiddenError(VoltEZError):
    """Insufficient permissions."""

    def __init__(self, message: str = "You do not have permission to perform this action."):
        super().__init__(
            code="FORBIDDEN",
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
        )


class UnauthorizedError(VoltEZError):
    """Authentication required or invalid."""

    def __init__(self, message: str = "Authentication required."):
        super().__init__(
            code="UNAUTHORIZED",
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
        )


class BadRequestError(VoltEZError):
    """Client sent invalid data."""

    def __init__(
        self,
        message: str = "Invalid request.",
        code: str = "BAD_REQUEST",
        field_errors: list[dict] | None = None,
    ):
        super().__init__(
            code=code,
            message=message,
            status_code=status.HTTP_400_BAD_REQUEST,
            field_errors=field_errors,
        )


class SlotUnavailableError(ConflictError):
    """Specific conflict: booking slot is no longer available."""

    def __init__(self):
        super().__init__(
            code="SLOT_UNAVAILABLE",
            message="The requested slot is no longer available.",
        )


# --- Exception Handlers ---


def _get_request_id(request: Request) -> str | None:
    """Extract request ID from response headers (set by middleware)."""
    return getattr(request.state, "request_id", None)


def register_exception_handlers(app: FastAPI) -> None:
    """Register all custom exception handlers on the FastAPI app."""

    @app.exception_handler(VoltEZError)
    async def voltez_error_handler(request: Request, exc: VoltEZError):
        return JSONResponse(
            status_code=exc.status_code,
            content=ErrorResponse(
                code=exc.code,
                message=exc.message,
                request_id=_get_request_id(request),
                field_errors=[FieldError(**fe) for fe in exc.field_errors]
                if exc.field_errors
                else None,
            ).model_dump(exclude_none=True),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        field_errors = []
        for error in exc.errors():
            loc = error.get("loc", ())
            # Skip the first element which is usually "body"
            field_path = (
                ".".join(str(l) for l in loc[1:]) if len(loc) > 1 else ".".join(str(l) for l in loc)
            )
            field_errors.append(
                FieldError(field=field_path, message=error.get("msg", "Invalid value"))
            )

        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=ErrorResponse(
                code="VALIDATION_ERROR",
                message="Request validation failed.",
                request_id=_get_request_id(request),
                field_errors=field_errors,
            ).model_dump(exclude_none=True),
        )

    @app.exception_handler(Exception)
    async def generic_error_handler(request: Request, exc: Exception):
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=ErrorResponse(
                code="INTERNAL_ERROR",
                message="An unexpected error occurred.",
                request_id=_get_request_id(request),
            ).model_dump(exclude_none=True),
        )
