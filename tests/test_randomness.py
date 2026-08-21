import numpy as np
import pytest

from voltez_ml.synthetic.randomness import (
    named_rng,
    negative_binomial_parameters,
    stable_id,
)


def test_named_random_streams_repeat_without_affecting_each_other() -> None:
    first_demand = named_rng(42, "demand").integers(0, 1000, size=8)
    second_demand = named_rng(42, "demand").integers(0, 1000, size=8)
    supply = named_rng(42, "supply").integers(0, 1000, size=8)

    assert np.array_equal(first_demand, second_demand)
    assert not np.array_equal(first_demand, supply)


def test_stable_ids_depend_on_run_entity_and_natural_key() -> None:
    identifier = stable_id("run-a", "port", "charger-1:0")

    assert identifier == stable_id("run-a", "port", "charger-1:0")
    assert identifier != stable_id("run-a", "port", "charger-1:1")
    assert identifier != stable_id("run-b", "port", "charger-1:0")


def test_negative_binomial_parameterization_preserves_requested_mean() -> None:
    mean = 3.5
    dispersion = 4.0

    n, probability = negative_binomial_parameters(mean, dispersion)
    calculated_mean = n * (1 - probability) / probability
    calculated_variance = n * (1 - probability) / probability**2

    assert calculated_mean == pytest.approx(mean)
    assert calculated_variance == pytest.approx(mean + mean**2 / dispersion)


def test_larger_dispersion_reduces_extra_burstiness() -> None:
    mean = 3.5
    low_n, low_probability = negative_binomial_parameters(mean, 1.0)
    high_n, high_probability = negative_binomial_parameters(mean, 20.0)

    low_variance = low_n * (1 - low_probability) / low_probability**2
    high_variance = high_n * (1 - high_probability) / high_probability**2

    assert high_variance < low_variance
