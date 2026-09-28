from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from models import Student, ShopItem, AvatarItem, Performance
import uuid

router = APIRouter(prefix="/shop", tags=["Avatar Shop"])

@router.get("/items")
def get_shop_items(db: Session = Depends(get_db)):
    items = db.query(ShopItem).all()
    return [
        {
            "id": str(item.id),
            "name": item.name,
            "icon": item.icon,
            "cost_xp": item.cost_xp,
            "item_type": item.item_type
        }
        for item in items
    ]

@router.post("/buy/{item_id}")
def buy_item(
    item_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    shop_item = db.query(ShopItem).filter(ShopItem.id == item_id).first()
    if not shop_item:
        raise HTTPException(status_code=404, detail="Item nicht gefunden")
    already_owned = db.query(AvatarItem).filter(
        AvatarItem.student_id == current_student.id,
        AvatarItem.item_id == str(shop_item.id)
    ).first()
    if already_owned:
        raise HTTPException(status_code=400, detail="Du besitzt dieses Item bereits!")
    performance = db.query(Performance).filter(Performance.student_id == current_student.id).first()
    if not performance or performance.xp < shop_item.cost_xp:
        raise HTTPException(status_code=400, detail="Nicht genug XP!")
    performance.xp -= shop_item.cost_xp
    new_avatar_item = AvatarItem(
        student_id=current_student.id,
        item_id=str(shop_item.id),
        item_type=shop_item.item_type,
        is_equipped=False
    )
    db.add(new_avatar_item)
    db.commit()
    return {
        "message": f"{shop_item.name} erfolgreich gekauft!",
        "remaining_xp": performance.xp
    }