from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_current_student
from models import Teacher, Student, Grade, SchoolClass
from schemas import GradeCreate, GradeResponse, ClassGradesResponse
import uuid
from routers.assignment import teacher_teaches_subject

router = APIRouter(prefix="/grades", tags=["Grades"])

@router.get("/class/{class_id}", response_model=list[ClassGradesResponse])
def get_class_grades(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    students = db.query(Student).filter(Student.class_id == class_id).all()
    result = []
    for student in students:
        grades = db.query(Grade).filter(Grade.student_id == student.id).order_by(Grade.date.desc()).all()
        if grades:
            avg = sum(g.value for g in grades) / len(grades)
        else:
            avg = 0.0
        result.append(ClassGradesResponse(
            student_id=student.id,
            real_name=student.real_name,
            pseudonym=student.pseudonym,
            grades=[GradeResponse.model_validate(g) for g in grades],
            average=round(avg, 2)
        ))
    return result

@router.post("/", response_model=GradeResponse, status_code=status.HTTP_201_CREATED)
def create_grade(
    grade_data: GradeCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    student = db.query(Student).filter(Student.id == grade_data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")
    if not teacher_teaches_subject(db, current_teacher.id, student.class_id, grade_data.subject):
        raise HTTPException(
            status_code=403, 
            detail=f"Sie unterrichten '{grade_data.subject}' nicht in dieser Klasse. "
                   f"Bitte wähle Sie eines Ihrer Fächer."
        )
    new_grade = Grade(
        student_id=grade_data.student_id,
        teacher_id=current_teacher.id,
        class_id=student.class_id,
        subject=grade_data.subject,
        value=grade_data.value,
        description=grade_data.description
    )
    db.add(new_grade)
    db.commit()
    db.refresh(new_grade)
    return GradeResponse.model_validate(new_grade)

@router.delete("/{grade_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_grade(
    grade_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    grade = db.query(Grade).filter(Grade.id == grade_id).first()
    if not grade:
        raise HTTPException(status_code=404, detail="Note nicht gefunden")
    if grade.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Du kannst nur deine eigenen Noten löschen")
    db.delete(grade)
    db.commit()
    return None

@router.get("/my-grades", response_model=list[GradeResponse])
def get_my_grades(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    grades = db.query(Grade).filter(Grade.student_id == current_student.id).order_by(Grade.date.desc()).all()
    return [GradeResponse.model_validate(g) for g in grades]