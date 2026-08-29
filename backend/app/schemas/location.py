from pydantic import BaseModel, ConfigDict, Field


class LocationSearchResult(BaseModel):
    """A human-readable place returned by the configured geocoder."""

    display_name: str = Field(min_length=1)
    latitude: float
    longitude: float
    place_type: str | None = None
    importance: float | None = None

    model_config = ConfigDict(from_attributes=True)
