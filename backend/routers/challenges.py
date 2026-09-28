from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from core.database import get_db
from core.security.security import get_current_student
from models import Student,SchoolHoliday, SchoolClass, School, DailyChallenge, QuizQuestion, ChallengeAttempt
from schemas import ChallengeResponse, QuizQuestionResponse, SubmitAnswerRequest, ChallengeStatusResponse
import uuid
from datetime import datetime, timezone, timedelta, date
from routers.games import DAILY_GAME_XP_LIMIT, get_daily_game_xp
from core.school_time import is_school_time

router = APIRouter(prefix="/challenges", tags=["Challenges"])

@router.get("/status", response_model=ChallengeStatusResponse)
def get_challenge_status(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == current_student.class_id).first()
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
    if school_time:
        message = "Mini-Spiele sind während der Unterrichtszeiten gesperrt."
        can_play = False
    elif daily_xp_remaining == 0:
        message = "Du hast heute bereits das Maximum von 100 Spiel-XP erreicht."
        can_play = False
    else:
        message = "Spiele verfügbar, viel spaß!"
        can_play = True
    return ChallengeStatusResponse(
        is_school_time=school_time,
        can_play=can_play,
        message=message,
        daily_xp_limit=DAILY_GAME_XP_LIMIT,
        daily_xp_earned=daily_xp_earned,
        daily_xp_remaining=daily_xp_remaining,
    )

@router.get("/daily", response_model=list[ChallengeResponse])
def get_daily_challenges(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    today = date.today()
    existing = db.query(DailyChallenge).filter(
        DailyChallenge.student_id == current_student.id,
        DailyChallenge.challenge_date == today
    ).all()   
    return

@router.get("/quiz/{challenge_id}", response_model=list[QuizQuestionResponse])
def get_quiz_questions(
    challenge_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):

@router.post("/submit-answer")
def submit_answer(
    data: SubmitAnswerRequest,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    # Schulzeit-Check
    if is_school_time():
        raise HTTPException(status_code=403, detail="Spiele sind während der Schulzeit gesperrt!")
    
    challenge = db.query(DailyChallenge).filter(
        DailyChallenge.id == data.challenge_id,
        DailyChallenge.student_id == current_student.id
    ).first()
    
    if not challenge or challenge.is_completed:
        raise HTTPException(status_code=400, detail="Challenge nicht verfügbar")
    
    question = db.query(QuizQuestion).filter(QuizQuestion.id == data.question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Frage nicht gefunden")
    is_correct = data.answer.lower() == question.correct_answer.lower()
    attempt = ChallengeAttempt(
        challenge_id=data.challenge_id,
        question_id=data.question_id,
        student_answer=data.answer,
        is_correct=is_correct
    )
    db.add(attempt)
    attempts_count = db.query(ChallengeAttempt).filter(
        ChallengeAttempt.challenge_id == data.challenge_id
    ).count()
    correct_count = db.query(ChallengeAttempt).filter(
        ChallengeAttempt.challenge_id == data.challenge_id,
        ChallengeAttempt.is_correct == True
    ).count()
    xp_earned = 0
    challenge_completed = False   
    if attempts_count >= 3:
        challenge.is_completed = True
        challenge.completed_at = datetime.now(timezone.utc)
        xp_earned = correct_count * 1
        current_student.xp = (current_student.xp or 0) + xp_earned
        challenge_completed = True    
    db.commit()   
    return {
        "is_correct": is_correct,
        "correct_answer": question.correct_answer,
        "attempts_count": attempts_count,
        "correct_count": correct_count,
        "challenge_completed": challenge_completed,
        "xp_earned": xp_earned
    }