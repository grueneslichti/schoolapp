from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_admin
from models import Student, Teacher, SchoolClass, PromotionHistory, School
from schemas import PromoteStudentRequest, BulkPromoteRequest, TransferStudentRequest
import uuid
from datetime import datetime, timezone, timedelta
import json

router = APIRouter(prefix="/promotion", tags=["Promotion"])

@router.post("/promote")
def promote_student(
    data: PromoteStudentRequest,
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")
    old_class_id = student.class_id
    new_class = db.query(SchoolClass).filter(SchoolClass.id == data.new_class_id).first()
    if not new_class:
        raise HTTPException(status_code=404, detail="Neue Klasse nicht gefunden")
    old_class = db.query(SchoolClass).filter(SchoolClass.id == old_class_id).first()
    history = PromotionHistory(
        student_id=student.id,
        from_class_id=old_class_id,
        to_class_id=data.new_class_id,
        promoted_by=current_admin.full_name
    )
    db.add(history)
    student.class_id = data.new_class_id
    db.commit()
    return {
        "message": f"{student.real_name} von Klasse {old_class.name if old_class else '?'} in Klasse {new_class.name} versetzt",
        "history_id": str(history.id),
        "student_name": student.real_name,
        "from_class": old_class.name if old_class else "Unbekannt",
        "to_class": new_class.name
    }

@router.post("/bulk-promote")
def bulk_promote(
    data: BulkPromoteRequest,
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    from_class = db.query(SchoolClass).filter(SchoolClass.id == data.from_class_id).first()
    to_class = db.query(SchoolClass).filter(SchoolClass.id == data.to_class_id).first()
    if not from_class or not to_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    students = db.query(Student).filter(Student.class_id == data.from_class_id).all()
    if data.only_older_than_days:
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=data.only_older_than_days)
        filtered_students = []
        for student in students:
            last_promotion = db.query(PromotionHistory).filter(
                PromotionHistory.student_id == student.id
            ).order_by(PromotionHistory.promoted_at.desc()).first()
            if not last_promotion or last_promotion.promoted_at < cutoff_date:
                filtered_students.append(student)
        students = filtered_students
    promoted_count = 0
    history_ids = []
    for student in students:
        history = PromotionHistory(
            student_id=student.id,
            from_class_id=data.from_class_id,
            to_class_id=data.to_class_id,
            promoted_by=current_admin.full_name
        )
        db.add(history)
        history_ids.append(str(history.id))
        student.class_id = data.to_class_id
        promoted_count += 1
    db.commit()  
    return {
        "message": f"{promoted_count} Schüler von Klasse {from_class.name} in Klasse {to_class.name} versetzt",
        "from_class": from_class.name,
        "to_class": to_class.name,
        "promoted_count": promoted_count,
        "history_ids": history_ids
    }

@router.post("/undo/{history_id}")
def undo_promotion(
    history_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    history = db.query(PromotionHistory).filter(PromotionHistory.id == history_id).first()
    if not history:
        raise HTTPException(status_code=404, detail="History-Eintrag nicht gefunden")
    
    student = db.query(Student).filter(Student.id == history.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")

    if student.class_id != history.to_class_id:
        raise HTTPException(
            status_code=400,
            detail=f"Schüler ist nicht mehr in der Zielklasse (aktuell: {student.class_id})"
        )
    student.class_id = history.from_class_id
    db.delete(history)
    db.commit()
    
    from_class = db.query(SchoolClass).filter(SchoolClass.id == history.from_class_id).first()
    
    return {
        "message": f"Versetzung von {student.real_name} rückgängig gemacht",
        "student_name": student.real_name,
        "restored_to_class": from_class.name if from_class else "Unbekannt"
    }

@router.post("/bulk-undo")
def bulk_undo(
    history_ids: list[uuid.UUID],
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    undone_count = 0
    failed_count = 0
    
    for history_id in history_ids:
        history = db.query(PromotionHistory).filter(PromotionHistory.id == history_id).first()
        if not history:
            failed_count += 1
            continue
        student = db.query(Student).filter(Student.id == history.student_id).first()
        if not student or student.class_id != history.to_class_id:
            failed_count += 1
            continue   
        student.class_id = history.from_class_id
        db.delete(history)
        undone_count += 1 
    db.commit() 
    return {
        "message": f"{undone_count} Versetzungen rückgängig gemacht",
        "undone_count": undone_count,
        "failed_count": failed_count
    }

@router.get("/history/{class_id}")
def get_class_promotion_history(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    history = db.query(PromotionHistory).filter(
        PromotionHistory.to_class_id == class_id
    ).order_by(PromotionHistory.promoted_at.desc()).all()
    result = []
    for h in history:
        student = db.query(Student).filter(Student.id == h.student_id).first()
        from_class = db.query(SchoolClass).filter(SchoolClass.id == h.from_class_id).first()
        result.append({
            "history_id": str(h.id),
            "student_name": student.real_name if student else "Unbekannt",
            "from_class": from_class.name if from_class else "Unbekannt",
            "promoted_at": h.promoted_at.isoformat(),
            "promoted_by": h.promoted_by
        })
    return result

@router.post("/transfer-school")
def transfer_to_different_school(
    data: TransferStudentRequest,
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")
    old_class = db.query(SchoolClass).filter(SchoolClass.id == student.class_id).first()
    if not old_class:
        raise HTTPException(status_code=404, detail="Alte Klasse nicht gefunden")
    new_class = db.query(SchoolClass).filter(SchoolClass.id == data.new_class_id).first()
    if not new_class:
        raise HTTPException(status_code=404, detail="Neue Klasse nicht gefunden")
    if old_class.school_id == new_class.school_id:
        raise HTTPException(
            status_code=400,
            detail="Für Wechsel innerhalb der gleichen Schule nutzen Sie bitte die normale Versetzung."
        )
    old_school = db.query(School).filter(School.id == old_class.school_id).first()
    new_school = db.query(School).filter(School.id == new_class.school_id).first()
    history = PromotionHistory(
        student_id=student.id,
        from_class_id=student.class_id,
        to_class_id=data.new_class_id,
        from_school_id=old_class.school_id,
        to_school_id=new_class.school_id,
        transfer_type=data.transfer_type,
        promoted_by=current_admin.full_name
    )
    db.add(history)
    classmates = db.query(Student).filter(Student.class_id == old_class.id).all()
    classmate_ids = [str(c.id) for c in classmates]
    student.class_id = data.new_class_id
    student.pending_graduation_photo = True
    student.graduation_classmate_ids = json.dumps(classmate_ids)
    student.graduation_class_name = old_class.name
    student.class_id = data.new_class_id
    db.commit()
    return {
        "message": f"{student.real_name} wurde von {old_school.name} nach {new_school.name} versetzt",
        "student_name": student.real_name,
        "from_school": old_school.name,
        "to_school": new_school.name,
        "from_class": old_class.name,
        "to_class": new_class.name,
        "transfer_type": data.transfer_type,
        "xp_kept": student.xp,
        "items_kept": True,
        "bonus_xp": 10 if data.transfer_type == "school_transfer" else 0
    }

@router.get("/all-students-with-school")
def get_all_students_with_school(
    db: Session = Depends(get_db),
    current_admin: Teacher = Depends(get_current_admin)
):
    students = db.query(Student).all()
    result = []
    for s in students:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == s.class_id).first()
        school = db.query(School).filter(School.id == school_class.school_id).first() if school_class else None
        result.append({
            "id": str(s.id),
            "name": s.real_name,
            "pseudonym": s.pseudonym,
            "class_name": school_class.name if school_class else "Unbekannt",
            "school_name": school.name if school else "Unbekannt",
            "school_id": str(school.id) if school else None,
            "class_id": str(s.id) if school_class else None,
            "xp": s.xp or 0
        })
    return result