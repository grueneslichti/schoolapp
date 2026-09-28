from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_password_hash, get_current_teacher, generate_easy_password, get_current_student, generate_unique_login_name
from models import Teacher, Student, SchoolClass
from schemas import TeacherCreate, TeacherResponse, StudentCreate, StudentResponse, StudentUpdate
import uuid
import secrets

router = APIRouter(prefix="/users", tags=["User Management"])

@router.post("/teachers", response_model=TeacherResponse, status_code=status.HTTP_201_CREATED)
def create_teacher(
    teacher_data: TeacherCreate, 
    db: Session = Depends(get_db)
):
    if db.query(Teacher).filter(Teacher.email == teacher_data.email).first():
        raise HTTPException(status_code=400, detail="E-Mail-Adresse bereits registriert")
    plain_password = teacher_data.initial_password or secrets.token_urlsafe(8)
    hashed_password = get_password_hash(plain_password)
    db_teacher = Teacher(
        school_id=teacher_data.school_id,
        email=teacher_data.email,
        full_name=teacher_data.full_name,
        password_hash=hashed_password
    )
    db.add(db_teacher)
    db.commit()
    db.refresh(db_teacher)
    return TeacherResponse(
        id=db_teacher.id,
        email=db_teacher.email,
        full_name=db_teacher.full_name,
        school_id=db_teacher.school_id,
        initial_password=plain_password
    )

@router.post("/students", response_model=StudentResponse, status_code=status.HTTP_201_CREATED)
def create_student(
    student_data: StudentCreate, 
    db: Session = Depends(get_db)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == student_data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    student_count = db.query(Student).filter(Student.class_id == student_data.class_id).count()
    pseudonym = f"{school_class.name}_{str(student_count + 1).zfill(3)}"
    while db.query(Student).filter(Student.pseudonym == pseudonym).first():
        student_count += 1
        pseudonym = f"{school_class.name}_{str(student_count + 1).zfill(3)}"
    plain_password = student_data.initial_password or secrets.token_urlsafe(8)
    hashed_password = get_password_hash(plain_password)
    db_student = Student(
        class_id=student_data.class_id,
        real_name=student_data.real_name,
        login_name=generate_unique_login_name(db, student_data.real_name),
        pseudonym=pseudonym,
        password_hash=hashed_password
    )
    db.add(db_student)
    db.commit()
    db.refresh(db_student)
    return StudentResponse(
        id=db_student.id,
        pseudonym=db_student.pseudonym,
        class_id=db_student.class_id,
        initial_password=plain_password
    )

@router.get("/students", status_code=status.HTTP_200_OK)
def list_students(
    class_id: uuid.UUID | None = None,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    query = db.query(Student)
    if class_id:
        query = query.filter(Student.class_id == class_id)
    students = query.all()
    return [
        {
            "id": str(s.id),
            "real_name": s.real_name,
            "pseudonym": s.pseudonym,
            "class_id": str(s.class_id)
        }
        for s in students
    ]

@router.put("/students/{student_id}", response_model=StudentResponse)
def update_student(
    student_id: uuid.UUID,
    student_update: StudentUpdate,
    db: Session = Depends(get_db)
):
    db_student = db.query(Student).filter(Student.id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden") 
    update_data = student_update.model_dump(exclude_unset=True)
    if "class_id" in update_data:
        new_class = db.query(SchoolClass).filter(SchoolClass.id == update_data["class_id"]).first()
        if not new_class:
            raise HTTPException(status_code=404, detail="Neue Klasse nicht gefunden")  
        student_count = db.query(Student).filter(Student.class_id == update_data["class_id"]).count()
        new_pseudonym = f"{new_class.name}_{str(student_count + 1).zfill(3)}" 
        while db.query(Student).filter(Student.pseudonym == new_pseudonym).first():
            student_count += 1
            new_pseudonym = f"{new_class.name}_{str(student_count + 1).zfill(3)}"   
        db_student.pseudonym = new_pseudonym
        db_student.class_id = update_data["class_id"]  
    db.commit()
    db.refresh(db_student) 
    return StudentResponse(
        id=db_student.id,
        pseudonym=db_student.pseudonym,
        class_id=db_student.class_id,
        initial_password="[UNCHANGED]"
    )

@router.delete("/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student(
    student_id: uuid.UUID,
    db: Session = Depends(get_db)
):
    db_student = db.query(Student).filter(Student.id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden") 
    db.delete(db_student)
    db.commit()
    return None

@router.post("/students/{student_id}/reset-password", status_code=status.HTTP_200_OK)
def reset_student_password(
    student_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    db_student = db.query(Student).filter(Student.id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")
    new_password = generate_easy_password()
    db_student.password_hash = get_password_hash(new_password)
    db_student.start_password = new_password
    db_student.must_change_password = True
    db.commit()
    return {
        "message": "Passwort erfolgreich zurückgesetzt",
        "pseudonym": db_student.pseudonym,
        "new_password": new_password
    }

@router.get("/me")
def get_my_info(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == current_student.class_id).first()
    return {
        "id": str(current_student.id),
        "real_name": current_student.real_name,
        "pseudonym": current_student.pseudonym,
        "class_id": str(current_student.class_id),
        "class_name": school_class.name if school_class else "Unbekannt",
        "xp": current_student.xp or 0
    }