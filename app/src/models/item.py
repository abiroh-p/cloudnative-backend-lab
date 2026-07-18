# WHY a generic "Item" model:
# Kept domain-neutral on purpose — the point of this stage is proving out
# the DB/API plumbing (CRUD, migrations, indexing), not designing a real
# product schema. Swap this for a real domain model later without touching
# anything in db/ or core/.

from datetime import datetime, timezone

from sqlalchemy import String, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column

from src.db.session import Base


class Item(Base):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
