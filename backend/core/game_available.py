from datetime import datetime
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from models import ScheduleEntry, SchoolClass, SchoolHoliday
import uuid

GERMAN_TZ = ZoneInfo("Europe/Berlin") #Zeitzone anpassen
#Anpassen an echten Star/Endzeit der Schule
FALLBACK_SCHOOL_START = 7
FALLBACK_SCHOOL_END = 16

def get_game_availability(db: Session, class_id: uuid.UUID) -> dict:
    now = datetime.now(GERMAN_TZ)
    if now.weekday() >= 6:
        return {"available": True, "reason": "Wochenende"}
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if school_class:
        today = now.date()
        holiday = db.query(SchoolHoliday).filter(
            SchoolHoliday.school_id == school_class.school_id,
            SchoolHoliday.start_date <= today,
            SchoolHoliday.end_date >= today
        ).first()
        if holiday:
            return {"available": True, "reason": f"Ferien ({holiday.name})"}
    current_weekday = now.weekday()
    current_time = now.time()
    entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == class_id,
        ScheduleEntry.day_of_week == current_weekday
    ).order_by(ScheduleEntry.start_time).all()
    if not entries:
        if FALLBACK_SCHOOL_START <= now.hour < FALLBACK_SCHOOL_END:
            return {
                "available": False,
                "reason": "Schulzeit (Fallback)",
                "free_at": f"{FALLBACK_SCHOOL_END}:00"
            }
        return {"available": True, "reason": "Nach der Schule (Fallback)"}
    for entry in entries:
        start = entry.start_time
        end = entry.end_time
        if isinstance(start, datetime):
            start = start.time()
        if isinstance(end, datetime):
            end = end.time()
        if start <= current_time <= end:
            return {
                "available": False,
                "reason": f"Unterricht: {entry.subject if hasattr(entry, 'subject') else ''}",
                "free_at": end.strftime("%H:%M")
            }
    return {"available": True, "reason": "Freistunde / Pause"}