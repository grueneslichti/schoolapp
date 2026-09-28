from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_current_student, hash_student_id
from models import Teacher, Student, Feedback, SchoolClass, TeacherAssignment
from schemas import FeedbackCreate, FeedbackStudentResponse, FeedbackTeacherResponse
import uuid
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from pydantic import BaseModel

GERMAN_TZ = ZoneInfo("Europe/Berlin")

def to_german_time(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(GERMAN_TZ)
router = APIRouter(prefix="/feedbacks", tags=["Feedbacks"])
RESPONSIBLE_SUBJECT = "Zuständig"

def teacher_is_responsible(db: Session, teacher_id: uuid.UUID, class_id: uuid.UUID) -> bool:
    assignment = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == teacher_id,
        TeacherAssignment.class_id == class_id,
        TeacherAssignment.subject.ilike(RESPONSIBLE_SUBJECT)
    ).first()
    return assignment is not None

def get_responsible_class_ids(db: Session, teacher_id: uuid.UUID) -> list[uuid.UUID]:
    assignments = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == teacher_id,
        TeacherAssignment.subject.ilike(RESPONSIBLE_SUBJECT)
    ).all()
    return [a.class_id for a in assignments]

@router.post("/", response_model=FeedbackStudentResponse, status_code=status.HTTP_201_CREATED)
def create_feedback(
    feedback_data: FeedbackCreate,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    anonymous_hash = hash_student_id(str(current_student.id))
    student_name = None if feedback_data.is_anonymous else current_student.real_name 
    new_feedback = Feedback(
        student_hash=anonymous_hash,
        is_anonymous=feedback_data.is_anonymous,
        student_name=student_name,
        class_id=current_student.class_id,
        category=feedback_data.category,
        message=feedback_data.message
    )
    db.add(new_feedback)
    db.commit()
    db.refresh(new_feedback)  
    return FeedbackStudentResponse.model_validate(new_feedback)

@router.get("/my-feedbacks", response_model=list[FeedbackStudentResponse])
def get_my_feedbacks(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    anonymous_hash = hash_student_id(str(current_student.id))
    feedbacks = db.query(Feedback).filter(
        Feedback.student_hash == anonymous_hash
    ).order_by(Feedback.created_at.desc()).all()
    return [FeedbackStudentResponse.model_validate(f) for f in feedbacks]

@router.delete("/my-feedbacks/{feedback_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_own_feedback(
    feedback_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    anonymous_hash = hash_student_id(str(current_student.id))
    
    feedback = db.query(Feedback).filter(
        Feedback.id == feedback_id,
        Feedback.student_hash == anonymous_hash
    ).first()  
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback nicht gefunden")
    
    db.delete(feedback)
    db.commit()
    return None

@router.get("/inbox", response_model=list[FeedbackTeacherResponse])
def get_my_inbox(
    unread_only: bool = False,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    responsible_class_ids = get_responsible_class_ids(db, current_teacher.id)  
    if not responsible_class_ids:
        return []  
    query = db.query(Feedback).filter(
        Feedback.class_id.in_(responsible_class_ids)
    )
    
    if unread_only:
        query = query.filter(Feedback.is_read == False)    
    feedbacks = query.order_by(Feedback.created_at.desc()).all()  
    result = []
    for feedback in feedbacks:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == feedback.class_id).first()
        result.append(FeedbackTeacherResponse(
            id=feedback.id,
            class_name=school_class.name if school_class else "Unbekannt",
            category=feedback.category,
            message=feedback.message,
            is_anonymous=feedback.is_anonymous,
            student_name=feedback.student_name if not feedback.is_anonymous else None,
            created_at=to_german_time(feedback.created_at),
            is_read=feedback.is_read
        ))
    return result

class BulkDeleteRequest(BaseModel):
    feedback_ids: list[uuid.UUID]

@router.post("/inbox/bulk-delete", status_code=status.HTTP_200_OK)
def bulk_delete_feedbacks(
    data: BulkDeleteRequest,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    deleted_count = 0
    skipped_count = 0  
    for feedback_id in data.feedback_ids:
        feedback = db.query(Feedback).filter(Feedback.id == feedback_id).first()       
        if not feedback:
            skipped_count += 1
            continue        
        if teacher_is_responsible(db, current_teacher.id, feedback.class_id):
            db.delete(feedback)
            deleted_count += 1
        else:
            skipped_count += 1
    
    db.commit()   
    return {
        "message": f"{deleted_count} Nachrichten gelöscht",
        "deleted": deleted_count,
        "skipped": skipped_count
    }

@router.delete("/inbox/{feedback_id}", status_code=status.HTTP_200_OK)
def delete_feedback_teacher(
    feedback_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    feedback = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not feedback:
        raise HTTPException(status_code=404, detail="Nachricht nicht gefunden")  
    if not teacher_is_responsible(db, current_teacher.id, feedback.class_id):
        raise HTTPException(status_code=403, detail="Sie sind für diese Klasse nicht zuständig")
    
    db.delete(feedback)
    db.commit()
    return {"message": "Nachricht gelöscht"}

@router.put("/inbox/{feedback_id}/read", status_code=status.HTTP_200_OK)
def mark_feedback_as_read(
    feedback_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    feedback = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback nicht gefunden") 
    if not teacher_is_responsible(db, current_teacher.id, feedback.class_id):
        raise HTTPException(status_code=403, detail="Sie sind für diese Klasse nicht zuständig")  
    feedback.is_read = True
    db.commit()
    return {"message": "Feedback gelesen"}