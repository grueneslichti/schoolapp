from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_password_hash, generate_unique_login_name
from models import Teacher, Student, SchoolClass, InvitationCode
from schemas import (
    InvitationCodeCreate, InvitationCodeResponse,
    StudentRegistrationRequest, StudentRegistrationResponse
)
import uuid
import secrets
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/registration", tags=["Registration"])

def make_aware(dt):

    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt

def is_code_expired(expires_at) -> bool:
    if expires_at is None:
        return False
    aware_expires = make_aware(expires_at)
    now = datetime.now(timezone.utc)
    return aware_expires < now

@router.post("/create-code", response_model=InvitationCodeResponse, status_code=status.HTTP_201_CREATED)
def create_invitation_code(
    data: InvitationCodeCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    normalized_code = data.code.strip().upper()
    existing = db.query(InvitationCode).filter(InvitationCode.code == normalized_code).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Der Code '{normalized_code}' existiert bereits.")
    expires_at = None
    if data.expires_in_days:
        expires_at = datetime.now(timezone.utc) + timedelta(days=data.expires_in_days)
    new_code = InvitationCode(
        code=normalized_code,
        class_id=data.class_id,
        created_by_teacher_id=current_teacher.id,
        max_uses=data.max_uses,
        expires_at=expires_at
    )
    db.add(new_code)
    db.commit()
    db.refresh(new_code)
    return InvitationCodeResponse(
        id=new_code.id,
        code=new_code.code,
        class_name=school_class.name,
        is_active=new_code.is_active,
        times_used=new_code.times_used,
        max_uses=new_code.max_uses,
        expires_at=new_code.expires_at,
        created_at=new_code.created_at
    )

@router.get("/validate-code/{code}")
def validate_code(code: str, db: Session = Depends(get_db)):
    code = code.strip().upper() 
    invitation = db.query(InvitationCode).filter(
        InvitationCode.code == code,
        InvitationCode.is_active == True
    ).first()
    
    if not invitation:
        raise HTTPException(status_code=404, detail="Code ungültig oder nicht aktiv")
    if is_code_expired(invitation.expires_at):
        raise HTTPException(status_code=410, detail="Dieser Code ist abgelaufen")
    if invitation.max_uses and invitation.times_used >= invitation.max_uses:
        raise HTTPException(status_code=410, detail="Dieser Code wurde bereits maximal oft genutzt")
    school_class = db.query(SchoolClass).filter(SchoolClass.id == invitation.class_id).first()
    
    return {
        "valid": True,
        "class_name": school_class.name if school_class else "Unbekannt",
        "class_level": school_class.level if school_class else None
    }

@router.post("/register-student", response_model=StudentRegistrationResponse)
def register_student(
    data: StudentRegistrationRequest,
    db: Session = Depends(get_db)
):
    normalized_code = data.invitation_code.strip().upper()
    invitation = db.query(InvitationCode).filter(
        InvitationCode.code == normalized_code,
        InvitationCode.is_active == True
    ).first()
    
    if not invitation:
        raise HTTPException(status_code=400, detail="Ungültiger Einladungscode")
    if is_code_expired(invitation.expires_at):
        raise HTTPException(status_code=410, detail="Dieser Code ist abgelaufen.")  
    if invitation.max_uses and invitation.times_used >= invitation.max_uses:
        raise HTTPException(status_code=410, detail="Dieser Code kann nicht mehr verwendet werden.")  
    school_class = db.query(SchoolClass).filter(SchoolClass.id == invitation.class_id).first()
    if not school_class:
        raise HTTPException(status_code=500, detail="Klasse nicht gefunden")
    existing_student = db.query(Student).filter(
        Student.class_id == invitation.class_id,
        Student.real_name.ilike(data.real_name.strip())
    ).first()
    if existing_student:
        raise HTTPException(
            status_code=400, 
            detail=f"In der Klasse {school_class.name} gibt es bereits einen Schüler mit dem Namen '{data.real_name}'."
        )
    student_count = db.query(Student).filter(Student.class_id == invitation.class_id).count()
    new_pseudonym = f"{school_class.name}_{str(student_count + 1).zfill(3)}"
    while db.query(Student).filter(Student.pseudonym == new_pseudonym).first():
        student_count += 1
        new_pseudonym = f"{school_class.name}_{str(student_count + 1).zfill(3)}"
    start_password = _generate_easy_password()
    password_hash = get_password_hash(start_password)
    new_student = Student(
        real_name=data.real_name.strip(),
        login_name=generate_unique_login_name(db, data.real_name),
        pseudonym=new_pseudonym,
        class_id=invitation.class_id,
        password_hash=password_hash,
        start_password=start_password,
        must_change_password=True
    )
    db.add(new_student)
    invitation.times_used += 1
    db.commit()
    db.refresh(new_student) 
    return StudentRegistrationResponse(
        student_id=new_student.id,
        pseudonym=new_student.pseudonym,
        real_name=new_student.real_name,
        class_name=school_class.name,
        start_password=start_password,
        message=f"Willkommen in Klasse {school_class.name}!"
    )

def _generate_easy_password(length=6):
    alphabet = "abcdefghijklmnpqrstuvwxyz23456789"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

@router.get("/my-codes", response_model=list[InvitationCodeResponse])
def get_my_codes(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    codes = db.query(InvitationCode).filter(
        InvitationCode.created_by_teacher_id == current_teacher.id
    ).order_by(InvitationCode.created_at.desc()).all()
    result = []
    for code in codes:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == code.class_id).first()
        result.append(InvitationCodeResponse(
            id=code.id,
            code=code.code,
            class_name=school_class.name if school_class else "Unbekannt",
            is_active=code.is_active,
            times_used=code.times_used,
            max_uses=code.max_uses,
            expires_at=code.expires_at,
            created_at=code.created_at
        ))
    return result

@router.delete("/codes/{code_id}")
def deactivate_code(
    code_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    code = db.query(InvitationCode).filter(
        InvitationCode.id == code_id,
        InvitationCode.created_by_teacher_id == current_teacher.id
    ).first()
    if not code:
        raise HTTPException(status_code=404, detail="Code nicht gefunden")
    code.is_active = False
    db.commit() 
    return {"message": "Code wurde deaktiviert"}