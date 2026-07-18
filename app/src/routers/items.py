# WHY a router instead of putting routes in main.py:
# FastAPI's APIRouter lets you group related endpoints and mount them onto
# the main app. Trivial with one resource, but this is the pattern that
# keeps main.py from becoming a 1000-line file once you have items, users,
# auth, etc. — worth building the habit now.

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.db.session import get_db
from src.models.item import Item
from src.models.schemas import ItemCreate, ItemResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/items", tags=["items"])


@router.post("", response_model=ItemResponse, status_code=201)
def create_item(payload: ItemCreate, db: Session = Depends(get_db)):
    item = Item(name=payload.name, description=payload.description)
    db.add(item)
    db.commit()
    db.refresh(item)   # pulls back DB-generated fields (id, created_at)
    logger.info("item_created", extra={"item_id": item.id})
    return item


@router.get("", response_model=list[ItemResponse])
def list_items(db: Session = Depends(get_db)):
    return db.execute(select(Item).order_by(Item.id)).scalars().all()


@router.get("/{item_id}", response_model=ItemResponse)
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.delete("/{item_id}", status_code=204)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    db.delete(item)
    db.commit()
    logger.info("item_deleted", extra={"item_id": item_id})
