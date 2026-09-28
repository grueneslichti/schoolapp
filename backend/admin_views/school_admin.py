from fastapi import Request
from sqladmin import ModelView
from wtforms import FileField, SelectField
from core.storage import delete_image, save_image_bytes
from models import School, SchoolHoliday

class SchoolAdmin(ModelView, model=School):
    name = "Schule"
    name_plural = "Schulen"
    icon = "fa-solid fa-school"
    column_list = [
        School.id,
        School.name,
        School.country_code,
        School.setup_code,
        School.school_type,
        School.login_background_path
    ]   
    column_labels = {
        "id": "ID",
        "name": "Name",
        "country_code": "Land",
        "setup_code": "Setup-Code",
        "school_type": "Schultyp",
        "login_background_path": "Login-Hintergrund",
    }
    form_columns = [
        School.name,
        School.country_code,
        School.school_type,
        School.login_background_path
    ]
    form_widget_args = {
        "login_background_path": {
            "type": "textarea",
            "rows": 3,
        }
    }
    async def scaffold_form(self, *args, **kwargs):
        form_class = await super().scaffold_form(*args, **kwargs)
        form_class.school_type = SelectField(
            "Schultyp",
            choices=[
                ("primary", "primary"),
                ("secondary", "secondary"),
                ("high", "high"),
            ],
            default="primary",
        )
        form_class.login_background_file = FileField(
            "Login-Hintergrundbild der Schule",
        )
        return form_class
    async def on_model_change(self, data: dict, model: School, is_created: bool, request: Request) -> None:
        form_data = await request.form()
        uploaded_file = form_data.get("login_background_file")
        if uploaded_file is not None and hasattr(uploaded_file, "read"):
            file_content = await uploaded_file.read()
            if file_content:
                data["login_background_path"] = save_image_bytes(
                    file_content,
                    "school_backgrounds",
                )

        if data.get("login_background_path") is not None:
            if (
                not is_created
                and model.login_background_path
                and model.login_background_path != data["login_background_path"]
            ):
                delete_image(model.login_background_path)
            model.login_background_path = data["login_background_path"]

        await super().on_model_change(data, model, is_created, request)

class SchoolHolidayAdmin(ModelView, model=SchoolHoliday):
    name = "Ferien"
    name_plural = "Schulferien"
    icon = "fa-solid fa-umbrella-beach"
    column_list = [
        SchoolHoliday.school,
        SchoolHoliday.name,
        SchoolHoliday.start_date,
        SchoolHoliday.end_date
    ]
    column_labels = {
        SchoolHoliday.school: "Schule",
        SchoolHoliday.name: "Name",
        SchoolHoliday.start_date: "Von",
        SchoolHoliday.end_date: "Bis"
    }
    form_columns = [
        SchoolHoliday.school,
        SchoolHoliday.name,
        SchoolHoliday.start_date,
        SchoolHoliday.end_date
    ]
    column_sortable_list = [
        "start_date",
        "end_date",
        "name",
    ]
    column_default_sort = ("start_date", False)
    can_edit = True
    can_delete = True
    can_create = True