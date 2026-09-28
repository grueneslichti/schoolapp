from sqladmin import BaseView, expose
from fastapi import Request
from fastapi.responses import RedirectResponse, JSONResponse
from core.database import SessionLocal
from models import Student, SchoolClass, School, PromotionHistory
import uuid
from datetime import datetime,timezone, timedelta
import json

class PromotionManagerAdmin(BaseView):
    name = "Klassenversetzung"
    icon = "fa-solid fa-arrow-up-right-dots"

    @expose("/promotion-manager", methods=["GET"])
    async def list_classes(self, request: Request):
        db = SessionLocal()
        try:
            classes = db.query(SchoolClass).order_by(SchoolClass.name).all()
            schools = db.query(School).order_by(School.name).all()
            classes_data = []
            for c in classes:
                school = db.query(School).filter(School.id == c.school_id).first()
                student_count = db.query(Student).filter(Student.class_id == c.id).count()
                classes_data.append({
                    "id": str(c.id),
                    "name": c.name,
                    "level": c.level,
                    "school_name": school.name if school else "Unbekannt",
                    "student_count": student_count,
                })
            return await self.templates.TemplateResponse(
                request=request,
                name="promotion_manager.html",
                context={
                    "classes": classes_data,
                    "schools": schools
                }
            )
        finally:
            db.close()

    @expose("/promotion-manager/class/{class_id}", methods=["GET"])
    async def show_class_students(self, request: Request, class_id: str | None = None):
        """Zeigt alle Schüler einer Klasse für die Einzelversetzung."""
        class_id = class_id or request.path_params.get("class_id") or request.query_params.get("class_id")
        if not class_id:
            return RedirectResponse(url="/admin/promotion-manager", status_code=302)
        try:
            class_uuid = uuid.UUID(str(class_id))
        except ValueError:
            return RedirectResponse(url="/admin/promotion-manager", status_code=302)
        db = SessionLocal()
        try:
            school_class = db.query(SchoolClass).filter(SchoolClass.id == class_uuid).first()
            if not school_class:
                return RedirectResponse(url="/admin/promotion-manager", status_code=302)
            students = db.query(Student).filter(Student.class_id == class_uuid).all()
            all_classes = db.query(SchoolClass).order_by(SchoolClass.name).all()
            students_data = []
            for s in students:
                students_data.append({
                    "id": str(s.id),
                    "name": s.real_name,
                    "pseudonym": s.pseudonym,
                    "xp": s.xp or 0,
                    "class_id": str(class_uuid)
                })
            classes_data = []
            for c in all_classes:
                school = db.query(School).filter(School.id == c.school_id).first()
                classes_data.append({
                    "id": str(c.id),
                    "display_name": f"{school.name if school else '?'} - {c.name}"
                })
            return await self.templates.TemplateResponse(
                request=request,
                name="promotion_class_students.html",
                context={
                    "school_class": school_class,
                    "students": students_data,
                    "all_classes": classes_data
                }
            )
        finally:
            db.close()

    @expose("/promotion-manager/api/promote", methods=["POST"])
    async def api_promote(self, request: Request):
        data = await request.json()
        student_id = data.get("student_id")
        new_class_id = data.get("new_class_id")
        try:
            student_id = uuid.UUID(student_id)
            new_class_id = uuid.UUID(new_class_id)
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Ungültige IDs"})
        db = SessionLocal()
        try:
            student = db.query(Student).filter(Student.id == student_id).first()
            if not student:
                return JSONResponse(status_code=404, content={"detail": "Schüler nicht gefunden"})
            new_class = db.query(SchoolClass).filter(SchoolClass.id == new_class_id).first()
            if not new_class:
                return JSONResponse(status_code=404, content={"detail": "Klasse nicht gefunden"})
            student.class_id = new_class_id
            db.commit()
            return JSONResponse(
                status_code=200,
                content={"message": f"{student.real_name} in Klasse {new_class.name} versetzt"}
            )
        finally:
            db.close()

    @expose("/promotion-manager/api/bulk-promote", methods=["POST"])
    async def api_bulk_promote(self, request: Request):
        data = await request.json()
        from_class_id = data.get("from_class_id")
        to_class_id = data.get("to_class_id")
        only_older_than_days = data.get("only_older_than_days")
        try:
            from_class_id = uuid.UUID(from_class_id)
            to_class_id = uuid.UUID(to_class_id)
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Ungültige IDs"})
        db = SessionLocal()
        try:
            admin_name = data.get("admin_name", "Admin")
            students = db.query(Student).filter(Student.class_id == from_class_id).all()
            if only_older_than_days:
                cutoff_date = datetime.now(timezone.utc) - timedelta(days=only_older_than_days)
                filtered_students = []
                for student in students:
                    last_promotion = db.query(PromotionHistory).filter(
                       PromotionHistory.student_id == student.id
                    ).order_by(PromotionHistory.promoted_at.desc()).first()
                    if not last_promotion or last_promotion.promoted_at < cutoff_date:
                        filtered_students.append(student)
                students = filtered_students
            count = 0
            history_ids = []
            for s in students:
                history = PromotionHistory(
                    student_id=s.id,
                    from_class_id=from_class_id,
                    to_class_id=to_class_id,
                    promoted_by=admin_name
                )
                db.add(history)
                db.flush()
                history_ids.append(str(history.id))
                s.class_id = to_class_id
                count += 1
            db.commit()
            return JSONResponse(
                status_code=200,
                content={
                    "message": f"{count} Schüler versetzt",
                    "count": count,
                    "history_ids": history_ids
                }
            )
        finally:
            db.close()

    @expose("/promotion-manager/api/graduate", methods=["POST"])
    async def api_graduate(self, request: Request):
        data = await request.json()
        student_id = data.get("student_id")
        keep_profile = data.get("keep_profile", False)
        try:
            student_id = uuid.UUID(student_id)
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Ungültige student_id"})
        db = SessionLocal()
        try:
            student = db.query(Student).filter(Student.id == student_id).first()
            if not student:
                return JSONResponse(status_code=404, content={"detail": "Schüler nicht gefunden"})
            if not keep_profile:
                from models import Avatar, AvatarItem, Friendship, XPTransfer
                db.query(AvatarItem).filter(AvatarItem.student_id == student.id).delete()
                db.query(Avatar).filter(Avatar.student_id == student.id).delete()
                db.query(Friendship).filter(
                    (Friendship.student_id_1 == student.id) | (Friendship.student_id_2 == student.id)
                ).delete(synchronize_session=False)
                db.query(XPTransfer).filter(
                    (XPTransfer.sender_id == student.id) | (XPTransfer.receiver_id == student.id)
                ).delete(synchronize_session=False)
            db.delete(student)
            db.commit()
            return JSONResponse(
                status_code=200,
                content={"message": f"{student.real_name} wurde abgeschlossen"}
            )
        finally:
            db.close()

    @expose("/promotion-manager/api/undo", methods=["POST"])
    async def api_undo(self, request: Request):

        data = await request.json()
        history_id_str = data.get("history_id")  
        try:
            history_id = uuid.UUID(history_id_str)
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Ungültige history_id"})  
        db = SessionLocal()
        try:
            history = db.query(PromotionHistory).filter(PromotionHistory.id == history_id).first()
            if not history:
                return JSONResponse(status_code=404, content={"detail": "History-Eintrag nicht gefunden"}) 
            student = db.query(Student).filter(Student.id == history.student_id).first()
            if not student or student.class_id != history.to_class_id:
                return JSONResponse(
                    status_code=400,
                    content={"detail": "Schüler ist nicht mehr in der Zielklasse"}
                )
            student.class_id = history.from_class_id
            db.delete(history)
            db.commit()
            return JSONResponse(
                status_code=200,
                content={"message": f"{student.real_name} zurückversetzt"}
            )
        finally:
            db.close()

    @expose("/promotion-manager/api/bulk-undo", methods=["POST"])
    async def api_bulk_undo(self, request: Request):
        data = await request.json()
        history_ids_str = data.get("history_ids", [])
        try:
            history_ids = [uuid.UUID(hid) for hid in history_ids_str]
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Ungültige history_ids"})
        db = SessionLocal()
        try:
            undone = 0
            failed = 0
            for hid in history_ids:
                history = db.query(PromotionHistory).filter(PromotionHistory.id == hid).first()
                if not history:
                    failed += 1
                    continue
                student = db.query(Student).filter(Student.id == history.student_id).first()
                if not student or student.class_id != history.to_class_id:
                    failed += 1
                    continue
                student.class_id = history.from_class_id
                db.delete(history)
                undone += 1
            db.commit()
            return JSONResponse(
                status_code=200,
                content={
                    "message": f"{undone} Versetzungen rückgängig gemacht",
                    "undone": undone,
                    "failed": failed
                }
            )
        finally:
            db.close()

    @expose("/promotion-manager/api/history/{class_id}", methods=["GET"])
    async def api_get_history(self, request: Request, class_id: str | None = None):
        class_id = class_id or request.path_params.get("class_id") or request.query_params.get("class_id")
        if not class_id:
            return JSONResponse(status_code=400, content={"detail": "class_id fehlt"})
        db = SessionLocal()
        try:
            try:
                class_uuid = uuid.UUID(str(class_id))
            except ValueError:
                return JSONResponse(status_code=400, content={"detail": "Ungültige class_id"})
            history = db.query(PromotionHistory).filter(
                PromotionHistory.to_class_id == class_uuid
            ).order_by(PromotionHistory.promoted_at.desc()).all()
            result = []
            for h in history:
                student = db.query(Student).filter(Student.id == h.student_id).first()
                from_class = db.query(SchoolClass).filter(SchoolClass.id == h.from_class_id).first()
                result.append({
                    "history_id": str(h.id),
                    "student_name": student.real_name if student else "Unbekannt",
                    "from_class": from_class.name if from_class else "Unbekannt",
                    "promoted_at": h.promoted_at.isoformat(),
                    "promoted_by": h.promoted_by,
                    "class_id": str(class_uuid)
                })
            return JSONResponse(status_code=200, content={"history": result})
        finally:
            db.close()

