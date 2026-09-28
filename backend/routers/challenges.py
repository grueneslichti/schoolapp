from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from models import Student, SchoolHoliday, SchoolClass
from schemas import ChallengeStatusResponse
from datetime import datetime, timezone
from routers.games import DAILY_GAME_XP_LIMIT, get_daily_game_xp
from core.school_time import is_school_time

router = APIRouter(prefix="/challenges", tags=["Challenges"])

@router.get("/status", response_model=ChallengeStatusResponse)
def get_challenge_status(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(
        SchoolClass.id == current_student.class_id
    ).first()
    school_id = school_class.school_id if school_class else None
    school_time = is_school_time(db, school_id)
    is_holiday = False
    if school_id:
        today = datetime.now(timezone.utc).date()
        holiday = db.query(SchoolHoliday).filter(
            SchoolHoliday.school_id == school_id,
            SchoolHoliday.start_date <= today,
            SchoolHoliday.end_date >= today
        ).first()
        is_holiday = holiday is not None
    daily_xp_earned = get_daily_game_xp(db, current_student.id)
    daily_xp_remaining = max(0, DAILY_GAME_XP_LIMIT - daily_xp_earned)
    if school_time and not is_holiday:
        message = "Mini-Spiele sind während der Unterrichtszeiten gesperrt."
        can_play = False
    elif daily_xp_remaining == 0:
        message = "Du hast heute bereits das Maximum von Spiel-XP erreicht."
        can_play = False
    else:
        message = "Spiele verfügbar, viel Spaß!"
        can_play = True
    return ChallengeStatusResponse(
        is_school_time=school_time,
        can_play=can_play,
        message=message,
        daily_xp_limit=DAILY_GAME_XP_LIMIT,
        daily_xp_earned=daily_xp_earned,
        daily_xp_remaining=daily_xp_remaining,
    )