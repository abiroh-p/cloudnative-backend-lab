# WHY separate schemas from the ORM model:
# The ORM model (models/item.py) describes the DATABASE table. This file
# describes the API's request/response SHAPE. They usually overlap a lot,
# but keeping them separate means you can, e.g., hide internal fields from
# API responses, or accept a request field that doesn't map 1:1 to a column
# — without those two concerns fighting each other in one class.

from datetime import datetime
from pydantic import BaseModel, ConfigDict


class ItemCreate(BaseModel):
    name: str
    description: str | None = None


class ItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)  # lets Pydantic read directly from ORM objects

    id: int
    name: str
    description: str | None
    created_at: datetime
