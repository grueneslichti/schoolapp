from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher, get_current_student
from models import Teacher, Student, SchoolClass, ScheduleEntry
from schemas import ScheduleEntryCreate, ScheduleEntryResponse
import uuid
from datetime import time as time_type

router = APIRouter(prefix="/schedule", tags=["Schedule"])

def parse_time(time_str: str) -> time_type:
    try:
        parts = time_str.split(':')
        return time_type(int(parts[0]), int(parts[1]))
    except:
        raise HTTPException(status_code=400, detail=f"Ungültiges Zeitformat: {time_str}")

@router.get("/class/{class_id}", response_model=list[ScheduleEntryResponse])
def get_class_schedule(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    teacher_entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == class_id,
        ScheduleEntry.created_by_role == "teacher"
    ).all()
    my_entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == class_id,
        ScheduleEntry.created_by_role == "student",
        ScheduleEntry.created_by_id == current_student.id
    ).all()
    all_entries = teacher_entries + my_entries
    all_entries.sort(key=lambda e: (e.day_of_week, e.start_time))
    result = []
    for entry in all_entries:
        result.append(ScheduleEntryResponse(
            id=entry.id,
            class_id=entry.class_id,
            subject=entry.subject,
            day_of_week=entry.day_of_week,
            start_time=entry.start_time.strftime("%H:%M"),
            end_time=entry.end_time.strftime("%H:%M"),
            room=entry.room,
            created_by_role=entry.created_by_role,
            is_editable=(entry.created_by_role == "student" and entry.created_by_id == current_student.id)
        ))
    return result

@router.get("/teacher/class/{class_id}", response_model=list[ScheduleEntryResponse])
def get_class_schedule_teacher(
    class_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == class_id
    ).order_by(ScheduleEntry.day_of_week, ScheduleEntry.start_time).all()
    result = []
    for entry in entries:
        result.append(ScheduleEntryResponse(
            id=entry.id,
            class_id=entry.class_id,
            subject=entry.subject,
            day_of_week=entry.day_of_week,
            start_time=entry.start_time.strftime("%H:%M"),
            end_time=entry.end_time.strftime("%H:%M"),
            room=entry.room,
            created_by_role=entry.created_by_role,
            is_editable=(entry.created_by_role == "teacher")
        ))
    return result

