from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher
from models import Teacher, Student, SchoolClass, TeacherAssignment
from pydantic import BaseModel, Field
import random
import uuid

router = APIRouter(prefix="/randomizer", tags=["Randomizer"])

class RandomizeRequest(BaseModel):
    class_id: uuid.UUID
    num_groups: int = Field(..., ge=1, description="Anzahl der Gruppen")

@router.get("/my-classes")
def get_my_classes(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    assignments = db.query(TeacherAssignment.class_id).filter(
        TeacherAssignment.teacher_id == current_teacher.id
    ).distinct().all()
    class_ids = [a[0] for a in assignments]
    if not class_ids:
        return []  
    classes = db.query(SchoolClass).filter(SchoolClass.id.in_(class_ids)).all()
    result = []
    for c in classes:
        student_count = db.query(Student).filter(Student.class_id == c.id).count()
        result.append({
            "id": str(c.id),
            "name": c.name,
            "student_count": student_count
        })
    result.sort(key=lambda x: x["name"])
    return result

@router.post("/generate")
def generate_groups(
    data: RandomizeRequest,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    teaches = db.query(TeacherAssignment).filter(
        TeacherAssignment.teacher_id == current_teacher.id,
        TeacherAssignment.class_id == data.class_id
    ).first()  
    if not teaches:
        raise HTTPException(
            status_code=403,
            detail="Du unterrichtest diese Klasse nicht"
        )
    school_class = db.query(SchoolClass).filter(SchoolClass.id == data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    students = db.query(Student).filter(
        Student.class_id == data.class_id
    ).all()
    
    if not students:
        raise HTTPException(status_code=400, detail="Diese Klasse hat keine Schüler")
    if data.num_groups > len(students):
        raise HTTPException(
            status_code=400,
            detail=f"Diese Klasse hat nur {len(students)} Schüler. "
                   f"Maximal {len(students)} Gruppen möglich."
        )
    student_names = [s.real_name or s.pseudonym or "Schüler" for s in students]
    random.shuffle(student_names)
    n = len(student_names)
    base_size = n // data.num_groups
    remainder = n % data.num_groups
    group_sizes = [base_size] * data.num_groups
    if remainder > 0:
        extra_groups = random.sample(range(data.num_groups), remainder)
        for idx in extra_groups:
            group_sizes[idx] += 1
    groups = []
    current_idx = 0
    for i, size in enumerate(group_sizes):
        group_students = student_names[current_idx:current_idx + size]
        current_idx += size
        groups.append({
            "group_number": i + 1,
            "students": group_students,
            "size": len(group_students)
        })
    return {
        "class_name": school_class.name,
        "num_students": n,
        "num_groups": data.num_groups,
        "groups": groups
    }