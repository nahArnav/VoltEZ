from types import SimpleNamespace
from uuid import uuid4

import pytest

from app import worker
from app.schemas.enums import BookingStatus
from database.models.booking_event import BookingEvent


class _FakeScalarResult:
    def __init__(self, bookings):
        self._bookings = bookings

    def scalars(self):
        return self

    def all(self):
        return self._bookings


class _FakeSession:
    def __init__(self, *, booking=None, bookings=None):
        self.booking = booking
        self.bookings = bookings or []
        self.added = []
        self.commits = 0

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args):
        return None

    async def get(self, _model, _identifier):
        return self.booking

    async def execute(self, _statement):
        return _FakeScalarResult(self.bookings)

    def add(self, value):
        self.added.append(value)

    async def commit(self):
        self.commits += 1


@pytest.mark.asyncio
async def test_delayed_job_expires_held_booking(monkeypatch) -> None:
    booking = SimpleNamespace(id=uuid4(), status=BookingStatus.HELD.value)
    session = _FakeSession(booking=booking)
    monkeypatch.setattr(worker, "AsyncSessionLocal", lambda: session)

    await worker.expire_unpaid_booking({}, str(booking.id))

    assert booking.status == BookingStatus.EXPIRED.value
    assert session.commits == 1
    assert any(isinstance(value, BookingEvent) for value in session.added)


@pytest.mark.asyncio
async def test_worker_startup_reconciles_only_active_holds(monkeypatch) -> None:
    held = SimpleNamespace(id=uuid4(), status=BookingStatus.HELD.value)
    confirmed = SimpleNamespace(id=uuid4(), status=BookingStatus.CONFIRMED.value)
    session = _FakeSession(bookings=[held, confirmed])
    monkeypatch.setattr(worker, "AsyncSessionLocal", lambda: session)

    repaired = await worker.reconcile_expired_booking_holds()

    assert repaired == 1
    assert held.status == BookingStatus.EXPIRED.value
    assert confirmed.status == BookingStatus.CONFIRMED.value
    assert session.commits == 1