@router.post("/teacher", response_model=ScheduleEntryResponse, status_code=status.HTTP_201_CREATED)
def create_teacher_schedule_entry(
    data: ScheduleEntryCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    school_class = db.query(SchoolClass).filter(SchoolClass.id == data.class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    start_time = parse_time(data.start_time)
    end_time = parse_time(data.end_time)
    if start_time >= end_time:
        raise HTTPException(status_code=400, detail="Startzeit muss vor der Endzeit liegen")
    overlapping = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == data.class_id,
        ScheduleEntry.day_of_week == data.day_of_week,
        ScheduleEntry.created_by_role == "teacher",
        ScheduleEntry.start_time < end_time,
        ScheduleEntry.end_time > start_time
    ).first()
    if overlapping:
        raise HTTPException(
            status_code=400, 
            detail=f"Überschneidung mit '{overlapping.subject}' ({overlapping.start_time.strftime('%H:%M')}-{overlapping.end_time.strftime('%H:%M')})"
        ) 
    new_entry = ScheduleEntry(
        class_id=data.class_id,
        subject=data.subject,
        day_of_week=data.day_of_week,
        start_time=start_time,
        end_time=end_time,
        room=data.room,
        created_by_role="teacher",
        created_by_id=current_teacher.id
    )
    db.add(new_entry)
    db.commit()
    db.refresh(new_entry)
    return ScheduleEntryResponse(
        id=new_entry.id,
        class_id=new_entry.class_id,
        subject=new_entry.subject,
        day_of_week=new_entry.day_of_week,
        start_time=new_entry.start_time.strftime("%H:%M"),
        end_time=new_entry.end_time.strftime("%H:%M"),
        room=new_entry.room,
        created_by_role=new_entry.created_by_role,
        is_editable=True
    )

@router.post("/student", response_model=ScheduleEntryResponse, status_code=status.HTTP_201_CREATED)
def create_student_schedule_entry(
    data: ScheduleEntryCreate,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    effective_class_id = data.class_id or current_student.class_id
    school_class = db.query(SchoolClass).filter(SchoolClass.id == effective_class_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Klasse nicht gefunden")
    start_time = parse_time(data.start_time)
    end_time = parse_time(data.end_time)
    if start_time >= end_time:
        raise HTTPException(status_code=400, detail="Startzeit muss vor der Endzeit liegen")
    new_entry = ScheduleEntry(
        class_id=effective_class_id,
        subject=data.subject,
        day_of_week=data.day_of_week,
        start_time=start_time,
        end_time=end_time,
        room=data.room,
        created_by_role="student",
        created_by_id=current_student.id
    )
    db.add(new_entry)
    db.commit()
    db.refresh(new_entry)
    return ScheduleEntryResponse(
        id=new_entry.id,
        class_id=new_entry.class_id,
        subject=new_entry.subject,
        day_of_week=new_entry.day_of_week,
        start_time=new_entry.start_time.strftime("%H:%M"),
        end_time=new_entry.end_time.strftime("%H:%M"),
        room=new_entry.room,
        created_by_role=new_entry.created_by_role,
        is_editable=True
    )

@router.delete("/student/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student_entry(
    entry_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    entry = db.query(ScheduleEntry).filter(
        ScheduleEntry.id == entry_id,
        ScheduleEntry.created_by_id == current_student.id,
        ScheduleEntry.created_by_role == "student"
    ).first() 
    if not entry:
        raise HTTPException(status_code=404, detail="Eintrag nicht gefunden oder keine Berechtigung") 
    db.delete(entry)
    db.commit()
    return None

@router.delete("/teacher/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_teacher_entry(
    entry_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    entry = db.query(ScheduleEntry).filter(
        ScheduleEntry.id == entry_id,
        ScheduleEntry.created_by_role == "teacher"
    ).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Eintrag nicht gefunden") 
    db.delete(entry)
    db.commit()
    return None

@router.get("/current-subject")
def get_current_subject(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    current_day = now.weekday()
    current_time = now.time() 
    entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == current_student.class_id,
        ScheduleEntry.day_of_week == current_day,
        ScheduleEntry.created_by_role == "teacher"
    ).all()
    for entry in entries:
        if entry.start_time <= current_time <= entry.end_time:
            return {
                "has_current_subject": True,
                "subject": entry.subject,
                "room": entry.room,
                "start_time": entry.start_time.strftime("%H:%M"),
                "end_time": entry.end_time.strftime("%H:%M")
            }
    return {"has_current_subject": False, "subject": None}

@router.get("/my-schedule", response_model=list[ScheduleEntryResponse])
def get_my_schedule(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    teacher_entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == current_student.class_id,
        ScheduleEntry.created_by_role == "teacher"
    ).all()
    my_entries = db.query(ScheduleEntry).filter(
        ScheduleEntry.class_id == current_student.class_id,
        ScheduleEntry.created_by_role == "student",
        ScheduleEntry.created_by_id == current_student.id
    ).all() 
    all_entries = teacher_entries + my_entries
    all_entries.sort(key=lambda e: (e.day_of_week, e.start_time))
    result = []
    for entry in all_entries:
        result.append(ScheduleEntryResponse(
            id=entry.id,
            class_id=entry.class_id,
            subject=entry.subject,
            day_of_week=entry.day_of_week,
            start_time=entry.start_time.strftime("%H:%M"),
            end_time=entry.end_time.strftime("%H:%M"),
            room=entry.room,
            created_by_role=entry.created_by_role,
            is_editable=(entry.created_by_role == "student" and entry.created_by_id == current_student.id)
        ))
    return result