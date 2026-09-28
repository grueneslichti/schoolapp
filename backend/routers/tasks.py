from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_current_student
from routers.assignment import teacher_teaches_subject
from models import Teacher, Student, SchoolClass, Task, TaskCompletion
from schemas import TaskCreate, TaskResponse
import uuid
from datetime import datetime, timezone

router = APIRouter(prefix="/tasks", tags=["Tasks"])

def make_aware(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt

@router.get("/class/{class_id}", response_model=list[TaskResponse])
def get_class_tasks(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    tasks = db.query(Task).filter(
        Task.class_id == class_id
    ).order_by(Task.due_date.asc()).all()
    now = datetime.now(timezone.utc)
    return [TaskResponse(
        id=task.id,
        class_id=task.class_id,
        class_name=school_class.name,
        subject=task.subject,
        title=task.title,
        description=task.description,
        due_date=task.due_date,
        created_at=task.created_at,
        is_overdue=make_aware(task.due_date) < now if task.due_date else False
    ) for task in tasks]

@router.get("/my-tasks", response_model=list[TaskResponse])
def get_my_tasks(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == current_student.class_id).first()
    tasks = db.query(Task).filter(
        Task.class_id == current_student.class_id
    ).order_by(Task.due_date.asc()).all()
    now = datetime.now(timezone.utc)
    result = []
    for task in tasks:
        completion = db.query(TaskCompletion).filter(
            TaskCompletion.task_id == task.id,
            TaskCompletion.student_id == current_student.id
        ).first() 
        result.append(TaskResponse(
            id=task.id,
            class_id=task.class_id,
            class_name=school_class.name if school_class else "Unbekannt",
            subject=task.subject,
            title=task.title,
            description=task.description,
            due_date=task.due_date,
            created_at=task.created_at,
            is_overdue=make_aware(task.due_date) < now if task.due_date else False,
            is_completed=completion is not None
        ))
    return result

@router.post("/", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(
    task_data: TaskCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == task_data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    if not teacher_teaches_subject(db, current_teacher.id, task_data.class_id, task_data.subject):
        raise HTTPException(
            status_code=403,
            detail=f"Du unterrichtest '{task_data.subject}' nicht in Klasse {school_class.name}."
        )
    try:
        due_date = datetime.fromisoformat(task_data.due_date)
        due_date = due_date.replace(hour=23, minute=59, second=59)
        if due_date.tzinfo is None:
            due_date = due_date.replace(tzinfo=timezone.utc)
    except ValueError:
        raise HTTPException(status_code=400, detail="Ungültiges Datumsformat")
    new_task = Task(
        class_id=task_data.class_id,
        subject=task_data.subject,
        title=task_data.title,
        description=task_data.description,
        due_date=due_date
    )
    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    return TaskResponse(
        id=new_task.id,
        class_id=new_task.class_id,
        class_name=school_class.name,
        subject=new_task.subject,
        title=new_task.title,
        description=new_task.description,
        due_date=new_task.due_date,
        created_at=new_task.created_at,
        is_overdue=False
    )

@router.post("/{task_id}/complete")
def complete_task(
    task_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Aufgabe nicht gefunden")
    if task.class_id != current_student.class_id:
        raise HTTPException(status_code=403, detail="Du bist nicht in dieser Klasse")
    existing = db.query(TaskCompletion).filter(
        TaskCompletion.task_id == task_id,
        TaskCompletion.student_id == current_student.id
    ).first()
    if existing:
        return {"message": "Aufgabe bereits abgeschlossen", "is_completed": True}
    completion = TaskCompletion(
        task_id=task_id,
        student_id=current_student.id
    )
    db.add(completion)
    db.commit()
    return {"message": "Aufgabe als erledigt markiert!", "is_completed": True}

@router.post("/{task_id}/uncomplete")
def uncomplete_task(
    task_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    completion = db.query(TaskCompletion).filter(
        TaskCompletion.task_id == task_id,
        TaskCompletion.student_id == current_student.id
    ).first()
    if not completion:
        return {"message": "Aufgabe war nicht abgeschlossen", "is_completed": False}
    db.delete(completion)
    db.commit()
    return {"message": "Aufgabe wieder geöffnet", "is_completed": False}

@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Aufgabe nicht gefunden")
    db.query(TaskCompletion).filter(TaskCompletion.task_id == task_id).delete()
    db.delete(task)
    db.commit()
    return None