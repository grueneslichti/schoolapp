# app/crud/avatar_items.py
from sqlalchemy.orm import Session
from schemas import models, schemas
from typing import List
import uuid

def unlock_item(db: Session, student_id: uuid.UUID, item_id: str, item_type: str) -> models.AvatarItem:
    existing_item = (
        db.query(models.AvatarItem)
        .filter(models.AvatarItem.student_id == student_id, models.AvatarItem.item_id == item_id)
        .first()
    )  
    if existing_item:
        return existing_item
    db_item = models.AvatarItem(
        student_id=student_id,
        item_id=item_id,
        item_type=item_type,
        is_equipped=False
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

def get_items_for_student(db: Session, student_id: uuid.UUID) -> List[models.AvatarItem]:
    return db.query(models.AvatarItem).filter(models.AvatarItem.student_id == student_id).all()

def equip_item(db: Session, student_id: uuid.UUID, item_id: str) -> models.AvatarItem:
    target_item = (
        db.query(models.AvatarItem)
        .filter(models.AvatarItem.student_id == student_id, models.AvatarItem.item_id == item_id)
        .first()
    ) 
    if not target_item:
        raise ValueError("Item nicht im Inventar des Schülers gefunden.")
    db.query(models.AvatarItem).filter(
        models.AvatarItem.student_id == student_id,
        models.AvatarItem.item_type == target_item.item_type,
        models.AvatarItem.is_equipped == True
    ).update({"is_equipped": False})
    target_item.is_equipped = True
    db.commit()
    db.refresh(target_item)
    return target_item

def remove_item(db: Session, student_id: uuid.UUID, item_id: str) -> bool:

    result = db.query(models.AvatarItem).filter(
        models.AvatarItem.student_id == student_id, 
        models.AvatarItem.item_id == item_id
    ).delete()
    db.commit()
    return result > 0