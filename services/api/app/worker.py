import asyncio
from arq.connections import RedisSettings
from sqlalchemy import update
from app.db.session import AsyncSessionLocal
from app.models.booking import Booking, BookingStatus

async def expire_unpaid_booking(ctx, booking_id: str):
    """
    This task wakes up 15 minutes after a booking is created.
    If the booking is still 'PENDING', it changes it to 'EXPIRED' to free the charger.
    """
    print(f"🚦 [Worker] Waking up to check booking: {booking_id}")
    
    # 1. Open a quick connection to the database
    async with AsyncSessionLocal() as db:
        # 2. Get the current booking status
        booking = await db.get(Booking, int(booking_id))
        
        if not booking:
            print(f"❌ [Worker] Booking {booking_id} not found.")
            return

        # 3. Check if they actually paid
        # Since Step 2.2, new bookings are marked as HELD. We check for both for backward compatibility.
        if booking.status in (BookingStatus.PENDING, BookingStatus.HELD):
            print(f"⚠️ [Worker] Booking {booking_id} is still {booking.status}. Expiring now!")
            
            booking.status = BookingStatus.EXPIRED
            await db.commit()
            
            print(f"✅ [Worker] Booking {booking_id} successfully expired. Charger is free.")
        else:
            print(f"👍 [Worker] Booking {booking_id} status is {booking.status}. No action needed.")

from app.core.config import settings

# ARQ Worker Configuration
class WorkerSettings:
    # Tell ARQ which functions it is allowed to run
    functions = [expire_unpaid_booking]
    
    # Connect to the Redis container using the env config
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    
    # Optional startup/shutdown hooks
    async def on_startup(ctx):
        print("🤖 Busboy Worker is starting up and listening for jobs...")

    async def on_shutdown(ctx):
        print("🛑 Busboy Worker is shutting down...")