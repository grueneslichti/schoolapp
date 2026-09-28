from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from models import Teacher, SchoolClass, TeacherAssignment
from pydantic import BaseModel
import uuid

router = APIRouter(prefix="/admin/assignments", tags=["Admin Assignments"])

class BulkAssignmentRequest(BaseModel):
    teacher_id: uuid.UUID
    subject: str
    class_ids: list[uuid.UUID]

@router.post("/bulk")
def bulk_assign_subject(
    data: BulkAssignmentRequest,
    db: Session = Depends(get_db)
):
    teacher = db.query(Teacher).filter(Teacher.id == data.teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Lehrer nicht gefunden")
    db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == data.teacher_id,
        TeacherAssignment.subject == data.subject
    ).delete()
    created = []
    for class_id in data.class_ids:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
        if school_class:
            new_assignment = TeacherAssignment(
                teacher_id=data.teacher_id,
                class_id=class_id,
                subject=data.subject
            )
            db.add(new_assignment)
            created.append(school_class.name)
    
    db.commit() 
    return {
        "message": f"{len(created)} Zuweisungen erstellt",
        "classes": created
    }

@router.get("/teacher/{teacher_id}")
def get_teacher_assignments(
    teacher_id: uuid.UUID,
    db: Session = Depends(get_db)
):
    assignments = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == teacher_id
    ).all()
    by_subject = {}
    for a in assignments:
        if a.subject not in by_subject:
            by_subject[a.subject] = []
        
        school_class = db.query(SchoolClass).filter(SchoolClass.id == a.class_id).first()
        if school_class:
            by_subject[a.subject].append({
                "class_id": str(school_class.id),
                "class_name": school_class.name
            })
    return {"assignments": by_subject}

@router.delete("/teacher/{teacher_id}/subject/{subject}")
def delete_subject_assignments(
    teacher_id: uuid.UUID,
    subject: str,
    db: Session = Depends(get_db)
):
    deleted = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == teacher_id,
        TeacherAssignment.subject == subject
    ).delete()
    db.commit()
    return {"message": f"{deleted} Zuweisungen gelöscht"}