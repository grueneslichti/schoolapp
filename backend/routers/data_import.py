from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from core.database import get_db
from models import School, SchoolClass, Teacher, Student
import uuid
import json
import csv
from io import StringIO

router = APIRouter(prefix="/import", tags=["Data Import"])
@router.post("/schools")
async def import_schools(
    file: UploadFile = File(...),
    import_mode: str = Form("merge"),
    db: Session = Depends(get_db)
):
    content = await file.read()
    content_str = content.decode('utf-8')
    if file.filename.endswith('.json'):
        data = json.loads(content_str)
        if isinstance(data, dict) and 'schools' in data:
            schools_data = data['schools']
        else:
            schools_data = data
    elif file.filename.endswith('.csv'):
        schools_data = _parse_csv(content_str)
    else:
        raise HTTPException(status_code=400, detail="Nur JSON oder CSV unterstützt")
    if import_mode == "replace":
        db.query(SchoolClass).delete()
        db.query(Teacher).delete()
        db.query(School).delete()
    imported = 0
    updated = 0
    skipped = 0
    errors = []
    uuid_map = {}
    for school_data in schools_data:
        try:
            result = _import_single_school(db, school_data, import_mode, uuid_map)
            if result == "imported":
                imported += 1
            elif result == "updated":
                updated += 1
            elif result == "skipped":
                skipped += 1
        except Exception as e:
            errors.append(f"Schule '{school_data.get('name', 'Unbekannt')}': {str(e)}") 
    db.commit()
    return {
        "message": f"{imported} importiert, {updated} aktualisiert, {skipped} übersprungen",
        "imported": imported,
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
        "uuid_map": uuid_map
    }

def _import_single_school(db: Session, data: dict, mode: str, uuid_map: dict) -> str:
    school_id = data.get('id')
    existing = None
    if school_id:
        existing = db.query(School).filter(School.id == school_id).first()
    if not existing:
        existing = db.query(School).filter(School.name == data.get('name')).first()
    if existing:
        if mode == "skip":
            uuid_map[school_id] = str(existing.id) if school_id else None
            return "skipped"
        existing.name = data.get('name', existing.name)
        existing.country_code = data.get('country_code', existing.country_code)
        existing.school_type = data.get('school_type', existing.school_type)
        if school_id:
            uuid_map[school_id] = str(existing.id)
        return "updated"
    new_id = uuid.UUID(school_id) if school_id else uuid.uuid4()
    new_school = School(
        id=new_id,
        name=data.get('name'),
        country_code=data.get('country_code', 'DE'),
        school_type=data.get('school_type', 'primary')
    )
    db.add(new_school)
    db.flush()    
    if school_id:
        uuid_map[school_id] = str(new_id)
    return "imported"

@router.post("/classes")
async def import_classes(
    file: UploadFile = File(...),
    import_mode: str = Form("merge"),
    school_uuid_map: str = Form("{}"),
    db: Session = Depends(get_db)
):
    content = await file.read()
    content_str = content.decode('utf-8') 
    if file.filename.endswith('.json'):
        data = json.loads(content_str)
        if isinstance(data, dict) and 'classes' in data:
            classes_data = data['classes']
        else:
            classes_data = data
    elif file.filename.endswith('.csv'):
        classes_data = _parse_csv(content_str)
    else:
        raise HTTPException(status_code=400, detail="Nur JSON oder CSV unterstützt")
    try:
        uuid_map = json.loads(school_uuid_map)
    except json.JSONDecodeError:
        uuid_map = {}
    imported = 0
    updated = 0
    skipped = 0
    errors = []
    for class_data in classes_data:
        try:
            result = _import_single_class(db, class_data, import_mode, uuid_map)
            if result == "imported":
                imported += 1
            elif result == "updated":
                updated += 1
            elif result == "skipped":
                skipped += 1
        except Exception as e:
            errors.append(f"Klasse '{class_data.get('name', 'Unbekannt')}': {str(e)}")
    db.commit()
    return {
        "message": f"{imported} importiert, {updated} aktualisiert, {skipped} übersprungen",
        "imported": imported,
        "updated": updated,
        "skipped": skipped,
        "errors": errors
    }

def _import_single_class(db: Session, data: dict, mode: str, uuid_map: dict) -> str:
    class_id = data.get('id')
    old_school_id = data.get('school_id')
    new_school_id_str = uuid_map.get(old_school_id, old_school_id)
    school = None
    if new_school_id_str:
        try:
            school = db.query(School).filter(School.id == new_school_id_str).first()
        except Exception:
            pass
    if not school and data.get('school_name'):
        school = db.query(School).filter(School.name == data.get('school_name')).first()
    if not school:
        raise ValueError(f"Schule nicht gefunden (school_id: {old_school_id})")
    existing = None
    if class_id:
        existing = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not existing:
        existing = db.query(SchoolClass).filter(
            SchoolClass.name == data.get('name'),
            SchoolClass.school_id == school.id
        ).first()
    if existing:
        if mode == "skip":
            return "skipped" 
        existing.name = data.get('name', existing.name)
        existing.level = data.get('level', existing.level)
        existing.school_id = school.id
        return "updated"
    new_id = uuid.UUID(class_id) if class_id else uuid.uuid4()
    new_class = SchoolClass(
        id=new_id,
        name=data.get('name'),
        level=data.get('level'),
        school_id=school.id
    )
    db.add(new_class)
    return "imported"

@router.get("/export-all")
def export_all(db: Session = Depends(get_db)):
    schools = db.query(School).all()
    classes = db.query(SchoolClass).all()
    return {
        "export_version": "1.0",
        "schools": [{
            "id": str(s.id),
            "name": s.name,
            "country_code": s.country_code,
            "school_type": s.school_type
        } for s in schools],
        "classes": [{
            "id": str(c.id),
            "name": c.name,
            "level": c.level,
            "school_id": str(c.school_id)
        } for c in classes]
    }

@router.post("/import-all")
async def import_all(
    file: UploadFile = File(...),
    import_mode: str = Form("merge"),
    db: Session = Depends(get_db)
):
    content = await file.read()
    data = json.loads(content.decode('utf-8'))
    uuid_map = {}
    imported_schools = 0
    imported_classes = 0
    errors = []
    for school_data in data.get('schools', []):
        try:
            result = _import_single_school(db, school_data, import_mode, uuid_map)
            if result in ("imported", "updated"):
                imported_schools += 1
        except Exception as e:
            errors.append(f"Schule: {str(e)}")
    db.flush()
    for class_data in data.get('classes', []):
        try:
            result = _import_single_class(db, class_data, import_mode, uuid_map)
            if result in ("imported", "updated"):
                imported_classes += 1
        except Exception as e:
            errors.append(f"Klasse: {str(e)}")
    db.commit()
    return {
        "message": f"{imported_schools} Schulen, {imported_classes} Klassen importiert",
        "imported_schools": imported_schools,
        "imported_classes": imported_classes,
        "errors": errors
    }

def _parse_csv(content: str) -> list[dict]:
    """Parst CSV-Content zu einer Liste von Dicts."""
    reader = csv.DictReader(StringIO(content))
    return [dict(row) for row in reader]