from uuid import UUID

from arq.connections import RedisSettings

from app.core.config import settings
from app.db.session import AsyncSessionLocal
from app.schemas.enums import BookingStatus
from database.models.booking import Booking
from database.models.booking_event import BookingEvent


async def expire_unpaid_booking(ctx, booking_id: str):
    """
    This task wakes up 10 minutes after a booking is created.
    If the booking is still unpaid, it expires the hold and records the transition.
    """
    print(f"🚦 [Worker] Waking up to check booking: {booking_id}")

    # 1. Open a quick connection to the database
    async with AsyncSessionLocal() as db:
        # 2. Get the current booking status
        booking = await db.get(Booking, UUID(booking_id))

        if not booking:
            print(f"❌ [Worker] Booking {booking_id} not found.")
            return

        # 3. Check if they actually paid
        # Since Step 2.2, new bookings are marked as HELD. We check for both for backward compatibility.
        if booking.status in (BookingStatus.PENDING.value, BookingStatus.HELD.value):
            print(f"⚠️ [Worker] Booking {booking_id} is still {booking.status}. Expiring now!")

            old_status = booking.status
            booking.status = BookingStatus.EXPIRED.value
            db.add(
                BookingEvent(
                    booking_id=booking.id,
                    old_status=old_status,
                    new_status=BookingStatus.EXPIRED.value,
                    actor="system:hold-expiry-worker",
                )
            )
            await db.commit()

            print(f"✅ [Worker] Booking {booking_id} successfully expired. Charger is free.")
        else:
            print(f"👍 [Worker] Booking {booking_id} status is {booking.status}. No action needed.")




# ARQ Worker Configuration
class WorkerSettings:
    # Tell ARQ which functions it is allowed to run
    functions = [expire_unpaid_booking]

    # Connect to the Redis container using the env config
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)

    # Optional startup/shutdown hooks
    @staticmethod
    async def on_startup(ctx):
        print("🤖 Busboy Worker is starting up and listening for jobs...")

    @staticmethod
    async def on_shutdown(ctx):
        print("🛑 Busboy Worker is shutting down...")
