from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_teacher
from models import Teacher, TeacherMessage, TeacherSchoolAssignment, School
from schemas import TeacherMessageCreate, TeacherMessageResponse, TeacherContact
import uuid

router = APIRouter(prefix="/teacher-messages", tags=["Teacher Messages"])

def get_teacher_school_ids(db: Session, teacher_id: uuid.UUID) -> list[uuid.UUID]:
    teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
    school_ids = {teacher.school_id} if teacher and teacher.school_id else set()
    assignments = db.query(TeacherSchoolAssignment).filter(
        TeacherSchoolAssignment.teacher_id == teacher_id
    ).all()
    school_ids.update(a.school_id for a in assignments)
    return list(school_ids)

@router.get("/contacts", response_model=list[TeacherContact])
def get_contacts(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    my_school_ids = get_teacher_school_ids(db, current_teacher.id)
    if not my_school_ids:
        return []
    teachers = db.query(Teacher).filter(
        Teacher.id != current_teacher.id
    ).all()
    result = []
    for t in teachers:
        shared_school_ids = set(my_school_ids).intersection(
            get_teacher_school_ids(db, t.id)
        )
        if not shared_school_ids:
            continue
        school = db.query(School).filter(School.id == next(iter(shared_school_ids))).first()
        result.append(TeacherContact(
            id=t.id,
            name=t.full_name,
            email=t.email,
            school_name=school.name if school else None
        ))
    result.sort(key=lambda x: x.name)
    return result

@router.get("/inbox", response_model=list[TeacherMessageResponse])
def get_inbox(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    messages = db.query(TeacherMessage).filter(
        TeacherMessage.receiver_id == current_teacher.id,
        TeacherMessage.deleted_by_receiver == False
    ).order_by(TeacherMessage.created_at.desc()).all() 
    return [_enrich_message(db, m) for m in messages]

@router.get("/sent", response_model=list[TeacherMessageResponse])
def get_sent(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    messages = db.query(TeacherMessage).filter(
        TeacherMessage.sender_id == current_teacher.id,
        TeacherMessage.deleted_by_sender == False
    ).order_by(TeacherMessage.created_at.desc()).all()   
    return [_enrich_message(db, m) for m in messages]

@router.get("/unread-count")
def get_unread_count(
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    count = db.query(TeacherMessage).filter(
        TeacherMessage.receiver_id == current_teacher.id,
        TeacherMessage.is_read == False,
        TeacherMessage.deleted_by_receiver == False
    ).count()
    return {"unread_count": count}

@router.post("/send", response_model=TeacherMessageResponse, status_code=status.HTTP_201_CREATED)
def send_message(
    data: TeacherMessageCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    receiver = db.query(Teacher).filter(Teacher.id == data.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Empfänger nicht gefunden")
    my_schools = set(get_teacher_school_ids(db, current_teacher.id))
    receiver_schools = set(get_teacher_school_ids(db, receiver.id))
    if not my_schools.intersection(receiver_schools):
        raise HTTPException(
            status_code=403,
            detail="Sie können nur Lehrer in der Schule anschreiben in der Sie zugewießen sind"
        )
    new_message = TeacherMessage(
        sender_id=current_teacher.id,
        receiver_id=receiver.id,
        subject=data.subject,
        message=data.message
    )
    db.add(new_message)
    db.commit()
    db.refresh(new_message)  
    return _enrich_message(db, new_message)

@router.put("/{message_id}/read")
def mark_as_read(
    message_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    message = db.query(TeacherMessage).filter(TeacherMessage.id == message_id).first()
    if not message:
        raise HTTPException(status_code=404, detail="Nachricht nicht gefunden")
    if message.receiver_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Nicht berechtigt")
    message.is_read = True
    db.commit()
    return {"message": "Als gelesen markiert"}

@router.delete("/{message_id}")
def delete_message(
    message_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    message = db.query(TeacherMessage).filter(TeacherMessage.id == message_id).first()
    if not message:
        raise HTTPException(status_code=404, detail="Nachricht nicht gefunden")
    if message.sender_id == current_teacher.id:
        message.deleted_by_sender = True
    elif message.receiver_id == current_teacher.id:
        message.deleted_by_receiver = True
    else:
        raise HTTPException(status_code=403, detail="Nicht berechtigt")
    if message.deleted_by_sender and message.deleted_by_receiver:
        db.delete(message)
    db.commit()
    return {"message": "Nachricht gelöscht"}

def _enrich_message(db: Session, message: TeacherMessage) -> TeacherMessageResponse:
    sender = db.query(Teacher).filter(Teacher.id == message.sender_id).first()
    receiver = db.query(Teacher).filter(Teacher.id == message.receiver_id).first()
    return TeacherMessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        sender_name=sender.full_name if sender else "Unbekannt",
        receiver_id=message.receiver_id,
        receiver_name=receiver.full_name if receiver else "Unbekannt",
        subject=message.subject,
        message=message.message,
        is_read=message.is_read,
        created_at=message.created_at
    )