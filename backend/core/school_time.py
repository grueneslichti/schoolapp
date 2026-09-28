import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from models import SchoolHoliday

def is_school_time(db: Session = None, school_id: uuid.UUID = None) -> bool:
    now = datetime.now(timezone.utc)
    today = now.date()
    if now.weekday() >= 5:
        return False
    if db and school_id:
        holiday = db.query(SchoolHoliday).filter(
            SchoolHoliday.school_id == school_id,
            SchoolHoliday.start_date <= today,
            SchoolHoliday.end_date >= today,
        ).first()
        if holiday:
            return False
    return 8 <= now.hour < 15