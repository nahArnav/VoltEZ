from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from geoalchemy2 import Geometry as GeometryType
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user, require_role
from app.db.session import get_db
from app.repositories.business import business_repo
from app.schemas.booking import BookingResponse
from app.schemas.business import (
    BusinessCreate,
    BusinessKYCResponse,
    BusinessKYCSubmit,
    BusinessResponse,
    BusinessUpdate,
)
from app.schemas.cash import (
    CashOtpVerificationResponse,
    CashOtpVerifyRequest,
    CashSettlementResponse,
)
from app.schemas.enums import BookingStatus, UserRole
from app.services.cash_flow import cash_flow_service
from database.models.booking import Booking
from database.models.booking_event import BookingEvent
from database.models.business import Business
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.user import User
from database.models.zone import Zone

router = APIRouter(prefix="/businesses", tags=["Businesses"])


async def _business_with_coordinates(db: AsyncSession, business_id: UUID):
    """Return a business with PostGIS coordinates decoded for mobile clients."""
    result = await db.execute(
        select(
            Business,
            func.ST_Y(Business.location.cast(GeometryType)).label("latitude"),
            func.ST_X(Business.location.cast(GeometryType)).label("longitude"),
        ).where(Business.id == business_id)
    )
    row = result.one_or_none()
    if row is None:
        return None
    business, latitude, longitude = row
    business.latitude = latitude
    business.longitude = longitude
    return business


