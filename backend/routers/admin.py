from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import verify_admin, get_password_hash
from models import School, SchoolClass, Teacher
from schemas import (
    SchoolCreate, SchoolResponse, SchoolUpdate,
    ClassCreate, ClassResponse, ClassUpdate
)
import uuid
import secrets
from pydantic import BaseModel

class BootstrapTeacherCreate(BaseModel):
    school_id: uuid.UUID
    email: str
    full_name: str
router = APIRouter(prefix="/admin", tags=["Admin Setup"])

@router.post("/teachers/bootstrap", status_code=status.HTTP_201_CREATED)
def admin_create_first_teacher(
    teacher_data: BootstrapTeacherCreate,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    if db.query(Teacher).filter(Teacher.email == teacher_data.email).first():
        raise HTTPException(status_code=400, detail="E-mail existiert bereits")
    plain_password = secrets.token_urlsafe(12)
    hashed = get_password_hash(plain_password)
    db_teacher = Teacher(
        school_id=teacher_data.school_id,
        email=teacher_data.email,
        full_name=teacher_data.full_name,
        password_hash=hashed,
        must_change_password=True
    )
    db.add(db_teacher)
    db.commit()
    return {
        "message": "Lehrer erstellt. Passwort bei erst-Login ändern",
        "email": teacher_data.email,
        "intial password": plain_password
    }

@router.post("/schools", response_model=SchoolResponse, status_code=status.HTTP_201_CREATED)
def admin_create_school(
    school: SchoolCreate,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    db_school = School(**school.model_dump())
    db.add(db_school)
    db.commit()
    db.refresh(db_school)
    return db_school

@router.get("/schools", response_model=list[SchoolResponse])
def admin_list_schools(
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    """Listet alle Schulen auf"""
    return db.query(School).all()

@router.put("/schools/{school_id}", response_model=SchoolResponse)
def admin_update_school(
    school_id: uuid.UUID,
    school_update: SchoolUpdate,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    db_school = db.query(School).filter(School.id == school_id).first()
    if not db_school:
        raise HTTPException(status_code=404, detail="Schule nicht gefunden")  
    update_data = school_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_school, key, value) 
    db.commit()
    db.refresh(db_school)
    return db_school

@router.delete("/schools/{school_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_school(
    school_id: uuid.UUID,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    db_school = db.query(School).filter(School.id == school_id).first()
    if not db_school:
        raise HTTPException(status_code=404, detail="Schule nicht gefunden")
    db.delete(db_school)
    db.commit()
    return None

@router.post("/schools/{school_id}/classes", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
def admin_create_class(
    school_id: uuid.UUID,
    class_data: ClassCreate,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise HTTPException(status_code=404, detail="Schule nicht gefunden")
    db_class = SchoolClass(school_id=school_id, **class_data.model_dump())
    db.add(db_class)
    db.commit()
    db.refresh(db_class)
    return db_class

@router.get("/schools/{school_id}/classes", response_model=list[ClassResponse])
def admin_list_classes(
    school_id: uuid.UUID,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    return db.query(SchoolClass).filter(SchoolClass.school_id == school_id).all()

@router.put("/classes/{class_id}", response_model=ClassResponse)
def admin_update_class(
    class_id: uuid.UUID,
    class_update: ClassUpdate,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    """Bearbeitet eine Klasse"""
    db_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not db_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")   
    update_data = class_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_class, key, value)
    db.commit()
    db.refresh(db_class)
    return db_class

@router.delete("/classes/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_class(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    db_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not db_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    db.delete(db_class)
    db.commit()
    return None

@router.get("/teachers", status_code=status.HTTP_200_OK)
def admin_list_teachers(
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    teachers = db.query(Teacher).all()
    return [
        {
            "id": str(t.id),
            "email": t.email,
            "full_name": t.full_name,
            "school_id": str(t.school_id)
        }
        for t in teachers
    ]

@router.delete("/teachers/{teacher_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_teacher(
    teacher_id: uuid.UUID,
    db: Session = Depends(get_db),
    _: bool = Depends(verify_admin)
):
    """Löscht einen Lehrer"""
    db_teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
    if not db_teacher:
        raise HTTPException(status_code=404, detail="Lehrer nicht gefunden")
    
    db.delete(db_teacher)
    db.commit()
    return None