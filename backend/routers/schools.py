import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from models import School
from schemas import SchoolCreate, SchoolResponse, SchoolSetupResponse, SchoolSetupRequest

router = APIRouter(prefix="/schools", tags=["Schools"])

@router.post("/", response_model=SchoolResponse, status_code=status.HTTP_201_CREATED)
def create_school(school: SchoolCreate, db: Session = Depends(get_db)):
    db_school = School(**school.model_dump())
    db.add(db_school)
    db.commit()
    db.refresh(db_school)
    return db_school

@router.get("/", response_model=list[SchoolResponse])
def read_schools(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(School).offset(skip).limit(limit).all()

@router.post("/setup", response_model=SchoolSetupResponse)
def setup_school(
    data: SchoolSetupRequest,
    db: Session = Depends(get_db)
):
    normalized_code = data.setup_code.strip()
    school = db.query(School).filter(
        School.setup_code.ilike(normalized_code)
    ).first()

    if not school:
        raise HTTPException(status_code=404, detail="Ungültiger Setup-Code")
    return SchoolSetupResponse(
        school_id=school.id,
        school_name=school.name,
        has_background=school.login_background_path is not None
    )
@router.get("/{school_id}/login-background")
def get_login_background(
    school_id: uuid.UUID,
    db: Session = Depends(get_db)
):
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise HTTPException(status_code=404, detail="Schule nicht gefunden")
    if not school.login_background_path:
        return {"has_background": False, "image_url": None}
    return {
        "has_background": True,
        "image_url": f"/{school.login_background_path}"
    }