import sys
from pathlib import Path
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

# Make src/ importable when Alembic runs from the app/ directory
sys.path.append(str(Path(__file__).resolve().parents[1]))

from src.core.config import settings, resolve_secrets
from src.db.session import Base
from src.models import item  # noqa: F401 — import registers the model with Base.metadata

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# WHY this call is REQUIRED here, not optional:
# settings.postgres_password starts out as whatever placeholder/env-var
# value was loaded — the REAL password only exists after this runs. Local
# dev was silently getting away without it because a working password
# often happened to already be sitting in .env from earlier testing. In
# AKS there is no .env fallback at all — without this call, the migration
# Job would try to connect with the "changeme" placeholder and fail
# outright. This was a real gap, not a hypothetical one.
resolve_secrets()

config.set_main_option("sqlalchemy.url", settings.database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=settings.database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
