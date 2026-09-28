from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from models import Student, ShopItem, AvatarItem
from schemas import ShopItemResponse, BuyItemRequest, BuyItemResponse, AvatarItemResponse, UpdatePositionRequest
import uuid
import json

router = APIRouter(prefix="/shop", tags=["Shop"])
@router.get("/items", response_model=list[ShopItemResponse])
def get_shop_items(db: Session = Depends(get_db)):
    items = db.query(ShopItem).filter(ShopItem.is_active == True).all()
    result = []
    for item in items:
        colors = json.loads(item.available_colors) if item.available_colors else ["#333333"]
        result.append(ShopItemResponse(
            id=item.id,
            name=item.name,
            icon=item.icon,
            item_type=item.item_type,
            cost_xp=item.cost_xp,
            rarity=item.rarity,
            available_colors=colors
        ))
    return result

@router.post("/buy", response_model=BuyItemResponse)
def buy_item(
    data: BuyItemRequest,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    shop_item = db.query(ShopItem).filter(
        ShopItem.id == data.shop_item_id,
        ShopItem.is_active == True
    ).first()
    if not shop_item:
        raise HTTPException(status_code=404, detail="Item nicht gefunden")
    available_colors = json.loads(shop_item.available_colors) if shop_item.available_colors else []
    if data.color not in available_colors:
        raise HTTPException(status_code=400, detail="Diese Farbe ist für das Item nicht verfügbar")
    student_xp = current_student.xp or 0
    if student_xp < shop_item.cost_xp:
        return BuyItemResponse(
            success=False,
            message=f"Nicht genug XP! Du brauchst {shop_item.cost_xp} XP, hast aber nur {student_xp}.",
            remaining_xp=student_xp
        )
    existing = db.query(AvatarItem).filter(
        AvatarItem.student_id == current_student.id,
        AvatarItem.shop_item_id == shop_item.id,
        AvatarItem.color == data.color
    ).first()
    if existing:
        return BuyItemResponse(
            success=False,
            message="Du besitzt dieses Item in dieser Farbe bereits!",
            remaining_xp=student_xp
        )
    current_student.xp = student_xp - shop_item.cost_xp
    new_item = AvatarItem(
        student_id=current_student.id,
        shop_item_id=shop_item.id,
        color=data.color,
        pos_x=0.5,
        pos_y=0.3,
        scale=1.0,
        is_equipped=False
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return BuyItemResponse(
        success=True,
        message=f"'{shop_item.name}' gekauft für {shop_item.cost_xp} XP!",
        avatar_item_id=new_item.id,
        remaining_xp=current_student.xp
    )
@router.get("/my-items", response_model=list[AvatarItemResponse])
def get_my_items(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    items = db.query(AvatarItem).filter(
        AvatarItem.student_id == current_student.id
    ).order_by(AvatarItem.unlocked_at.desc()).all()
    result = []
    for item in items:
        shop_item = db.query(ShopItem).filter(ShopItem.id == item.shop_item_id).first()
        result.append(AvatarItemResponse(
            id=item.id,
            shop_item_id=item.shop_item_id,
            name=shop_item.name if shop_item else "Unbekannt",
            icon=shop_item.icon if shop_item else "?",
            item_type=shop_item.item_type if shop_item else "unknown",
            color=item.color,
            rarity=shop_item.rarity if shop_item else "common",
            pos_x=item.pos_x,
            pos_y=item.pos_y,
            scale=item.scale,
            is_equipped=item.is_equipped
        ))
    return result

@router.post("/equip/{item_id}")
def toggle_equip(
    item_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    item = db.query(AvatarItem).filter(
        AvatarItem.id == item_id,
        AvatarItem.student_id == current_student.id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item nicht gefunden")
    item.is_equipped = not item.is_equipped
    db.commit()
    return {"message": "Item angelegt" if item.is_equipped else "Item abgelegt", "is_equipped": item.is_equipped}

@router.put("/position/{item_id}")
def update_position(
    item_id: uuid.UUID,
    data: UpdatePositionRequest,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    item = db.query(AvatarItem).filter(
        AvatarItem.id == item_id,
        AvatarItem.student_id == current_student.id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item nicht gefunden")
    item.pos_x = max(0.0, min(1.0, data.pos_x))
    item.pos_y = max(0.0, min(1.0, data.pos_y))
    item.scale = max(0.2, min(3.0, data.scale))
    db.commit()
    return {"message": "Position aktualisiert"}

#SHOP-ITEMS ERSTELLEN (für Admin/Setup)
@router.post("/seed-items")
def seed_shop_items(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    existing = db.query(ShopItem).count()
    if existing > 0:
        return {"message": f"Es existieren bereits {existing} Items. Seed übersprungen."}
    items_data = [
        # Platzhalter
        {"name": "Basecap", "icon": "🧢", "item_type": "hat", "cost_xp": 10, "rarity": "common",
         "colors": '["#FF0000", "#0000FF", "#00AA00", "#333333", "#FFD700"]'},
        {"name": "Zauberhut", "icon": "🎩", "item_type": "hat", "cost_xp": 25, "rarity": "rare",
         "colors": '["#333333", "#4B0082", "#8B0000"]'},
        {"name": "Partyhut", "icon": "🥳", "item_type": "hat", "cost_xp": 15, "rarity": "common",
         "colors": '["#FF69B4", "#FFD700", "#00CED1"]'},
        {"name": "Krone", "icon": "👑", "item_type": "hat", "cost_xp": 50, "rarity": "epic",
         "colors": '["#FFD700", "#C0C0C0"]'},
        {"name": "Sonnenbrille", "icon": "🕶️", "item_type": "glasses", "cost_xp": 8, "rarity": "common",
         "colors": '["#333333", "#FF0000", "#0000FF"]'},
        {"name": "Runde Brille", "icon": "👓", "item_type": "glasses", "cost_xp": 12, "rarity": "common",
         "colors": '["#333333", "#8B4513", "#FFD700"]'},
        {"name": "Sterne-Brille", "icon": "⭐", "item_type": "glasses", "cost_xp": 30, "rarity": "rare",
         "colors": '["#FFD700", "#FF69B4"]'},

        {"name": "Regenbogen", "icon": "🌈", "item_type": "background", "cost_xp": 20, "rarity": "rare",
         "colors": '["#FF0000"]'},
        {"name": "Sterne", "icon": "✨", "item_type": "background", "cost_xp": 15, "rarity": "common",
         "colors": '["#FFD700", "#C0C0C0"]'},
        {"name": "Weltraum", "icon": "🚀", "item_type": "background", "cost_xp": 35, "rarity": "epic",
         "colors": '["#191970"]'},
        {"name": "Goldener Rahmen", "icon": "🖼️", "item_type": "frame", "cost_xp": 20, "rarity": "rare",
         "colors": '["#FFD700"]'},
        {"name": "Blumen-Rahmen", "icon": "🌸", "item_type": "frame", "cost_xp": 30, "rarity": "common",
         "colors": '["#FF69B4", "#FF6347", "#9370DB"]'},
        {"name": "Stern", "icon": "⭐", "item_type": "sticker", "cost_xp": 5, "rarity": "common",
         "colors": '["#FFD700", "#FF6347", "#00CED1"]'},
        {"name": "Herz", "icon": "❤️", "item_type": "sticker", "cost_xp": 5, "rarity": "common",
         "colors": '["#FF0000", "#FF69B4"]'},
        {"name": "Blitz", "icon": "⚡", "item_type": "sticker", "cost_xp": 8, "rarity": "common",
         "colors": '["#FFD700", "#00BFFF"]'},
        {"name": "Einmal-Einhorn", "icon": "🦄", "item_type": "sticker", "cost_xp": 45, "rarity": "epic",
         "colors": '["#FF69B4", "#9370DB"]'},
    ]
    for item_data in items_data:
        new_item = ShopItem(
            name=item_data["name"],
            icon=item_data["icon"],
            item_type=item_data["item_type"],
            cost_xp=item_data["cost_xp"],
            rarity=item_data["rarity"],
            available_colors=item_data["colors"]
        )
        db.add(new_item)
    db.commit()
    return {"message": f"{len(items_data)} Shop-Items erstellt!"}