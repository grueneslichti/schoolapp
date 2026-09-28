from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from models import Student, FocusSession
from schemas import FocusSessionCreate, FocusSessionResponse, FocusCompleteResponse
import uuid
import math

router = APIRouter(prefix="/focus", tags=["Focus Mode"])
XP_MULTIPLIERS = {
    15: 0.4,
    30: 0.6,
    45: 1.0,
}
MIN_MINUTES_FOR_XP = 10

def calculate_xp(planned_minutes: int, actual_minutes: int) -> int:
    if actual_minutes < MIN_MINUTES_FOR_XP:
        return 0
    multiplier = XP_MULTIPLIERS.get(planned_minutes, 0.4)
    completion_ratio = actual_minutes / planned_minutes
    raw_xp = actual_minutes * multiplier * completion_ratio
    return max(0, math.ceil(raw_xp))

@router.post("/complete", response_model=FocusCompleteResponse)
def complete_focus_session(
    session_data: FocusSessionCreate,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    actual = min(session_data.actual_minutes, session_data.planned_minutes)
    xp_earned = calculate_xp(session_data.planned_minutes, actual)
    focus_session = FocusSession(
        student_id=current_student.id,
        planned_minutes=session_data.planned_minutes,
        actual_minutes=actual,
        xp_earned=xp_earned,
        completed=session_data.completed
    )
    db.add(focus_session)
    current_student.xp = (current_student.xp or 0) + xp_earned
    db.commit()
    db.refresh(current_student)
    if xp_earned == 0:
        message = "Schade, das war zu kurz für XP. Konzentriere dich länger"
    elif session_data.completed:
        message = f"Super! Du hast die vollen {session_data.planned_minutes} Minuten durchgehalten und {xp_earned} XP verdient!"
    else:
        message = f"Gut gemacht! Du hast {actual} Minuten fokussiert gelernt und {xp_earned} XP verdient."
    
    return FocusCompleteResponse(
        xp_earned=xp_earned,
        total_xp=current_student.xp,
        message=message
    )

@router.get("/history", response_model=list[FocusSessionResponse])
def get_focus_history(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    sessions = db.query(FocusSession).filter(
        FocusSession.student_id == current_student.id
    ).order_by(FocusSession.created_at.desc()).limit(20).all()
    
    return [FocusSessionResponse.model_validate(s) for s in sessions]

@router.get("/my-xp")
def get_my_xp(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    return {
        "xp": current_student.xp or 0,
        "pseudonym": current_student.pseudonym
    }