"""
Seed-Skript für Shop-Items. Zum Testen
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core.database import SessionLocal
from models import ShopItem
from sqlalchemy import func

def seed_items():
    db = SessionLocal()
    try:
        existing = db.query(func.count(ShopItem.id)).scalar()
        if existing > 0:
            print(f"Es existieren bereits {existing} Items. Seed wird übersprungen.")
            return
        #Platzhalter
        items_data = [
            {"name": "Basecap", "icon": "🧢", "item_type": "hat", "cost_xp": 10, "rarity": "common", "is_fixed": False,
             "colors": '["#FF0000", "#0000FF", "#00AA00", "#333333", "#FFD700", "#FF69B4", "#00CED1"]'},
            {"name": "Zauberhut", "icon": "🎩", "item_type": "hat", "cost_xp": 25, "rarity": "rare", "is_fixed": False,
             "colors": '["#333333", "#4B0082", "#8B0000"]'},
            {"name": "Partyhut", "icon": "🥳", "item_type": "hat", "cost_xp": 15, "rarity": "common", "is_fixed": False,
             "colors": '["#FF69B4", "#FFD700", "#00CED1"]'},
            {"name": "Krone", "icon": "👑", "item_type": "hat", "cost_xp": 50, "rarity": "epic", "is_fixed": False,
             "colors": '["#FFD700", "#C0C0C0"]'},
            {"name": "Sonnenbrille", "icon": "🕶️", "item_type": "glasses", "cost_xp": 8, "rarity": "common", "is_fixed": False,
             "colors": '["#333333", "#FF0000", "#0000FF"]'},
            {"name": "Runde Brille", "icon": "👓", "item_type": "glasses", "cost_xp": 12, "rarity": "common", "is_fixed": False,
             "colors": '["#333333", "#8B4513", "#FFD700"]'},
            {"name": "Sterne-Brille", "icon": "⭐", "item_type": "glasses", "cost_xp": 30, "rarity": "rare", "is_fixed": False,
             "colors": '["#FFD700", "#FF69B4"]'},
            {"name": "Regenbogen", "icon": "🌈", "item_type": "background", "cost_xp": 20, "rarity": "rare", "is_fixed": True,
             "colors": '["#FF6B6B"]'},
            {"name": "Sterne", "icon": "✨", "item_type": "background", "cost_xp": 15, "rarity": "common", "is_fixed": True,
             "colors": '["#FFD700", "#C0C0C0", "#87CEEB"]'},
            {"name": "Weltraum", "icon": "🚀", "item_type": "background", "cost_xp": 35, "rarity": "epic", "is_fixed": True,
             "colors": '["#191970", "#4B0082"]'},
            {"name": "Wiese", "icon": "🌿", "item_type": "background", "cost_xp": 12, "rarity": "common", "is_fixed": True,
             "colors": '["#228B22", "#90EE90"]'},
            {"name": "Goldener Rahmen", "icon": "🖼️", "item_type": "frame", "cost_xp": 30, "rarity": "rare", "is_fixed": True,
             "colors": '["#FFD700", "#DAA520", "#B8860B", "#FFA500", "#FF8C00"]'},
            {"name": "Blumen-Rahmen", "icon": "🌸", "item_type": "frame", "cost_xp": 20, "rarity": "common", "is_fixed": True,
             "colors": '["#FF69B4", "#FF6347", "#9370DB", "#FF1493", "#DB7093"]'},
            {"name": "Regenbogen-Rahmen", "icon": "🌈", "item_type": "frame", "cost_xp": 40, "rarity": "epic", "is_fixed": True,
             "colors": '["#FF0000", "#FF7F00", "#FFFF00", "#00FF00", "#0000FF", "#8B00FF"]'},
            {"name": "Eis-Rahmen", "icon": "❄️", "item_type": "frame", "cost_xp": 25, "rarity": "rare", "is_fixed": True,
             "colors": '["#00CED1", "#87CEEB", "#ADD8E6", "#E0FFFF", "#B0E0E6"]'},
            {"name": "Feuer-Rahmen", "icon": "🔥", "item_type": "frame", "cost_xp": 35, "rarity": "rare", "is_fixed": True,
             "colors": '["#FF4500", "#FF6347", "#FF8C00", "#FFA500", "#FFD700"]'},
            {"name": "Stern", "icon": "⭐", "item_type": "sticker", "cost_xp": 5, "rarity": "common", "is_fixed": False,
             "colors": '["#FFD700", "#FF6347", "#00CED1"]'},
            {"name": "Herz", "icon": "❤️", "item_type": "sticker", "cost_xp": 5, "rarity": "common", "is_fixed": False,
             "colors": '["#FF0000", "#FF69B4"]'},
            {"name": "Blitz", "icon": "⚡", "item_type": "sticker", "cost_xp": 8, "rarity": "common", "is_fixed": False,
             "colors": '["#FFD700", "#00BFFF"]'},
            {"name": "Einhorn", "icon": "🦄", "item_type": "sticker", "cost_xp": 45, "rarity": "epic", "is_fixed": False,
             "colors": '["#FF69B4", "#9370DB"]'},
        ]
        for item_data in items_data:
            new_item = ShopItem(
                name=item_data["name"],
                icon=item_data["icon"],
                item_type=item_data["item_type"],
                cost_xp=item_data["cost_xp"],
                rarity=item_data["rarity"],
                is_fixed=item_data["is_fixed"],
                available_colors=item_data["colors"]
            )
            db.add(new_item) 
        db.commit()
        print(f"{len(items_data)} Shop-Items erfolgreich erstellt!")    
    except Exception as e:
        print(f"Fehler: {e}")
        db.rollback()
    finally:
        db.close()
if __name__ == "__main__":
    seed_items()