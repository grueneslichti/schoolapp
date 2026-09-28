from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_current_student
from models import Teacher, Exam, SchoolClass, Student
from schemas import ExamCreate, ExamResponse, ConflictCheckResponse
import uuid
from datetime import date
from routers.assignment import teacher_teaches_subject

router = APIRouter(prefix="/exams", tags=["Exams"])

def exam_title(exam) -> str:
    return getattr(exam, "title", None) or exam.subject or "Prüfung"

def check_conflicts(
    db: Session,
    class_id: uuid.UUID,
    exam_date: date,
    exclude_exam_id: uuid.UUID | None = None
) -> list[Exam]:
    query = db.query(Exam).filter(
        Exam.class_id == class_id,
        Exam.exam_date == exam_date
    )
    if exclude_exam_id:
        query = query.filter(Exam.id != exclude_exam_id)
    return query.all()

@router.post("/conflict-check", response_model=ConflictCheckResponse)
def conflict_check(
    exam_data: ExamCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    conflicts = check_conflicts(db, exam_data.class_id, exam_data.exam_date)   
    if not conflicts:
        return ConflictCheckResponse(has_conflict=False, message="Kein Konflikt gefunden.")
    conflict_list = []
    for exam in conflicts:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == exam.class_id).first()
        conflict_list.append(ExamResponse(
            id=exam.id,
            class_id=exam.class_id,
            class_name=school_class.name if school_class else "Unbekannt",
            teacher_id=exam.teacher_id,
            title=exam_title(exam),
            subject=exam.subject,
            exam_date=exam.exam_date,
            created_at=exam.created_at,
            description=exam.description
        ))
    subjects = ", ".join([f"{e.subject}" for e in conflicts])
    message = f"In dieser Klasse gibt es am selben Tag bereits {len(conflicts)} Prüfung(en): {subjects}" 
    return ConflictCheckResponse(
        has_conflict=True,
        conflicting_exams=conflict_list,
        message=message
    )

@router.post("/", response_model=ExamResponse, status_code=status.HTTP_201_CREATED)
def create_exam(
    exam_data: ExamCreate,
    force: bool = False,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):  
    school_class = db.query(SchoolClass).filter(SchoolClass.id == exam_data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden") 
    if not teacher_teaches_subject(db, current_teacher.id, exam_data.class_id, exam_data.subject):
        raise HTTPException(
            status_code=403,
            detail=f"Sie unterrichten '{exam_data.subject}' nicht in dieser Klasse {school_class.name}. "
                   f"Bitte wähle Sie eines Ihrer Fächer."
        )
    if not force:
        conflicts = check_conflicts(db, exam_data.class_id, exam_data.exam_date)
        if conflicts:
            pass  
    new_exam = Exam(
        class_id=exam_data.class_id,
        teacher_id=current_teacher.id,
        subject=exam_data.subject,
        exam_date=exam_data.exam_date,
        description=exam_data.description
    )
    db.add(new_exam)
    db.commit()
    db.refresh(new_exam) 
    return ExamResponse(
        id=new_exam.id,
        class_id=new_exam.class_id,
        class_name=school_class.name,
        teacher_id=new_exam.teacher_id,
        title=exam_title(new_exam),
        subject=new_exam.subject,
        exam_date=new_exam.exam_date,
        created_at=new_exam.created_at,
        description=new_exam.description
    )

@router.get("/", response_model=list[ExamResponse])
def get_all_exams(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    exams = db.query(Exam).order_by(Exam.exam_date.asc()).all()
    result = []
    for exam in exams:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == exam.class_id).first()
        result.append(ExamResponse(
            id=exam.id,
            class_id=exam.class_id,
            class_name=school_class.name if school_class else "Unbekannt",
            teacher_id=exam.teacher_id,
            title=exam_title(exam),
            subject=exam.subject,
            exam_date=exam.exam_date,
            created_at=exam.created_at,
            description=exam.description
        ))
    return result

@router.get("/class/{class_id}", response_model=list[ExamResponse])
def get_class_exams(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")  
    exams = db.query(Exam).filter(
        Exam.class_id == class_id
    ).order_by(Exam.exam_date.asc()).all() 
    return [ExamResponse(
        id=exam.id,
        class_id=exam.class_id,
        class_name=school_class.name,
        teacher_id=exam.teacher_id,
        title=exam_title(exam),
        subject=exam.subject,
        exam_date=exam.exam_date,
        created_at=exam.created_at,
        description=exam.description
    ) for exam in exams]

@router.delete("/{exam_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_exam(
    exam_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Prüfung nicht gefunden")
    
    db.delete(exam)
    db.commit()
    return None

@router.get("/my-upcoming", response_model=list[ExamResponse])
def get_my_upcoming_exams(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    from datetime import date

    today = date.today()
    exams = db.query(Exam).filter(
        Exam.class_id == current_student.class_id,
        Exam.exam_date >= today
    ).order_by(Exam.exam_date.asc()).all()
    school_class = db.query(SchoolClass).filter(
        SchoolClass.id == current_student.class_id
    ).first()
    return [ExamResponse(
        id=exam.id,
        class_id=exam.class_id,
        class_name=school_class.name if school_class else "Unbekannt",
        teacher_id=exam.teacher_id,
        subject=exam.subject,
        title=exam_title(exam),
        exam_date=exam.exam_date,
        created_at=exam.created_at,
        description=exam.description
    ) for exam in exams]

@router.get("/has-upcoming")
def has_upcoming_exams(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    from datetime import date
    today = date.today()
    count = db.query(Exam).filter(
        Exam.class_id == current_student.class_id,
        Exam.exam_date >= today
    ).count()

    return {"has_exams": count > 0, "count": count}