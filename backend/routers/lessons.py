from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_current_student
from core.config import settings
from models import Teacher, Student, SchoolClass, LessonSignal, LessonRating
from schemas import (
    LessonSignalCreate, LessonSignalResponse,
    LessonRatingCreate, LessonRatingResponse,
    ActiveSignalResponse, RatingSummary
)
import uuid
from datetime import datetime, timedelta, timezone, date

router = APIRouter(prefix="/lessons", tags=["Lessons"])

def make_aware(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt

@router.post("/signal-end", response_model=LessonSignalResponse, status_code=status.HTTP_201_CREATED)
def signal_lesson_end(
    data: LessonSignalCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    now = datetime.now(timezone.utc)
    active_signals = db.query(LessonSignal).filter(
        LessonSignal.class_id == data.class_id
    ).all()  
    for signal in active_signals:
        aware_signal_time = make_aware(signal.signal_time)
        window_end = aware_signal_time + timedelta(minutes=signal.window_minutes)
        if window_end > now:
            raise HTTPException(
                status_code=400, 
                detail=f"Es gibt bereits ein aktives Signal für '{signal.subject}'."
            )   
    new_signal = LessonSignal(
        class_id=data.class_id,
        teacher_id=current_teacher.id,
        subject=data.subject,
        window_minutes=data.window_minutes
    )
    db.add(new_signal)
    db.commit()
    db.refresh(new_signal)  
    return LessonSignalResponse(
        id=new_signal.id,
        class_id=new_signal.class_id,
        subject=new_signal.subject,
        signal_time=new_signal.signal_time,
        window_minutes=new_signal.window_minutes,
        is_active=True
    )

@router.get("/active-signal", response_model=ActiveSignalResponse)
def get_active_signal(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    now = datetime.now(timezone.utc)
    
    signals = db.query(LessonSignal).filter(
        LessonSignal.class_id == current_student.class_id
    ).order_by(LessonSignal.signal_time.desc()).all()
    for signal in signals:
        aware_signal_time = make_aware(signal.signal_time)
        window_end = aware_signal_time + timedelta(minutes=signal.window_minutes)  
        if window_end > now:
            existing_rating = db.query(LessonRating).filter(
                LessonRating.signal_id == signal.id,
                LessonRating.student_id == current_student.id
            ).first()  
            if existing_rating:
                return ActiveSignalResponse(has_active_signal=False)    
            remaining = int((window_end - now).total_seconds())
            return ActiveSignalResponse(
                has_active_signal=True,
                signal_id=str(signal.id),
                subject=signal.subject,
                time_remaining_seconds=remaining
            )
    return ActiveSignalResponse(has_active_signal=False)

@router.get("/unrated-today")
def get_unrated_today(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)
    signals = db.query(LessonSignal).filter(
        LessonSignal.class_id == current_student.class_id,
        LessonSignal.signal_time >= today_start,
        LessonSignal.signal_time < tomorrow_start,
    ).order_by(LessonSignal.signal_time.desc()).all()
    unrated = []
    for signal in signals:
        existing = db.query(LessonRating).filter(
            LessonRating.signal_id == signal.id,
            LessonRating.student_id == current_student.id
        ).first()    
        if not existing:
            unrated.append({
                "signal_id": str(signal.id),
                "subject": signal.subject,
                "signal_time": make_aware(signal.signal_time).isoformat()
            })
    return {"unrated_signals": unrated, "count": len(unrated)}

@router.post("/rate", response_model=LessonRatingResponse, status_code=status.HTTP_201_CREATED)
def rate_lesson(
    data: LessonRatingCreate,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    signal = db.query(LessonSignal).filter(LessonSignal.id == data.signal_id).first()
    if not signal:
        raise HTTPException(status_code=404, detail="Signal nicht gefunden")
    
    if signal.class_id != current_student.class_id:
        raise HTTPException(status_code=403, detail="Du bist nicht in dieser Klasse")
    now = datetime.now(timezone.utc)
    signal_time = make_aware(signal.signal_time)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)
    if signal_time < today_start or signal_time >= tomorrow_start:
        raise HTTPException(
            status_code=400,
            detail="Diese Stunde kann nur am selben Tag bewertet werden.",
        )
    existing = db.query(LessonRating).filter(
        LessonRating.signal_id == data.signal_id,
        LessonRating.student_id == current_student.id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Du hast diese Stunde bereits bewertet")
    is_neutral = data.is_neutral if hasattr(data, 'is_neutral') else False
    rating_value = None if is_neutral else data.rating
    new_rating = LessonRating(
        signal_id=data.signal_id,
        student_id=current_student.id,
        rating=rating_value,
        is_neutral=is_neutral,
        comment=data.comment
    )
    db.add(new_rating)
    xp_reward = settings.XP_PER_RATING
    current_student.xp = (current_student.xp or 0) + xp_reward
    db.commit()
    db.refresh(new_rating)
    return LessonRatingResponse(
        id=new_rating.id,
        rating=new_rating.rating,
        is_neutral=new_rating.is_neutral,
        comment=new_rating.comment,
        created_at=new_rating.created_at,
        xp_earned=xp_reward
    )

@router.get("/ratings/class/{class_id}", response_model=list[RatingSummary])
def get_class_ratings(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    signals = db.query(LessonSignal).filter(
        LessonSignal.class_id == class_id
    ).order_by(LessonSignal.signal_time.desc()).limit(50).all()
    result = []
    for signal in signals:
        ratings = db.query(LessonRating).filter(
            LessonRating.signal_id == signal.id
        ).all()
        valid_ratings = [r.rating for r in ratings if not r.is_neutral and r.rating is not None]
        avg = sum(valid_ratings) / len(valid_ratings) if valid_ratings else 0.0
        neutral_count = sum(1 for r in ratings if r.is_neutral) 
        result.append(RatingSummary(
            signal_id=str(signal.id),
            subject=signal.subject,
            signal_time=signal.signal_time,
            total_ratings=len(ratings),
            average_rating=round(avg, 2),
            neutral_count=neutral_count,
            ratings=[LessonRatingResponse(
                id=r.id,
                rating=r.rating,
                is_neutral=r.is_neutral,
                comment=r.comment,
                created_at=r.created_at,
                xp_earned=0
            ) for r in ratings]
        ))
    return result