@expose("/promotion-manager/school-transfer", methods=["GET"])
async def school_transfer_page(self, request: Request):
    """Seite für Schulwechsel (Umzug oder Abschluss)."""
    db = SessionLocal()
    try:
        students = db.query(Student).all()
        schools = db.query(School).order_by(School.name).all()
        classes = db.query(SchoolClass).order_by(SchoolClass.school_id, SchoolClass.name).all()
        students_data = []
        for s in students:
            school_class = db.query(SchoolClass).filter(SchoolClass.id == s.class_id).first()
            school = db.query(School).filter(School.id == school_class.school_id).first() if school_class else None
            students_data.append({
                "id": str(s.id),
                "name": s.real_name,
                "pseudonym": s.pseudonym,
                "current_class": school_class.name if school_class else "?",
                "current_school": school.name if school else "?",
                "current_school_id": str(school.id) if school else "",
                "xp": s.xp or 0
            })      
        schools_data = []
        for school in schools:
            schools_data.append({
                "id": str(school.id),
                "name": school.name,
                "country_code": school.country_code
            })   
        classes_data = []
        for c in classes:
            school = db.query(School).filter(School.id == c.school_id).first()
            classes_data.append({
                "id": str(c.id),
                "name": c.name,
                "school_id": str(c.school_id),
                "school_name": school.name if school else "?"
            })     
        return await self.templates.TemplateResponse(
            request=request,
            name="school_transfer.html",
            context={
                "students": students_data,
                "schools": schools_data,
                "classes": classes_data
            }
        )
    finally:
        db.close()

