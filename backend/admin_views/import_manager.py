from sqladmin import BaseView, expose
from fastapi import Request
from core.database import SessionLocal
from models import School, SchoolClass

class ImportManagerAdmin(BaseView):
    name = "Daten-Import"
    icon = "fa-solid fa-file-import"

    @expose("/import-manager", methods=["GET"])
    async def import_page(self, request: Request):
        """Zeigt die Import-Seite."""
        db = SessionLocal()
        try:
            school_count = db.query(School).count()
            class_count = db.query(SchoolClass).count()
            return await self.templates.TemplateResponse(
                request=request,
                name="import_manager.html",
                context={
                    "school_count": school_count,
                    "class_count": class_count
                }
            )
        finally:
            db.close()