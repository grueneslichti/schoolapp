from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher
from models import SchoolClass, School, Teacher, TeacherAssignment
from schemas import ClassCreate, ClassResponse
import uuid
from routers.assignment import teacher_teaches_class

router = APIRouter(prefix="/schools/{school_id}/classes", tags=["Classes"])
api_router = APIRouter(prefix="/classes", tags=["Classes"])

@router.post("/", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
def create_class(
    school_id: uuid.UUID,
    class_data: ClassCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise HTTPException(status_code=404, detail="Schule nicht gefunden")
    db_class = SchoolClass(school_id=school_id, **class_data.model_dump())
    db.add(db_class)
    db.commit()
    db.refresh(db_class)
    return db_class

@router.get("/", response_model=list[ClassResponse])
def get_all_classes(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    assigned_class_ids = db.query(TeacherAssignment.class_id).filter(
        TeacherAssignment.teacher_id == current_teacher.id
    ).distinct().all()
    class_ids = [cid[0] for cid in assigned_class_ids] 
    if not class_ids:
        return[]
    classes = db.query(SchoolClass).filter(
        SchoolClass.id.in_(class_ids)
    ).order_by(SchoolClass.name).all()
    return classes

@api_router.post("/", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
def create_class_for_teacher_school(
    class_data: ClassCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    new_class = SchoolClass(
        name=class_data.name,
        level=class_data.level,
        school_id=current_teacher.school_id
    )
    db.add(new_class)
    db.commit()
    db.refresh(new_class)
    return new_class

@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_class(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")  
    db.delete(school_class)
    db.commit()
    return None

@api_router.get("/", response_model=list[ClassResponse])
def get_classes_for_current_teacher(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    classes = db.query(SchoolClass).filter(SchoolClass.school_id == current_teacher.school_id).order_by(SchoolClass.name).all()
    return [ClassResponse.model_validate(c) for c in classes]
