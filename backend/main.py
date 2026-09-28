import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(1, str(PROJECT_DIR))

from fastapi import FastAPI
import uuid
from pathlib import Path
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware
from starlette.requests import Request
from sqladmin import Admin, ModelView
from sqladmin.authentication import AuthenticationBackend
from routers import auth,teacher_messages,games,randomizer,graduation_photo,challenges,admin_assignments,promotion,mascot,assignment,shop ,avatars,schools,classes,tasks,users,admin as admin_router,friends,xp_transfer,grades,feedbacks,exams,focus,registration,schedule,lessons 
from core.database import engine
from models import SchoolClass,SchoolHoliday, Teacher, Student, Task, Grade, Feedback, Exam, InvitationCode, TeacherAssignment
from core.security.security import get_password_hash, generate_easy_password, generate_unique_login_name
from core.config import settings
from core.storage import get_image_path
from sqlalchemy.orm import Session as DBSession, defaultload, selectinload
from admin_views.assignment_manager import AssignmentManagerAdmin
from admin_views.school_admin import SchoolAdmin, SchoolHolidayAdmin
from admin_views.promotion_manager import PromotionManagerAdmin
from admin_views.import_manager import ImportManagerAdmin

app = FastAPI(
    title="Schulapp",
    description="Backend-Steuerung für die Schul-App",
    version="0.5.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(
    SessionMiddleware, 
    secret_key=settings.SECRET_KEY
)
uploads_dir = Path(__file__).parent / "uploads"
uploads_dir.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

class AdminAuth(AuthenticationBackend):
    async def login(self, request: Request) -> bool:
        form = await request.form()
        username = form.get("username")
        password = form.get("password") 
        if username and username.lower() == "admin" and password == settings.ADMIN_KEY:
            request.session.update({"admin": True})
            return True
        return False
    async def logout(self, request: Request) -> bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> bool:
        return request.session.get("admin", False)
authentication_backend = AdminAuth(secret_key=settings.SECRET_KEY)
admin_panel = Admin(app, engine, authentication_backend=authentication_backend)

class ClassAdmin(ModelView, model=SchoolClass):
    name = "Klasse"
    name_plural = "Klassen"
    icon = "fa-solid fa-users-line"
    column_list = [SchoolClass.id, SchoolClass.name, SchoolClass.level, SchoolClass.school]
    column_labels = {
        "name": "Klassenname",
        "level": "Stock / Stufe",
        "school": "Zugehörige Schule"
    }
    can_edit = True
    can_delete = True

class TeacherAdmin(ModelView, model=Teacher):
    name = "Lehrer"
    name_plural = "Lehrer"
    icon = "fa-solid fa-chalkboard-user"
    column_list = [Teacher.id, Teacher.full_name, Teacher.email, Teacher.school, Teacher.start_password]
    column_default_sort = ('start_password', True)
    column_labels = {
        "start_password": "Start-Passwort (Einmalig)"
    }
    form_excluded_columns = [Teacher.password_hash, Teacher.start_password, Teacher.must_change_password]
    can_edit = True
    can_delete = True
    async def on_model_change(self, data, model, is_created, request, *args, **kwargs):
        if is_created:
            if getattr(model, "class_id", None) and getattr(model,"real_name", None):
                with DBSession(engine) as session:
                    existing = session.query(Student).filter(
                        Student.class_id == model.class_id,
                        Student.real_name.ilike(model.real_name)                    
                    ).first()
                    if existing:
                        print("Name Existiert schon {model.real_name}")
            pwd = generate_easy_password()
            model.password_hash = get_password_hash(pwd)
            model.start_password = pwd
            model.must_change_password = True
        await super().on_model_change(data, model, is_created, request, *args, **kwargs)
