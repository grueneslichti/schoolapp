from sqlalchemy.orm import Session
from core import models, schemas
from typing import List
import uuid

def create_ticket(db: Session, ticket: schemas.TicketCreate, student_pseudonym: str, school_id: uuid.UUID) -> models.FeedbackTicket:
 
    reporter = None if ticket.is_anonymous else student_pseudonym
    db_ticket = models.FeedbackTicket(
        school_id=school_id,
        category=ticket.category,
        message=ticket.message,
        reporter_pseudonym=reporter,
        is_anonymous=ticket.is_anonymous
    )
    db.add(db_ticket)
    db.commit()
    db.refresh(db_ticket)
    return db_ticket

def get_tickets_by_school(db: Session, school_id: uuid.UUID, skip: int = 0, limit: int = 100) -> List[models.FeedbackTicket]:
    return (
        db.query(models.FeedbackTicket)
        .filter(models.FeedbackTicket.school_id == school_id)
        .order_by(models.FeedbackTicket.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

def delete_ticket(db: Session, ticket_id: uuid.UUID) -> bool:
    """
    Löscht ein Ticket (z.B. wenn es bearbeitet wurde oder abgelaufen ist).
    """
    db_ticket = db.query(models.FeedbackTicket).filter(models.FeedbackTicket.id == ticket_id).first()
    if db_ticket:
        db.delete(db_ticket)
        db.commit()
        return True
    return False