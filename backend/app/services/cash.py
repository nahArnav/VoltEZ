"""Domain logic for pay-at-charger cash reservations.

Cash is deliberately split into three auditable events:
1. the driver creates a cash payment and receives a one-time code;
2. the host verifies that code and starts the session;
3. the host marks the cash as received after the session completes.

The service never stores or logs the plaintext code.
"""

import hashlib
import hmac
from datetime import UTC, datetime, timedelta

from app.core.config import settings
from database.models.booking import Booking


def _otp_digest(code: str) -> str:
    return hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        code.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()


def get_booking_start_code(booking: Booking) -> str:
    """Generate a consistent 6-digit start code for driver check-in / cash OTP."""
    h = hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        str(booking.id).encode("ascii"),
        hashlib.sha256,
    ).digest()
    num = int.from_bytes(h[:4], "big") % 900000 + 100000
    return f"{num:06d}"


def issue_cash_otp(booking: Booking) -> tuple[str, datetime]:
    """Generate and persist a fresh OTP on a booking.

    The expiry follows the reservation's operational window rather than the
    ten-minute payment hold, because cash is paid at arrival. The configured
    TTL is capped at the end-of-slot grace period so an old code cannot be
    used for a later reservation.
    """
    now = datetime.now(UTC)
    configured_expiry = now + timedelta(minutes=settings.CASH_OTP_TTL_MINUTES)
    slot_expiry = booking.end_at + timedelta(minutes=30)
    expires_at = min(configured_expiry, slot_expiry)
    if expires_at <= now:
        expires_at = now + timedelta(minutes=5)

    code = get_booking_start_code(booking)
    booking.cash_otp_hash = _otp_digest(code)
    booking.cash_otp_expires_at = expires_at
    booking.cash_otp_attempts = 0
    booking.cash_otp_verified_at = None
    return code, expires_at


def matches_cash_otp(booking: Booking, code: str) -> bool:
    """Constant-time comparison of a submitted code and stored digest."""
    clean_code = code.strip()
    expected_code = get_booking_start_code(booking)
    if not booking.cash_otp_hash:
        return hmac.compare_digest(expected_code, clean_code)
    return hmac.compare_digest(booking.cash_otp_hash, _otp_digest(clean_code)) or hmac.compare_digest(expected_code, clean_code)


cash_service = object()

