from sqladmin import BaseView, expose
from fastapi import Request
from fastapi.responses import RedirectResponse, JSONResponse
from core.database import SessionLocal
from models import (
    Teacher,
    School,
    SchoolClass,
    TeacherAssignment,
    TeacherSchoolAssignment,
)
import uuid

class AssignmentManagerAdmin(BaseView):
    name = "Schnellzuweisung"
    icon = "fa-solid fa-chalkboard-teacher"
    @expose("/assignment-manager", methods=["GET"])
    async def list_teachers(self, request: Request):
        db = SessionLocal()
        try:
            teachers = db.query(Teacher).order_by(Teacher.full_name).all()
            teacher_stats = {}
            school_stats = {}
            for teacher in teachers:
                assignment_count = db.query(TeacherAssignment).filter(
                    TeacherAssignment.teacher_id == teacher.id
                ).count()
                school_count = db.query(TeacherSchoolAssignment).filter(
                    TeacherSchoolAssignment.teacher_id == teacher.id
                ).count()
                teacher_stats[str(teacher.id)] = assignment_count
                school_stats[str(teacher.id)] = school_count
            return await self.templates.TemplateResponse(
                request=request,
                name="assignment_manager_list.html",
                context={
                    "teachers": teachers,
                    "teacher_stats": teacher_stats,
                    "school_stats": school_stats,
                },
            )
        finally:
            db.close()

    @expose("/assignment-manager/edit", methods=["GET"])
    async def edit_teacher(self, request: Request):
        teacher_id_str = request.query_params.get("teacher_id")
        if not teacher_id_str:
            return RedirectResponse(url="/admin/assignment-manager", status_code=302)
        try:
            teacher_id = uuid.UUID(teacher_id_str)
        except ValueError:
            return RedirectResponse(url="/admin/assignment-manager", status_code=302)
        db = SessionLocal()
        try:
            teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
            if not teacher:
                return RedirectResponse(url="/admin/assignment-manager", status_code=302)
            schools = db.query(School).order_by(School.name).all()
            assigned_school_rows = db.query(TeacherSchoolAssignment).filter(
                TeacherSchoolAssignment.teacher_id == teacher_id
            ).all()
            assigned_school_ids = [str(row.school_id) for row in assigned_school_rows]
            assigned_school_uuid_ids = [row.school_id for row in assigned_school_rows]
            classes_query = db.query(SchoolClass)
            if assigned_school_uuid_ids:
                classes_query = classes_query.filter(
                    SchoolClass.school_id.in_(assigned_school_uuid_ids)
                )
                classes = classes_query.order_by(SchoolClass.school_id, SchoolClass.name).all()
            else:
                classes = []
            classes_with_school = []
            for c in classes:
                school_name = c.school.name if c.school else "Unbekannt"
                classes_with_school.append({
                    "id": str(c.id),
                    "name": c.name,
                    "level": c.level,
                    "school_id": str(c.school_id),
                    "school_name": school_name,
                    "display_name": f"{school_name} - {c.name}",
                })
            schools_data = []
            for s in schools:
                schools_data.append({
                    "id": str(s.id),
                    "name": s.name,
                    "country_code": s.country_code,
                    "is_assigned": str(s.id) in assigned_school_ids,
                })
            assignments = db.query(TeacherAssignment).filter(
                TeacherAssignment.teacher_id == teacher_id
            ).all()
            subjects = {}
            for a in assignments:
                if a.subject not in subjects:
                    subjects[a.subject] = []
                subjects[a.subject].append(str(a.class_id))
            return await self.templates.TemplateResponse(
                request=request,
                name="assignment_manager_edit.html",
                context={
                    "teacher": teacher,
                    "schools": schools_data,
                    "assigned_school_ids": assigned_school_ids,
                    "classes": classes_with_school,
                    "subjects": subjects,
                },
            )
        finally:
            db.close()

    @expose("/assignment-manager/save-schools", methods=["POST"])
    async def save_schools(self, request: Request):

        data = await request.json()
        teacher_id_str = data.get("teacher_id")
        school_id_strs = data.get("school_ids", [])
        try:
            teacher_id = uuid.UUID(teacher_id_str)
            new_school_ids = [uuid.UUID(sid) for sid in school_id_strs]
        except Exception:
            return JSONResponse(
                status_code=400,
                content={"detail": "Ungültige teacher_id oder school_ids"},
            )
        db = SessionLocal()
        try:
            teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
            if not teacher:
                return JSONResponse(
                    status_code=404,
                    content={"detail": "Lehrer nicht gefunden"},
                )
            db.query(TeacherSchoolAssignment).filter(
                TeacherSchoolAssignment.teacher_id == teacher_id
            ).delete()
            for school_id in new_school_ids:
                school = db.query(School).filter(School.id == school_id).first()
                if school:
                    db.add(TeacherSchoolAssignment(
                        teacher_id=teacher_id,
                        school_id=school_id,
                    ))
            if new_school_ids:
                allowed_class_ids = db.query(SchoolClass.id).filter(
                    SchoolClass.school_id.in_(new_school_ids)
                ).all()
                allowed_class_ids = [row[0] for row in allowed_class_ids]
                db.query(TeacherAssignment).filter(
                    TeacherAssignment.teacher_id == teacher_id,
                    ~TeacherAssignment.class_id.in_(allowed_class_ids)
                ).delete(synchronize_session=False)
            else:
                db.query(TeacherAssignment).filter(
                    TeacherAssignment.teacher_id == teacher_id
                ).delete()
            db.commit()
            return JSONResponse(
                content={
                    "message": "Schul-Zuweisungen gespeichert",
                    "school_count": len(new_school_ids),
                }
            )
        except Exception as e:
            db.rollback()
            return JSONResponse(
                status_code=500,
                content={"detail": str(e)},
            )
        finally:
            db.close()

    @expose("/assignment-manager/save-subject", methods=["POST"])
    async def save_subject(self, request: Request):

        data = await request.json()
        teacher_id_str = data.get("teacher_id")
        subject = data.get("subject")
        class_id_strs = data.get("class_ids", [])
        if not subject or not subject.strip():
            return JSONResponse(
                status_code=400,
                content={"detail": "Fach fehlt"},
            )
        subject = subject.strip()
        try:
            teacher_id = uuid.UUID(teacher_id_str)
            class_ids = [uuid.UUID(cid) for cid in class_id_strs]
        except Exception:
            return JSONResponse(
                status_code=400,
                content={"detail": "Ungültige IDs"},
            )
        db = SessionLocal()
        try:
            teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
            if not teacher:
                return JSONResponse(
                    status_code=404,
                    content={"detail": "Lehrer nicht gefunden"},
                )
            assigned_school_ids = db.query(TeacherSchoolAssignment.school_id).filter(
                TeacherSchoolAssignment.teacher_id == teacher_id
            ).all()
            assigned_school_ids = [row[0] for row in assigned_school_ids]
            if not assigned_school_ids:
                return JSONResponse(
                    status_code=400,
                    content={"detail": "Der Lehrer ist keiner Schule zugewiesen"},
                )
            allowed_classes = db.query(SchoolClass).filter(
                SchoolClass.id.in_(class_ids),
                SchoolClass.school_id.in_(assigned_school_ids),
            ).all()
            allowed_class_ids = [c.id for c in allowed_classes]
            db.query(TeacherAssignment).filter(
                TeacherAssignment.teacher_id == teacher_id,
                TeacherAssignment.subject == subject,
            ).delete()
            created = []
            for class_id in allowed_class_ids:
                db.add(TeacherAssignment(
                    teacher_id=teacher_id,
                    class_id=class_id,
                    subject=subject,
                ))
                school_class = next((c for c in allowed_classes if c.id == class_id), None)
                if school_class:
                    school_name = school_class.school.name if school_class.school else "Unbekannt"
                    created.append(f"{school_name} - {school_class.name}")
            db.commit()
            skipped = len(class_ids) - len(allowed_class_ids)
            return {
                "message": f"{len(created)} Zuweisungen gespeichert",
                "classes": created,
                "skipped": skipped,
            }
        except Exception as e:
            db.rollback()
            return JSONResponse(
                status_code=500,
                content={"detail": str(e)},
            )
        finally:
            db.close()

    @expose("/assignment-manager/delete-subject", methods=["POST"])
    async def delete_subject(self, request: Request):
        data = await request.json()
        teacher_id_str = data.get("teacher_id")
        subject = data.get("subject")
        try:
            teacher_id = uuid.UUID(teacher_id_str)
        except Exception:
            return JSONResponse(
                status_code=400,
                content={"detail": "Ungültige teacher_id"},
            )
        db = SessionLocal()
        try:
            deleted = db.query(TeacherAssignment).filter(
                TeacherAssignment.teacher_id == teacher_id,
                TeacherAssignment.subject == subject,
            ).delete()
            db.commit()
            return {
                "message": f"{deleted} Zuweisungen gelöscht",
                "deleted": deleted,
            }
        except Exception as e:
            db.rollback()
            return JSONResponse(
                status_code=500,
                content={"detail": str(e)},
            )
        finally:
            db.close()