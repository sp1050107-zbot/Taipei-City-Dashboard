#!/usr/bin/env python3
"""Verifies docker-compose-db.yaml exposes the host ports Phase 2's native BE needs."""
import pathlib

COMPOSE = pathlib.Path(__file__).parent / "docker-compose-db.yaml"


def _service_block(text, name, next_name):
    return text.split(f"{name}:")[1].split(f"{next_name}:")[0]


def test_postgres_data_port_mapped():
    block = _service_block(COMPOSE.read_text(), "  postgres-data", "  postgres-manager")
    assert '"5433:5432"' in block, "postgres-data must publish host port 5433 -> 5432"


def test_redis_port_mapped():
    block = _service_block(COMPOSE.read_text(), "  redis", "  postgres-data")
    assert '"6379:6379"' in block, "redis must publish host port 6379 -> 6379"


def test_postgres_manager_port_unchanged():
    block = _service_block(COMPOSE.read_text(), "  postgres-manager", "  pgadmin")
    assert '"5432:5432"' in block, "postgres-manager host port mapping must stay 5432:5432"


def test_volumes_and_container_names_unchanged():
    text = COMPOSE.read_text()
    for needle in (
        "container_name: redis", "container_name: postgres-data",
        "- redis-data:/data", "- postgres-data:/var/lib/postgresql/data",
    ):
        assert needle in text, f"missing {needle}"


if __name__ == "__main__":
    test_postgres_data_port_mapped()
    test_redis_port_mapped()
    test_postgres_manager_port_unchanged()
    test_volumes_and_container_names_unchanged()
    print("PASS")
