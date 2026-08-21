"""Reproducible random streams and stable identifiers.

Each generator module receives a named stream. Adding a new random draw to the demand module will
therefore not silently change charger IDs or vehicle profiles produced by another module.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from collections.abc import Mapping
from typing import Any

import numpy as np
from numpy.random import Generator


def canonical_json(value: Any) -> str:
    """Serialize JSON-compatible data in one stable representation."""

    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=str)


def stable_hash(value: Any) -> str:
    """Return a SHA-256 hash for a JSON-compatible value."""

    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def named_rng(seed: int, stream_name: str) -> Generator:
    """Create a deterministic RNG whose output depends only on seed and stream name."""

    stream_digest = hashlib.sha256(stream_name.encode("utf-8")).digest()
    stream_seed = int.from_bytes(stream_digest[:8], byteorder="big", signed=False)
    sequence = np.random.SeedSequence([seed, stream_seed])
    return np.random.default_rng(sequence)


def stable_id(namespace_id: str, entity: str, natural_key: str | int) -> str:
    """Create a UUID-shaped deterministic identifier without exposing personal data."""

    value = f"voltez:{namespace_id}:{entity}:{natural_key}"
    return str(uuid.uuid5(uuid.NAMESPACE_URL, value))


def structural_namespace(city: str, generator_version: str, structural_seed: int) -> str:
    """Return the identity namespace for one stable synthetic charging network.

    Dynamic simulation runs intentionally receive different run IDs. Physical entities instead
    use this namespace so the same Pune zones, hosts, chargers, and ports can be followed across
    independent train/validation/test histories.
    """

    return f"structure:{city.casefold()}:{generator_version}:{structural_seed}"


def negative_binomial_parameters(mean: float, dispersion: float) -> tuple[float, float]:
    """Translate mean/dispersion into NumPy's ``n`` and ``p`` parameterization.

    The resulting distribution has variance ``mean + mean**2 / dispersion``. Increasing
    dispersion therefore reduces extra burstiness and approaches a Poisson count process.
    """

    if mean < 0:
        raise ValueError("negative-binomial mean cannot be negative")
    if dispersion <= 0:
        raise ValueError("negative-binomial dispersion must be positive")
    probability = dispersion / (dispersion + mean) if mean > 0 else 1.0
    return dispersion, probability


def config_fingerprint(config_values: Mapping[str, Any]) -> str:
    """Fingerprint the values that define one synthetic simulation."""

    return stable_hash(dict(config_values))