@router.get("/me", response_model=BusinessResponse)
async def get_my_business(
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Return the owner's primary business for the current single-business UI."""
    businesses = await business_repo.get_by_owner_id(db, owner_id=current_user.id)
    if not businesses:
        raise HTTPException(status_code=404, detail="Business not found")
    return await _business_with_coordinates(db, businesses[0].id)


@router.get("/", response_model=list[BusinessResponse])
async def list_businesses(
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """List all businesses for the current owner."""
    # type ignore for Pylance Column[int] false positive
    businesses = await business_repo.get_by_owner_id(db, owner_id=current_user.id)  # type: ignore
    enriched = []
    for business in businesses:
        enriched.append(await _business_with_coordinates(db, business.id))
    return enriched


@router.post("/", response_model=BusinessResponse, status_code=status.HTTP_201_CREATED)
async def create_business(
    business_in: BusinessCreate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Register a new business."""
    business_data = business_in.model_dump()

    # Extract lat/lng to convert to PostGIS geometry
    lat = business_data.pop("latitude", None)
    lon = business_data.pop("longitude", None)
    if lat is not None and lon is not None:
        business_data["location"] = f"SRID=4326;POINT({lon} {lat})"

    if business_data.get("zone_id") is None:
        point = func.ST_SetSRID(func.ST_MakePoint(lon, lat), 4326)
        zone_result = await db.execute(
            select(Zone.id)
            .where(Zone.active, Zone.centroid.is_not(None))
            .order_by(func.ST_Distance(Zone.centroid, point))
            .limit(1)
        )
        zone_id = zone_result.scalar_one_or_none()
        if zone_id is None:
            raise HTTPException(status_code=422, detail="No active service zone covers this location")
        business_data["zone_id"] = zone_id

    business_data["owner_id"] = current_user.id
    business_data["verification_status"] = "pending"

    business = await business_repo.create(db, obj_in=business_data)
    await db.commit()
    await db.refresh(business)

    # Attach lat/lng for Pydantic serialization
    business.latitude = lat
    business.longitude = lon

    return business


@router.get("/{business_id}", response_model=BusinessResponse)
async def get_business(
    business_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    business = await _business_with_coordinates(db, business_id)
    if not business:
        raise HTTPException(status_code=404, detail="Business not found")
    # For now, let anyone view a business, or restrict to owner if needed.
    return business


@router.get("/{business_id}/bookings", response_model=list[BookingResponse])
async def list_business_bookings(
    business_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """List reservations made against ports owned by this business."""
    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")
    result = await db.execute(
        select(Booking)
        .join(ChargerPort, Booking.charger_port_id == ChargerPort.id)
        .join(Charger, ChargerPort.charger_id == Charger.id)
        # Owners only need actionable reservations in their operations view.
        # Cancelled/expired/failed rows remain auditable in booking history,
        # but must not appear as current work in the dashboard.
        .where(
            Charger.business_id == business_id,
            Booking.status == BookingStatus.CONFIRMED.value,
        )
        .order_by(Booking.start_at.desc())
    )
    # Keep the owner dashboard free of opaque UUID-only labels.  This is the
    # same station context returned by the driver booking API.
    from app.api.v1.booking import _with_charger_context

    return [
        await _with_charger_context(db, booking)
        for booking in result.scalars().all()
    ]


@router.post(
    "/{business_id}/bookings/{booking_id}/cash-verify",
    response_model=CashOtpVerificationResponse,
)
async def verify_cash_booking_otp(
    business_id: UUID,
    booking_id: UUID,
    otp_in: CashOtpVerifyRequest,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Host verifies the driver's one-time cash code and starts charging."""

    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")

    booking, session = await cash_flow_service.verify_otp_and_start(
        db,
        business_id=business_id,
        booking_id=booking_id,
        code=otp_in.code,
    )
    return CashOtpVerificationResponse(
        booking_id=booking.id,
        session_id=session.id,
        booking_status=booking.status,
        session_status=session.status,
        started_at=session.started_at,
    )


@router.post(
    "/{business_id}/bookings/{booking_id}/cash-settle",
    response_model=CashSettlementResponse,
)
async def settle_cash_booking(
    business_id: UUID,
    booking_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Host records receipt of cash after the driver finishes charging."""

    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")

    payment = await cash_flow_service.settle_cash(
        db,
        business_id=business_id,
        booking_id=booking_id,
        actor_id=current_user.id,
    )
    return CashSettlementResponse(
        payment_id=payment.id,
        booking_id=payment.booking_id,
        amount=float(payment.amount),
        currency=payment.currency,
        status=payment.status,
        verified_at=payment.verified_at,
    )


@router.post("/{business_id}/bookings/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_business_booking(
    business_id: UUID,
    booking_id: UUID,
    request: Request,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Allow an owner to cancel a reservation on one of their ports."""
    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")
    result = await db.execute(
        select(Booking)
        .join(ChargerPort, Booking.charger_port_id == ChargerPort.id)
        .join(Charger, ChargerPort.charger_id == Charger.id)
        .where(Booking.id == booking_id, Charger.business_id == business_id)
    )
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status not in {
        BookingStatus.PENDING.value,
        BookingStatus.HELD.value,
        BookingStatus.CONFIRMED.value,
    }:
        raise HTTPException(status_code=409, detail=f"Cannot cancel a {booking.status} booking")
    old_status = booking.status
    booking.status = BookingStatus.CANCELLED.value
    booking.cancelled_at = datetime.now(UTC)
    db.add(
        BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.CANCELLED.value,
            actor=f"owner:{current_user.id}",
            metadata_={"reason": "business_cancelled"},
        )
    )
    await db.commit()
    await db.refresh(booking)
    redis = getattr(request.app.state, "redis", None)
    if redis is not None:
        lock_key = f"hold:port:{booking.charger_port_id}:{int(booking.start_at.timestamp())}:{int(booking.end_at.timestamp())}"
        await redis.delete(lock_key)
    from app.api.v1.booking import _with_charger_context

    return await _with_charger_context(db, booking)


@router.patch("/{business_id}", response_model=BusinessResponse)
async def update_business(
    business_id: UUID,
    business_in: BusinessUpdate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    business = await business_repo.get(db, id=business_id)
    if not business or business.owner_id != current_user.id:  # type: ignore
        raise HTTPException(status_code=404, detail="Business not found or unauthorized")

    update_data = business_in.model_dump(exclude_unset=True)
    lat = update_data.pop("latitude", None)
    lon = update_data.pop("longitude", None)
    if (lat is None) != (lon is None):
        raise HTTPException(
            status_code=422,
            detail="latitude and longitude must be updated together",
        )
    if lat is not None and lon is not None:
        update_data["location"] = f"SRID=4326;POINT({lon} {lat})"

    business = await business_repo.update(db, db_obj=business, obj_in=update_data)
    await db.commit()
    await db.refresh(business)
    if lat is not None:
        business.latitude = lat
        business.longitude = lon
    return await _business_with_coordinates(db, business_id)


@router.delete("/{business_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_business(
    business_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    business = await business_repo.get(db, id=business_id)
    if not business or business.owner_id != current_user.id:  # type: ignore
        raise HTTPException(status_code=404, detail="Business not found or unauthorized")

    await business_repo.remove(db, id=business_id)
    await db.commit()
    return None


@router.get("/{business_id}/kyc", response_model=BusinessKYCResponse)
async def get_business_kyc(
    business_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve KYC verification status for a business."""
    business = await business_repo.get(db, id=business_id)
    if not business or (current_user.role != UserRole.ADMIN and business.owner_id != current_user.id):
        raise HTTPException(status_code=404, detail="Business not found")

    return BusinessKYCResponse(
        business_id=business.id,
        verification_status=business.verification_status,
        gstin_masked=business.kyc_gstin_masked,
        pan_masked=business.kyc_pan_masked,
        electricity_meter_id=business.kyc_electricity_meter_masked,
        payout_upi_id=business.kyc_payout_upi_masked,
        submitted_at=business.kyc_submitted_at or business.updated_at,
    )


@router.post("/{business_id}/kyc", response_model=BusinessKYCResponse)
async def submit_business_kyc(
    business_id: UUID,
    kyc_in: BusinessKYCSubmit,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Submit host KYC documents (GSTIN, PAN, Electricity meter) and verify business."""
    business = await business_repo.get(db, id=business_id)
    if not business or (current_user.role != UserRole.ADMIN and business.owner_id != current_user.id):
        raise HTTPException(status_code=404, detail="Business not found")

    gst = kyc_in.gstin.strip() if kyc_in.gstin else None
    pan = kyc_in.pan_number.strip() if kyc_in.pan_number else None
    meter = kyc_in.electricity_meter_id.strip() if kyc_in.electricity_meter_id else None
    payout = kyc_in.payout_upi_id.strip() if kyc_in.payout_upi_id else None
    if not gst and not pan:
        raise HTTPException(status_code=422, detail="GSTIN or PAN is required")

    def mask(value: str | None, prefix: int = 3, suffix: int = 2) -> str | None:
        if not value:
            return None
        if len(value) <= prefix + suffix:
            return "•" * len(value)
        return value[:prefix] + "•" * (len(value) - prefix - suffix) + value[-suffix:]

    now = datetime.now(UTC)
    # Submission is not verification. A provider or admin review must approve it.
    business.verification_status = "pending"
    business.kyc_gstin_masked = mask(gst, prefix=4, suffix=3)
    business.kyc_pan_masked = mask(pan, prefix=3, suffix=2)
    business.kyc_electricity_meter_masked = mask(meter)
    business.kyc_payout_upi_masked = mask(payout, prefix=2, suffix=4)
    business.kyc_submitted_at = now
    business.updated_at = now
    db.add(business)
    await db.commit()
    await db.refresh(business)

    return BusinessKYCResponse(
        business_id=business.id,
        verification_status=business.verification_status,
        gstin_masked=business.kyc_gstin_masked,
        pan_masked=business.kyc_pan_masked,
        electricity_meter_id=business.kyc_electricity_meter_masked,
        payout_upi_id=business.kyc_payout_upi_masked,
        submitted_at=business.kyc_submitted_at,
    )
