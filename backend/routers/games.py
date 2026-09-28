from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from datetime import datetime, timezone, timedelta
from core.database import get_db
from core.game_available import get_game_availability
from core.security.security import get_current_student
from models import Student, SchoolClass, GameHighscore, GameUnlock
from schemas import SubmitScoreRequest, SubmitScoreResponse, HighscoreEntry, ClassHighscoresResponse
import uuid
from core.task_generator import generate_task
from core.school_time import is_school_time

GAME_COSTS = {
    "number_hunt": 1000,
    "mathe_jagd": 1000,
    "function_master": 1000,
}
TRIAL_MINUTES = 5
router = APIRouter(prefix="/games", tags=["Games"])
DAILY_GAME_XP_LIMIT = 10

@router.get("/access/{game_type}")
def get_game_access(
    game_type: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if game_type not in GAME_COSTS:
        raise HTTPException(status_code=400, detail="Unbekanntes Spiel")
    availability = get_game_availability(db, current_student.class_id)
    unlock = db.query(GameUnlock).filter(
        GameUnlock.student_id == current_student.id,
        GameUnlock.game_type == game_type
    ).first()
    is_unlocked = unlock.is_unlocked if unlock else False
    trial_active = False
    trial_seconds_remaining = 0
    if unlock and unlock.trial_started_at and not is_unlocked:
        trial_end = unlock.trial_started_at + timedelta(minutes=TRIAL_MINUTES)
        now = datetime.now(timezone.utc)
        if trial_end.tzinfo is None:
            trial_end = trial_end.replace(tzinfo=timezone.utc)
        if now < trial_end:
            trial_active = True
            trial_seconds_remaining = int((trial_end - now).total_seconds())
    can_play = availability["available"] and (is_unlocked or trial_active)
    return {
        "game_type": game_type,
        "time_available": availability["available"],
        "time_reason": availability["reason"],
        "free_at": availability.get("free_at"),
        "is_unlocked": is_unlocked,
        "trial_active": trial_active,
        "trial_seconds_remaining": trial_seconds_remaining,
        "trial_started": bool(unlock and unlock.trial_started_at),
        "unlock_cost": GAME_COSTS[game_type],
        "student_xp": current_student.xp or 0,
        "can_play": can_play
    }
@router.post("/start-trial/{game_type}")
def start_trial(
    game_type: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if game_type not in GAME_COSTS:
        raise HTTPException(status_code=400, detail="Unbekanntes Spiel") 
    unlock = db.query(GameUnlock).filter(
        GameUnlock.student_id == current_student.id,
        GameUnlock.game_type == game_type
    ).first()
    if not unlock:
        unlock = GameUnlock(
            student_id=current_student.id,
            game_type=game_type
        )
        db.add(unlock)  
    if unlock.is_unlocked:
        return {"message": "Bereits freigeschaltet"}
    if unlock.trial_started_at:
        return {"message": "Testphase bereits gestartet"}   
    unlock.trial_started_at = datetime.now(timezone.utc)
    db.commit()
    return {
        "message": f"Testphase gestartet! Du hast {TRIAL_MINUTES} Minuten.",
        "trial_seconds_remaining": TRIAL_MINUTES * 60
    }
@router.post("/unlock/{game_type}")
def unlock_game(
    game_type: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if game_type not in GAME_COSTS:
        raise HTTPException(status_code=400, detail="Unbekanntes Spiel")
    cost = GAME_COSTS[game_type]
    student_xp = current_student.xp or 0
    if student_xp < cost:
        raise HTTPException(
            status_code=400,
            detail=f"Nicht genug XP! Du brauchst {cost}, hast aber nur {student_xp}."
        )  
    unlock = db.query(GameUnlock).filter(
        GameUnlock.student_id == current_student.id,
        GameUnlock.game_type == game_type
    ).first()
    if not unlock:
        unlock = GameUnlock(student_id=current_student.id, game_type=game_type)
        db.add(unlock)
    if unlock.is_unlocked:
        return {"message": "Bereits freigeschaltet"}
    current_student.xp = student_xp - cost
    unlock.is_unlocked = True
    unlock.unlocked_at = datetime.now(timezone.utc)
    db.commit()
    return {
        "message": f"Spiel freigeschaltet für {cost} XP!",
        "remaining_xp": current_student.xp
    }

def calculate_xp(score: int) -> int:
    return max(1, score // 1000)

def get_daily_game_xp(db: Session, student_id: uuid.UUID) -> int:
    today = datetime.now(timezone.utc).date()
    earned = db.query(func.coalesce(func.sum(GameHighscore.xp_earned), 0)).filter(
        GameHighscore.student_id == student_id,
        func.date(GameHighscore.created_at) == today,
    ).scalar()
    return int(earned or 0)

@router.post("/submit-score", response_model=SubmitScoreResponse)
def submit_score(
    data: SubmitScoreRequest,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(
        SchoolClass.id == current_student.class_id
    ).first()  
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    daily_xp = get_daily_game_xp(db, current_student.id)
    xp_earned = min(calculate_xp(data.score), max(0, DAILY_GAME_XP_LIMIT - daily_xp))
    existing_best = db.query(GameHighscore).filter(
        GameHighscore.class_id == current_student.class_id,
        GameHighscore.game_type == data.game_type,
        GameHighscore.difficulty == data.difficulty
    ).order_by(GameHighscore.score.desc()).first()
    is_new_record = existing_best is None or data.score > existing_best.score
    new_highscore = GameHighscore(
        student_id=current_student.id,
        class_id=current_student.class_id,
        game_type=data.game_type,
        difficulty=data.difficulty,
        score=data.score,
        xp_earned=xp_earned
    )
    db.add(new_highscore)
    current_student.xp = (current_student.xp or 0) + xp_earned
    db.commit()
    my_rank = db.query(GameHighscore).filter(
        GameHighscore.class_id == current_student.class_id,
        GameHighscore.game_type == data.game_type,
        GameHighscore.difficulty == data.difficulty,
        GameHighscore.score > data.score
    ).count() + 1
    return SubmitScoreResponse(
        success=True,
        xp_earned=xp_earned,
        total_xp=current_student.xp,
        is_new_class_record=is_new_record,
        class_rank=my_rank
    )
@router.get("/highscores/{game_type}/{difficulty}", response_model=ClassHighscoresResponse)
def get_class_highscores(
    game_type: str,
    difficulty: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    highscores = db.query(GameHighscore).filter(
        GameHighscore.class_id == current_student.class_id,
        GameHighscore.game_type == game_type,
        GameHighscore.difficulty == difficulty
    ).order_by(GameHighscore.score.desc()).limit(10).all()
    top_scores = []
    for rank, hs in enumerate(highscores, 1):
        student = db.query(Student).filter(Student.id == hs.student_id).first()
        top_scores.append(HighscoreEntry(
            rank=rank,
            student_name=student.real_name if student else "Unbekannt",
            pseudonym=student.pseudonym if student else "Unbekannt",
            score=hs.score,
            difficulty=hs.difficulty,
            created_at=hs.created_at,
            is_me=(hs.student_id == current_student.id)
        ))
    my_best = db.query(GameHighscore).filter(
        GameHighscore.student_id == current_student.id,
        GameHighscore.game_type == game_type,
        GameHighscore.difficulty == difficulty
    ).order_by(GameHighscore.score.desc()).first() 
    total_players = db.query(GameHighscore.student_id).filter(
        GameHighscore.class_id == current_student.class_id,
        GameHighscore.game_type == game_type,
        GameHighscore.difficulty == difficulty
    ).distinct().count()
    my_rank = None
    if my_best:
        my_rank = db.query(GameHighscore).filter(
            GameHighscore.class_id == current_student.class_id,
            GameHighscore.game_type == game_type,
            GameHighscore.difficulty == difficulty,
            GameHighscore.score > my_best.score
        ).count() + 1
    return ClassHighscoresResponse(
        game_type=game_type,
        difficulty=difficulty,
        top_scores=top_scores,
        my_best_score=my_best.score if my_best else None,
        my_rank=my_rank,
        total_players=total_players
    )
POINTS_BY_DIFFICULTY = {
    "easy": 1,
    "medium": 2,
    "hard": 3
}

@router.get("/functions/task")
def get_function_task(
    difficulty: str = "easy",
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(
        SchoolClass.id == current_student.class_id
    ).first()
    school_id = school_class.school_id if school_class else None
    if is_school_time(db, school_id):
        availability = get_game_availability(db, current_student.class_id)
    if not availability["available"]:
        raise HTTPException(
            status_code=403,
            detail=f"Spiele sind gerade gesperrt ({availability['reason']}). Frei ab {availability.get('free_at', 'später')}."
        )
    if difficulty not in ["easy", "medium", "hard"]:
        difficulty = "easy"
    task = generate_task(difficulty)
    return {
        "difficulty": difficulty,
        "task_type": task["task_type"],
        "question": task["question"],
        "options": task["options"],
        "correct_answer": task["correct_answer"],
        "graph_type": task["graph_type"],
        "graph_points": task.get("graph_points"),
        "graph_lines": task.get("graph_lines"),
        "points_reward": POINTS_BY_DIFFICULTY[difficulty]
    }

@router.post("/functions/submit")
def submit_function_answer(
    answer: str,
    correct_answer: str,
    difficulty: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    is_correct = answer.strip() == correct_answer.strip()
    points_earned = POINTS_BY_DIFFICULTY.get(difficulty, POINTS_BY_DIFFICULTY["easy"]) if is_correct else 0
    old_xp_threshold = (current_student.function_points or 0) // 100
    current_student.function_points = (current_student.function_points or 0) + points_earned
    new_xp_threshold = current_student.function_points // 100
    xp_earned = new_xp_threshold - old_xp_threshold
    current_student.xp = (current_student.xp or 0) + xp_earned
    db.commit() 
    return {
        "is_correct": is_correct,
        "points_earned": points_earned,
        "total_function_points": current_student.function_points,
        "xp_earned": xp_earned,
        "total_xp": current_student.xp
    }

@router.get("/my-highscores/{game_type}")
def get_my_highscores(
    game_type: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    highscores = db.query(GameHighscore).filter(
        GameHighscore.student_id == current_student.id,
        GameHighscore.game_type == game_type
    ).order_by(GameHighscore.score.desc()).limit(5).all()
    return {
        "game_type": game_type,
        "highscores": [{
            "score": hs.score,
            "difficulty": hs.difficulty,
            "xp_earned": hs.xp_earned,
            "created_at": hs.created_at.isoformat()
        } for hs in highscores]
    }