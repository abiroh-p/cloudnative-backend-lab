# WHY this file exists:
# This is the ONE place the app talks to the database engine. Every part of
# the app that needs a DB session imports get_db() from here — centralizing
# it means connection pooling, retries, or a DB swap only ever needs to
# change in one file.

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from src.core.config import settings

# pool_size / max_overflow: SQLAlchemy maintains a pool of open DB
# connections rather than opening a new TCP connection per request (that
# would be slow and would exhaust Postgres's max_connections under load).
# These numbers are deliberately small since this is a learning/single-node
# setup — a production service would tune these against real traffic.
engine = create_engine(
    settings.database_url,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,   # checks connection is alive before using it —
                           # avoids "server closed the connection" errors after idle periods
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Base class every ORM model inherits from."""
    pass


def get_db():
    """
    FastAPI dependency — yields a DB session, guarantees it's closed after
    the request finishes even if the request raises an exception.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
