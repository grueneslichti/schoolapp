from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from models import Student, XPTransfer, Performance, Friendship
from pydantic import BaseModel
from datetime import datetime, timedelta
import uuid

router = APIRouter(prefix="/xp", tags=["XP Transfer"])

class XPTransferRequest(BaseModel):
    receiver_id: uuid.UUID
    amount: int
    reason: str

MAX_XP_PER_WEEK = 50

@router.post("/give")
def give_xp(
    transfer: XPTransferRequest,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    receiver = db.query(Student).filter(Student.id == transfer.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Empfänger nicht gefunden")
    if receiver.id == current_student.id:
        raise HTTPException(status_code=400, detail="Du kannst dir nicht selbst XP geben")
    friendship = db.query(Friendship).filter(
        ((Friendship.student_id_1 == current_student.id) & (Friendship.student_id_2 == receiver.id)) |
        ((Friendship.student_id_1 == receiver.id) & (Friendship.student_id_2 == current_student.id))
    ).filter(Friendship.status == "accepted").first()
    if not friendship:
        raise HTTPException(status_code=403, detail="Du kannst nur Freunden XP geben")
    if transfer.amount < 5 or transfer.amount > 50:
        raise HTTPException(status_code=400, detail="XP-Betrag muss zwischen 5 und 50 liegen")
    one_week_ago = datetime.now() - timedelta(days=7)
    weekly_transfers = db.query(XPTransfer).filter(
        XPTransfer.sender_id == current_student.id,
        XPTransfer.created_at >= one_week_ago
    ).all()
    total_given_this_week = sum(t.amount for t in weekly_transfers)
    if total_given_this_week + transfer.amount > MAX_XP_PER_WEEK:
        remaining = MAX_XP_PER_WEEK - total_given_this_week
        raise HTTPException(
            status_code=400, 
            detail=f"Wöchentliches Limit erreicht!"
        )
    new_transfer = XPTransfer(
        sender_id=current_student.id,
        receiver_id=transfer.receiver_id,
        amount=transfer.amount,
        reason=transfer.reason
    )
    db.add(new_transfer)
    receiver_performance = db.query(Performance).filter(Performance.student_id == receiver.id).first()
    if not receiver_performance:
        receiver_performance = Performance(student_id=receiver.id, xp=0, level=1, streak_days=0)
        db.add(receiver_performance)
    receiver_performance.xp += transfer.amount
    db.commit()
    return {
        "message": f"{transfer.amount} XP an {receiver.real_name} gesendet!",
        "reason": transfer.reason,
        "weekly_limit_remaining": MAX_XP_PER_WEEK - (total_given_this_week + transfer.amount)
    }

@router.get("/history")
def get_xp_history(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    sent = db.query(XPTransfer).filter(XPTransfer.sender_id == current_student.id).order_by(XPTransfer.created_at.desc()).limit(10).all()
    received = db.query(XPTransfer).filter(XPTransfer.receiver_id == current_student.id).order_by(XPTransfer.created_at.desc()).limit(10).all()
    history = []
    for t in sent:
        sender = db.query(Student).filter(Student.id == t.sender_id).first()
        receiver = db.query(Student).filter(Student.id == t.receiver_id).first()
        history.append({
            "type": "sent",
            "to": receiver.real_name,
            "amount": t.amount,
            "reason": t.reason,
            "date": t.created_at.isoformat()
        })
    for t in received:
        sender = db.query(Student).filter(Student.id == t.sender_id).first()
        history.append({
            "type": "received",
            "from": sender.real_name,
            "amount": t.amount,
            "reason": t.reason,
            "date": t.created_at.isoformat()
        })
    history.sort(key=lambda x: x["date"], reverse=True)
    return {"history": history[:20]}