@expose("/promotion-manager/api/transfer-school", methods=["POST"])
async def api_transfer_school(self, request: Request):
    """API: Schüler an andere Schule versetzen."""
    data = await request.json()
    student_id_str = data.get("student_id")
    new_class_id_str = data.get("new_class_id")
    transfer_type = data.get("transfer_type", "school_transfer")
    classmates = db.query(Student).filter(Student.class_id == old_class.id).all()
    classmate_ids = [str(c.id) for c in classmates]
    student.pending_graduation_photo = True
    student.graduation_classmate_ids = json.dumps(classmate_ids)
    student.graduation_class_name = old_class.name
    student.class_id = data.new_class_id
    try:
        student_id = uuid.UUID(student_id_str)
        new_class_id = uuid.UUID(new_class_id_str)
    except ValueError:
        return JSONResponse(status_code=400, content={"detail": "Ungültige IDs"})
    db = SessionLocal()
    try:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student:
            return JSONResponse(status_code=404, content={"detail": "Schüler nicht gefunden"}) 
        old_class = db.query(SchoolClass).filter(SchoolClass.id == student.class_id).first()
        new_class = db.query(SchoolClass).filter(SchoolClass.id == new_class_id).first()
        if not old_class or not new_class:
            return JSONResponse(status_code=404, content={"detail": "Klasse nicht gefunden"})
        if old_class.school_id == new_class.school_id:
            return JSONResponse(
                status_code=400,
                content={"detail": "Für Wechsel innerhalb der gleichen Schule nutze die normale Versetzung"}
            )
        history = PromotionHistory(
            student_id=student.id,
            from_class_id=student.class_id,
            to_class_id=new_class_id,
            from_school_id=old_class.school_id,
            to_school_id=new_class.school_id,
            transfer_type=transfer_type,
            promoted_by="Admin"
        )
        db.add(history)
        student.class_id = new_class_id
        if transfer_type == "school_transfer":
            student.xp = (student.xp or 0) + 10
        db.commit()
        old_school = db.query(School).filter(School.id == old_class.school_id).first()
        new_school = db.query(School).filter(School.id == new_class.school_id).first()      
        return {
            "message": f"{student.real_name} erfolgreich versetzt von {old_school.name} nach {new_school.name}",
            "student_name": student.real_name,
            "from_school": old_school.name,
            "to_school": new_school.name
        }
    except Exception as e:
        db.rollback()
        return JSONResponse(status_code=500, content={"detail": str(e)})
    finally:
        db.close()