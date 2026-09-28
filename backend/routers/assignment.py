from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher
from models import Teacher, TeacherAssignment, SchoolClass
import uuid

router = APIRouter(prefix="/assignments", tags=["Assignments"])

@router.get("/my-classes")
def get_my_classes(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    assignments = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == current_teacher.id
    ).all()
    result = []
    seen_class_ids = set()   
    for assignment in assignments:
        if assignment.class_id in seen_class_ids:
            continue
        seen_class_ids.add(assignment.class_id)        
        school_class = db.query(SchoolClass).filter(SchoolClass.id == assignment.class_id).first()
        if school_class:
            result.append({
                "id": str(school_class.id),
                "name": school_class.name,
                "level": school_class.level,
                "school_id": str(school_class.school_id)
            })   
    return result

@router.get("/my-subjects/{class_id}")
def get_my_subjects_for_class(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    assignments = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == current_teacher.id,
        TeacherAssignment.class_id == class_id
    ).all()    
    subjects = [a.subject for a in assignments]
    return {"subjects": subjects}

@router.get("/my-assignments")
def get_my_assignments(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    assignments = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == current_teacher.id
    ).all()   
    result = []
    for a in assignments:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == a.class_id).first()
        result.append({
            "id": str(a.id),
            "class_id": str(a.class_id),
            "class_name": school_class.name if school_class else "Unbekannt",
            "subject": a.subject
        })    
    return result

def teacher_teaches_subject(db: Session, teacher_id: uuid.UUID, class_id: uuid.UUID, subject: str) -> bool:
    assignment = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == teacher_id,
        TeacherAssignment.class_id == class_id,
        TeacherAssignment.subject.ilike(subject)
    ).first()
    return assignment is not None

def teacher_teaches_class(db: Session, teacher_id: uuid.UUID, class_id: uuid.UUID) -> bool:
    assignment = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == teacher_id,
        TeacherAssignment.class_id == class_id
    ).first()
    return assignment is not None