from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from core.database import get_db
from core.security.security import get_current_student
from core.config import settings
from models import Student, Friendship, XPGift, SchoolClass, FriendRequest
from schemas import XPGiftCreate, XPGiftResponse, FriendResponse, XPGiftResult
import uuid
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/friends", tags=["Friends"])

@router.get("/my-friends", response_model=list[FriendResponse])
def get_my_friends(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    friendships = db.query(Friendship).filter(
        (Friendship.student_id_1 == current_student.id) |
        (Friendship.student_id_2 == current_student.id)
    ).all()  
    friends = []
    for friendship in friendships:
        friend_id = friendship.student_id_2 if friendship.student_id_1 == current_student.id else friendship.student_id_1
        friend = db.query(Student).filter(Student.id == friend_id).first()     
        if friend:
            school_class = db.query(SchoolClass).filter(SchoolClass.id == friend.class_id).first()
            friends.append(FriendResponse(
                id=friend.id,
                pseudonym=friend.pseudonym,
                real_name=friend.real_name,
                class_name=school_class.name if school_class else "Unbekannt",
                xp=friend.xp or 0
            ))
    return friends

@router.get("/search")
def search_students(
    q: str = Query(..., min_length=2),
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
): 
    results = db.query(Student).filter(
        Student.id != current_student.id,
        (Student.real_name.ilike(f"%{q}%")) | (Student.pseudonym.ilike(f"%{q}%"))
    ).limit(20).all() 
    response = []
    for student in results:
        school_class = db.query(SchoolClass).filter(SchoolClass.id == student.class_id).first()
        existing_friendship = db.query(Friendship).filter(
            ((Friendship.student_id_1 == current_student.id) & (Friendship.student_id_2 == student.id)) |
            ((Friendship.student_id_1 == student.id) & (Friendship.student_id_2 == current_student.id))
        ).first() 
        existing_request = db.query(FriendRequest).filter(
            FriendRequest.sender_id == current_student.id,
            FriendRequest.receiver_id == student.id,
            FriendRequest.status == "pending"
        ).first() 
        response.append({
            "id": str(student.id),
            "real_name": student.real_name,
            "pseudonym": student.pseudonym,
            "class_name": school_class.name if school_class else "Unbekannt",
            "is_already_friend": existing_friendship is not None,
            "request_already_sent": existing_request is not None
        })
    return response

@router.post("/request")
def send_friend_request(
    receiver_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    receiver = db.query(Student).filter(Student.id == receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")
    if receiver.id == current_student.id:
        raise HTTPException(status_code=400, detail="Du kannst dich nicht selbst anfragen")
    existing_friendship = db.query(Friendship).filter(
        ((Friendship.student_id_1 == current_student.id) & (Friendship.student_id_2 == receiver.id)) |
        ((Friendship.student_id_1 == receiver.id) & (Friendship.student_id_2 == current_student.id))
    ).first() 
    if existing_friendship:
        raise HTTPException(status_code=400, detail="Ihr seid bereits Freunde")  
    existing_request = db.query(FriendRequest).filter(
        FriendRequest.sender_id == current_student.id,
        FriendRequest.receiver_id == receiver.id,
        FriendRequest.status == "pending"
    ).first()  
    if existing_request:
        raise HTTPException(status_code=400, detail="Anfrage wurde bereits gesendet")
    new_request = FriendRequest(
        sender_id=current_student.id,
        receiver_id=receiver.id,
        status="pending"
    )
    db.add(new_request)
    db.commit()
    return {"message": f"Freundesanfrage an {receiver.real_name} gesendet!"}

@router.get("/requests")
def get_friend_requests(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    requests = db.query(FriendRequest).filter(
        FriendRequest.receiver_id == current_student.id,
        FriendRequest.status == "pending"
    ).order_by(FriendRequest.created_at.desc()).all()
    response = []
    for req in requests:
        sender = db.query(Student).filter(Student.id == req.sender_id).first()
        school_class = db.query(SchoolClass).filter(SchoolClass.id == sender.class_id).first() if sender else None
        response.append({
            "id": str(req.id),
            "sender_id": str(sender.id) if sender else "",
            "sender_name": sender.real_name if sender else "Unbekannt",
            "sender_pseudonym": sender.pseudonym if sender else "",
            "sender_class": school_class.name if school_class else "Unbekannt",
            "created_at": req.created_at.isoformat() if req.created_at else ""
        })
    return response

@router.post("/requests/{request_id}/accept")
def accept_friend_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    req = db.query(FriendRequest).filter(
        FriendRequest.id == request_id,
        FriendRequest.receiver_id == current_student.id,
        FriendRequest.status == "pending"
    ).first()
    if not req:
        raise HTTPException(status_code=404, detail="Anfrage nicht gefunden")
    new_friendship = Friendship(
        student_id_1=req.sender_id,
        student_id_2=req.receiver_id
    )
    db.add(new_friendship)
    req.status = "accepted"
    db.commit()
    return {"message": "Freundschaft bestätigt! 🎉"}

@router.post("/requests/{request_id}/decline")
def decline_friend_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    req = db.query(FriendRequest).filter(
        FriendRequest.id == request_id,
        FriendRequest.receiver_id == current_student.id,
        FriendRequest.status == "pending"
    ).first()
    if not req:
        raise HTTPException(status_code=404, detail="Anfrage nicht gefunden") 
    req.status = "declined"
    db.commit()
    return {"message": "Anfrage abgelehnt"}

@router.get("/remaining-xp")
def get_remaining_xp(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    spent_xp = db.query(func.coalesce(func.sum(XPGift.amount), 0)).filter(
        XPGift.sender_id == current_student.id,
        XPGift.created_at >= week_ago
    ).scalar()
    remaining = max(0, settings.WEEKLY_XP_GIFT_LIMIT - spent_xp)
    return {
        "weekly_limit": settings.WEEKLY_XP_GIFT_LIMIT,
        "spent_this_week": spent_xp,
        "remaining": remaining
    }

@router.post("/give-xp", response_model=XPGiftResult)
def give_xp_to_friend(
    gift_data: XPGiftCreate,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    receiver = db.query(Student).filter(Student.id == gift_data.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Schüler nicht gefunden")   
    if receiver.id == current_student.id:
        raise HTTPException(status_code=400, detail="Du kannst dir nicht selbst XP geben")
    friendship = db.query(Friendship).filter(
        ((Friendship.student_id_1 == current_student.id) & (Friendship.student_id_2 == receiver.id)) |
        ((Friendship.student_id_1 == receiver.id) & (Friendship.student_id_2 == current_student.id))
    ).first()
    if not friendship:
        raise HTTPException(status_code=403, detail="Du kannst nur Freunden XP geben") 
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    spent_xp = db.query(func.coalesce(func.sum(XPGift.amount), 0)).filter(
        XPGift.sender_id == current_student.id,
        XPGift.created_at >= week_ago
    ).scalar() 
    remaining = settings.WEEKLY_XP_GIFT_LIMIT - spent_xp 
    if gift_data.amount > remaining:
        return XPGiftResult(
            success=False,
            message=f"Du hast diese Woche zuviel XP verschenkt.",
            remaining_weekly_xp=remaining
        )  
    new_gift = XPGift(
        sender_id=current_student.id,
        receiver_id=receiver.id,
        amount=gift_data.amount,
        message=gift_data.message
    )
    db.add(new_gift)  
    receiver.xp = (receiver.xp or 0) + gift_data.amount
    db.commit()
    db.refresh(receiver)
    new_remaining = remaining - gift_data.amount
    return XPGiftResult(
        success=True,
        message=f"🎉 Du hast {receiver.real_name} {gift_data.amount} XP geschenkt!",
        remaining_weekly_xp=new_remaining,
        total_xp_receiver=receiver.xp
    )

@router.get("/xp-notifications")
def get_xp_notifications(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    query = db.query(XPGift).filter(
        XPGift.receiver_id == current_student.id
    )
    if current_student.last_xp_notification_seen:
        query = query.filter(XPGift.created_at > current_student.last_xp_notification_seen)
    gifts = query.order_by(XPGift.created_at.desc()).all()
    notifications = []
    for gift in gifts:
        sender = db.query(Student).filter(Student.id == gift.sender_id).first()
        school_class = db.query(SchoolClass).filter(SchoolClass.id == sender.class_id).first() if sender else None 
        notifications.append({
            "id": str(gift.id),
            "sender_name": sender.real_name if sender else "Unbekannt",
            "sender_class": school_class.name if school_class else "",
            "amount": gift.amount,
            "message": gift.message,
            "created_at": gift.created_at.isoformat() if gift.created_at else ""
        })
    total_xp = sum(g.amount for g in gifts)
    return {
        "notifications": notifications,
        "total_xp_received": total_xp,
        "count": len(notifications)
    }

@router.post("/xp-notifications/read")
def mark_xp_notifications_read(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    current_student.last_xp_notification_seen = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Benachrichtigungen als gelesen markiert"}