from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from core.graduation_photo import generate_class_photo
from models import Student, Avatar, SchoolClass, School
import json
import uuid
from datetime import datetime

router = APIRouter(prefix="/graduation-photo", tags=["Graduation Photo"])

@router.get("/status")
def get_graduation_photo_status(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    return {
        "pending": current_student.pending_graduation_photo,
        "has_photo": bool(current_student.graduation_photo_path),
        "class_name": current_student.graduation_class_name,
        "photo_path": current_student.graduation_photo_path
    }

@router.post("/generate")
def generate_graduation_photo(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if not current_student.pending_graduation_photo:
        raise HTTPException(status_code=400, detail="Kein Foto ausstehend")
    
    if not current_student.graduation_classmate_ids:
        raise HTTPException(status_code=400, detail="Keine Klassenkameraden gespeichert")
    classmate_ids = json.loads(current_student.graduation_classmate_ids)
    school_name = "Deine Schule"
    students_data = []
    for cid in classmate_ids:
        try:
            classmate = db.query(Student).filter(Student.id == uuid.UUID(cid)).first()
        except Exception:
            classmate = None
        if classmate:
            avatar = db.query(Avatar).filter(Avatar.student_id == classmate.id).first()
            students_data.append({
                "name": classmate.pseudonym or classmate.real_name or "Schüler",
                "avatar_path": avatar.original_path if avatar else None,
                "anime_path": avatar.anime_path if avatar else None
            })
    if not students_data:
        raise HTTPException(status_code=400, detail="Keine gültigen Klassenkameraden gefunden")
    year = datetime.now().year
    class_name = current_student.graduation_class_name or "?"
    photo_path = generate_class_photo(
        students_data=students_data,
        class_name=class_name,
        school_name=school_name,
        year=year
    )
    if not photo_path:
        raise HTTPException(status_code=500, detail="Foto konnte nicht generiert werden")
    current_student.graduation_photo_path = photo_path
    current_student.pending_graduation_photo = False
    db.commit()
    return {
        "message": "Klassenabschluss-Foto erstellt!",
        "photo_path": photo_path
    }
@router.post("/decline")
def decline_graduation_photo(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    current_student.pending_graduation_photo = False
    current_student.graduation_classmate_ids = None
    current_student.graduation_class_name = None
    db.commit()
    return {"message": "Okay, kein Foto. Die Daten wurden gelöscht."}

@router.get("/image")
def get_graduation_photo(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if not current_student.graduation_photo_path:
        raise HTTPException(status_code=404, detail="Kein Foto vorhanden")
    from pathlib import Path
    full_path = Path(__file__).parent.parent / current_student.graduation_photo_path
    if not full_path.exists():
        raise HTTPException(status_code=404, detail="Foto-Datei nicht gefunden")  
    return FileResponse(full_path, media_type="image/jpeg")