class StudentAdmin(ModelView, model=Student):
    name = "Schüler"
    name_plural = "Schüler"
    icon = "fa-solid fa-user-graduate"
    column_list = [
        Student.id,
        Student.real_name,
        Student.pseudonym,
        "school_name",
        Student.school_class, Student.start_password]
    column_default_sort = ('start_password', True)
    column_labels = {
        Student.real_name: "Name des Schülers",
        Student.pseudonym: "Schüler-ID",
        "school_name": "Schule",
        Student.school_class: "Klasse",
        Student.xp: "XP",
        "start_password": "Start-Passwort"
    }
    column_formatters = {
        "school_name": lambda m, v: (
            m.school_class.school.name
            if m.school_class and m.school_class.school
            else "Unbekannt"
        )
    }
    def list_query(self, request: Request):
        query = super().list_query(request)
        return query.options(
            defaultload(Student.school_class).selectinload(SchoolClass.school)
        )
    form_excluded_columns = [
        Student.password_hash,
        Student.start_password,
        Student.must_change_password,
        Student.pseudonym
        ]
    column_default_sort = [('real_name', False)]
    page_size = 50
    can_edit = True
    can_delete = True
    can_create = True
    can_export = True

    async def on_model_change(self, data, model, is_created, request, *args, **kwargs):
        if is_created:
            new_pseudonym = None
            if getattr(model, "class_id", None):
                with DBSession(engine) as session:
                    school_class = session.query(SchoolClass).filter(SchoolClass.id == model.class_id).first()
                    if school_class:
                        student_count = session.query(Student).filter(
                            Student.class_id == model.class_id
                        ).count()
                        new_pseudonym = f"{school_class.name}_{str(student_count + 1).zfill(3)}"
                        while session.query(Student).filter(Student.pseudonym == new_pseudonym).first():
                            student_count += 1
                            new_pseudonym = f"{school_class.name}_{str(student_count + 1).zfill(3)}"
            if not new_pseudonym:
                base = (getattr(model, "real_name", None) or "user").replace(" ", "_")
                new_pseudonym = f"{base}_{str(uuid.uuid4())[:8]}"
            model.pseudonym = new_pseudonym
            with DBSession(engine) as session:
                model.login_name = generate_unique_login_name(session, model.real_name)
            pwd = generate_easy_password()
            model.password_hash = get_password_hash(pwd)
            model.start_password = pwd
            model.must_change_password = True
        await super().on_model_change(data, model, is_created, request, *args, **kwargs,)

class GradeAdmin(ModelView, model=Grade):
    name = "Note"
    name_plural = "Noten"
    icon = "fa-solid fa-star-half-stroke" 
    column_list = [Grade.student, Grade.teacher, Grade.subject, Grade.value, Grade.created_at]
    column_labels = {
        "student": "Schüler",
        "teacher": "Lehrer ",
        "subject": "Fach",
        "value": "Note ",
        "created_at": "Eingetragen am"
    }
    form_excluded_columns = [Grade.class_id] 
    can_edit = True
    can_delete = True

class FeedbackAdmin(ModelView, model=Feedback):
    name = "Kummerkasten"
    name_plural = "Kummerkasten"
    icon = "fa-solid fa-envelope-open-text"
    column_list = [
        Feedback.school_class,
        Feedback.category,
        Feedback.message,
        Feedback.is_read,
        Feedback.created_at
        ]    
    column_labels = {
        "school_class": "Klasse",
        "category": "Kategorie",
        "message": "Nachricht",
        "is_read": "Gelesen?",
        "created_at": "Eingegangen am"
    }
    form_excluded_columns = [Feedback.student_hash]
    can_edit = True
    can_delete = True

class InvitationCodeAdmin(ModelView, model=InvitationCode):
    name = "Einladungscode"
    name_plural = "Einladungscodes"
    icon = "fa-solid fa-ticket"
    column_list = [
        InvitationCode.code,
        InvitationCode.school_class,
        InvitationCode.is_active,
        InvitationCode.times_used,
        InvitationCode.max_uses,
        InvitationCode.expires_at,
        InvitationCode.created_at
    ]
    column_labels = {
        "code": "Code",
        "school_class": "Klasse",
        "is_active": "Aktiv",
        "times_used": "Verwendet",
        "max_uses": "Max. Nutzungen",
        "expires_at": "Läuft ab am",
        "created_at": "Erstellt am"
    }
    can_edit = True
    can_delete = True
    async def on_model_change(self, data, model, is_created, request, *args, **kwargs):
        if model.code:
            model.code = model.code.strip().upper()
        await super().on_model_change(data, model, is_created, request, *args, **kwargs)
admin_panel.add_view(InvitationCodeAdmin)

