from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student, get_current_teacher, hash_student_id
from schemas import FeedbackCreate, FeedbackStudentResponse, FeedbackTeacherResponse
from models import Student, Teacher, Feedback, SchoolClass

router = APIRouter(prefix="/tickets", tags=["Tickets"])

@router.post("/", response_model=FeedbackStudentResponse)
def create_ticket(
    ticket: FeedbackCreate,
    db: Session = Depends(get_db),
    student: Student = Depends(get_current_student)
):
    feedback = Feedback(
        student_hash=hash_student_id(str(student.id)),
        is_anonymous=ticket.is_anonymous,
        student_name=None if ticket.is_anonymous else student.real_name,
        class_id=student.class_id,
        category=ticket.category,
        message=ticket.message,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)
    return FeedbackStudentResponse.model_validate(feedback)

@router.get("/", response_model=list[FeedbackTeacherResponse])
def get_tickets(
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher)
):
    feedbacks = (
        db.query(Feedback)
        .join(SchoolClass, Feedback.class_id == SchoolClass.id)
        .filter(SchoolClass.school_id == teacher.school_id)
        .order_by(Feedback.created_at.desc())
        .all()
    )
    return [
        FeedbackTeacherResponse(
            id=feedback.id,
            class_name=school_class.name if (school_class := db.query(SchoolClass).filter(SchoolClass.id == feedback.class_id).first()) else "Unbekannt",
            category=feedback.category,
            message=feedback.message,
            is_anonymous=feedback.is_anonymous,
            is_read=feedback.is_read,
            created_at=feedback.created_at,
        )
        for feedback in feedbacks
    ]