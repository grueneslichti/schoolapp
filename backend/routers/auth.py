from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import or_
from core.database import get_db
from core.security.security import verify_password, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES, get_current_user, get_password_hash, generate_easy_password, generate_unique_login_name
from models import Teacher, Student, School, SchoolClass
from datetime import timedelta
from pydantic import BaseModel
from schemas import TokenResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])

class PasswordChangeRequest(BaseModel):
    old_password: str
    new_password: str

class StudentLoginRequest(BaseModel):
    identifier: str
    password: str

@router.post("/change-password")
def change_password(
    req: PasswordChangeRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    user = current_user["user"]
    if not verify_password(req.old_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Das alte Passwort ist nicht korrekt")
    if len(req.new_password) <6:
        raise HTTPException(status_code=400, detail="Das neue Passwort muss mindestens 6 Zeichen besitzen")
    user.password_hash = get_password_hash(req.new_password)
    user.must_change_password = False
    user.start_password = None
    db.commit()
    return {"message": "Passwort erfolgreich geändert"}

@router.post("/login/teacher", response_model=TokenResponse)
def login_teacher(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    teacher = db.query(Teacher).filter(Teacher.email == form_data.username).first()
    if not teacher or not verify_password(form_data.password, teacher.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Falsche E-Mail oder falsches Passwort")
    school = db.query(School).filter(School.id == teacher.school_id).first()
    token = create_access_token(
        data={"sub": str(teacher.id), "role": "teacher"},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return TokenResponse(
        access_token=token,
        role="teacher",
        school_id=school.id,
        school_name=school.name,
        school_type=school.school_type or "primary",
        must_change_password=teacher.must_change_password,
        full_name=teacher.full_name
    )

@router.post("/login/student", response_model=TokenResponse)
def login_student(
    data: StudentLoginRequest,
    db: Session = Depends(get_db)
):
    identifier = data.identifier.strip()
    candidates = db.query(Student).filter(
        or_(
            Student.login_name == identifier,
            Student.real_name.ilike(identifier),
            Student.pseudonym == identifier
        )
    ).all()
    if not candidates:
        raise HTTPException(status_code=401, detail="Schüler nicht gefunden")
    matches = [s for s in candidates if verify_password(data.password, s.password_hash)]
    if not matches:
        raise HTTPException(status_code=401, detail="Falsches Passwort")

    if len(matches) > 1:
        for student in sorted(matches, key=lambda item: str(item.id)):
            if not student.login_name:
                student.login_name = generate_unique_login_name(db, student.real_name)
        db.flush()
        db.commit()
        raise HTTPException(
            status_code=409,
            detail={
                "message": "Mehrere Schüler mit diesen Zugangsdaten",
                "options": [s.login_name for s in matches],
            },
        )
    student = matches[0]
    if not student.login_name:
        student.login_name = generate_unique_login_name(db, student.real_name)
        db.flush()
        db.commit()
    school_class = db.query(SchoolClass).filter(SchoolClass.id == student.class_id).first()
    if not school_class:
        raise HTTPException(status_code=500, detail="Klasse des Schülers nicht gefunden")
    school = db.query(School).filter(School.id == school_class.school_id).first()  
    token = create_access_token(
        data={"sub": str(student.id), "role": "student"},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return TokenResponse(
        access_token=token,
        role="student",
        school_id=school.id,
        school_name=school.name,
        school_type=school.school_type or "primary",
        must_change_password=student.must_change_password,
        pseudonym=student.pseudonym,
        real_name=student.real_name
        )

class ResetRequest(BaseModel):
    username: str

@router.post("/request-password-reset")
def request_passwort_reset(
    req: ResetRequest,
    db: Session = Depends(get_db)
):
    teacher = db.query(Teacher).filter(Teacher.email.ilike(req.username)).first()
    student = db.query(Student).filter(
        (Student.real_name.ilike(req.username)) | (Student.pseudonym == req.username)
    ).first()
    user = teacher or student
    if not user:
        return {"message": "Benutzername unbekannt, bitte frag nach ob dein Benutzername im System ist."}
    new_pwd = generate_easy_password()
    user.password_hash = get_password_hash(new_pwd)
    user.start_password = new_pwd
    user.must_change_password = True
    db.commit()
    db.refresh (user)
    print(f"Neues Startpasswort in der Datenbank: {user.start_password}")
    print(f" must_change_password ist: {user.must_change_password}")
    print(f"Passwort: {new_pwd}")
    return {"message": "Passwort erstellt, frage den Lehrer oder Administrator nach dem neuen Passwort"}