class ExamAdmin(ModelView, model=Exam):
    name = "Prüfung"
    name_plural = "Prüfungen"
    icon = "fa-solid fa-clipboard-check"
    column_list = [Exam.school_class, Exam.teacher, Exam.subject, Exam.exam_date, Exam.description]
    column_labels = {
        "school_class": "Klasse",
        "teacher": "Lehrer",
        "subject": "Fach",
        "exam_date": "Datum",
        "description": "Beschreibung"
    }
    form_columns = ["class_id", "teacher_id", "subject", "exam_date", "description"]
    can_edit = True
    can_delete = True    

    async def on_model_change(self, data, model, is_created, request, *args, **kwargs):
        if is_created:
            if getattr(model, "student_id", None):
                with DBSession(engine) as session:
                    student = session.query(Student).filter(Student.id == model.student_id).first()
                    if student:
                        model.class_id = student.class_id               
        await super().on_model_change(data, model, is_created, request, *args, **kwargs)

class TaskAdmin(ModelView, model=Task):
    name = "Aufgabe"
    name_plural = "Aufgaben"
    icon = "fa-solid fa-list-check"
    column_list = [Task.id, Task.subject, Task.title, Task.due_date, Task.school_class]
    can_edit = True
    can_delete = True

class TeacherAssignmentAdmin(ModelView, model=TeacherAssignment):
    name = "Lehrer-Zuweisung"
    name_plural = "Lehrer-Zuweisungen"
    icon = "fa-solid fa-chalkboard-teacher"
    column_list = [
        TeacherAssignment.teacher,
        TeacherAssignment.school_class,
        TeacherAssignment.subject,
        TeacherAssignment.created_at
    ]
    column_labels = {
        "teacher": "Lehrer",
        "school_class": "Klasse",
        "subject": "Fach",
        "created_at": "Zugewiesen am"
    }
    can_edit = True
    can_delete = True

admin_panel.add_view(SchoolAdmin)
admin_panel.add_view(ClassAdmin)
admin_panel.add_view(TeacherAdmin)
admin_panel.add_view(StudentAdmin)
admin_panel.add_view(TaskAdmin)
admin_panel.add_view(GradeAdmin)
admin_panel.add_view(FeedbackAdmin)
admin_panel.add_view(ExamAdmin)
admin_panel.add_view(TeacherAssignmentAdmin)
admin_panel.add_view(AssignmentManagerAdmin)
admin_panel.add_view(PromotionManagerAdmin)
admin_panel.add_view(SchoolHolidayAdmin)
admin_panel.add_view(ImportManagerAdmin)

app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(schools.router, prefix="/api/v1")
app.include_router(classes.router, prefix="/api/v1")
app.include_router(classes.api_router, prefix="/api/v1")
app.include_router(tasks.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(admin_router.router, prefix="/api/v1")
app.include_router(friends.router, prefix="/api/v1")
app.include_router(xp_transfer.router, prefix="/api/v1")
app.include_router(grades.router, prefix="/api/v1")
app.include_router(feedbacks.router, prefix="/api/v1")
app.include_router(exams.router, prefix="/api/v1")
app.include_router(focus.router, prefix= "/api/v1")
app.include_router(registration.router, prefix= "/api/v1")
app.include_router(schedule.router, prefix= "/api/v1")
app.include_router(lessons.router, prefix= "/api/v1")
app.include_router(avatars.router, prefix="/api/v1")
app.include_router(shop.router, prefix="/api/v1")
app.include_router(assignment.router, prefix="/api/v1")
app.include_router(admin_assignments.router, prefix="/api/v1")
app.include_router(mascot.router, prefix="/api/v1")
app.include_router(promotion.router, prefix= "/api/v1")
app.include_router(challenges.router, prefix="/api/v1")
app.include_router(games.router, prefix="/api/v1")
app.include_router(graduation_photo.router, prefix="/api/v1")
app.include_router(randomizer.router, prefix="/api/v1")
app.include_router(teacher_messages.router, prefix="/api/v1")

@app.get("/", tags=["Root"])
def read_root():
    return {
        "status": "online",
        "message": "Schulapp läuft.",
        "version": "0.1.0"
    }

@app.get("/api/v1/config/ui-context", tags=["Configuration"])
def get_ui_context():
    return {
        "available_themes": ["primary", "secondary", "high"],
        "mascot_enabled": True,
        "focus_mode_default": False,
        "message": "Die App passt ihr Design basierend auf dem 'class_level' des Users an."
    }