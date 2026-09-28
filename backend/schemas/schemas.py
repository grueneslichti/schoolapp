from pydantic import BaseModel, ConfigDict, field_validator
from typing import Optional
from datetime import datetime,date
import uuid

class SchoolCreate(BaseModel):
    name: str
    country_code: str

class SchoolResponse(SchoolCreate):
    id: uuid.UUID
    model_config = ConfigDict(from_attributes=True)

class ClassCreate(BaseModel):
    name: str
    level: str

class ClassResponse(ClassCreate):
    id: uuid.UUID
    school_id: uuid.UUID
    model_config = ConfigDict(from_attributes=True)

class TaskCreate(BaseModel):
    class_id: uuid.UUID
    subject: str
    title: str
    description: Optional[str] = None
    due_date: str
    @field_validator("title")
    @classmethod
    def validate_title(cls, v):
        if len(v.strip()) < 3:
            raise ValueError("Titel muss mindestens 3 Zeichen haben")
        return v.strip()
    @field_validator("subject")
    @classmethod
    def validate_subject(cls, v):
        if len(v.strip()) < 2:
            raise ValueError("Fach muss mindestens 2 Zeichen haben")
        return v.strip()

class TaskResponse(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    class_name: str
    subject: str
    title: str
    description: Optional[str] = None
    due_date: datetime
    created_at: datetime
    is_overdue: bool = False
    is_completed: bool = False
    model_config = ConfigDict(from_attributes=True)

class FeedbackCreate(BaseModel):
    category:Optional[str] = None
    message: str
    is_anonymous: bool = True
    @field_validator("message")
    @classmethod
    def validate_message(cls, v):
        if len(v.strip()) < 5:
            raise ValueError("Die Nachricht muss mindestens 5 Zeichen enthalten")
        if len(v) > 1500:
            raise ValueError ("Zuviele Zeichen, kürze bitte die Nachricht")
        return v.strip()

class FeedbackStudentResponse(BaseModel):
    id: uuid.UUID
    category: Optional[str] = None
    message: str
    is_anonymous: bool = True
    created_at: datetime
    model_config = ConfigDict (from_attributes=True)

class FeedbackTeacherResponse(BaseModel):
    id: uuid.UUID
    class_name: str
    category:Optional[str] = None
    message: str
    is_anonymous: bool = True
    created_at: datetime
    is_read: bool
    model_config = ConfigDict(from_attributes=True)

class FocusSessionCreate(BaseModel):
    planned_minutes: int
    actual_minutes: int
    completed: bool = False
    @field_validator("planned_minutes")
    @classmethod
    def validate_planned(cls, v):
        if v not in [15, 30, 45]:
            raise ValueError("Geplante Dauer muss 15/30 oder 45 Minuten sein")
        return v
    @field_validator("actual_minutes")
    @classmethod
    def validate_actual(cls, v):
        if v < 0:
            raise ValueError("Tatsächliche Dauer darf nicht negativ sein")
        return v

class FocusSessionResponse(BaseModel):
    id: uuid.UUID
    planned_minutes: int
    actual_minutes: int
    xp_earned: int
    completed: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class FocusCompleteResponse(BaseModel):
    xp_earned: int
    total_xp: int
    message: str

class XPGiftCreate(BaseModel):
    receiver_id: uuid.UUID
    amount: int
    message: Optional[str] = None
    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v):
        if v < 1:
            raise ValueError("XP-Betrag muss mindestens 1 sein")
        if v > 10:
            raise ValueError("XP-Betrag darf maximal 10 sein")
        return v
    @field_validator("message")
    @classmethod
    def validate_message(cls, v):
        if v and len(v) > 200:
            raise ValueError("Nachricht zu lange, bitte kürzen (200 zeichen)")
        return v

class XPGiftResponse(BaseModel):
    id: uuid.UUID
    sender_id: uuid.UUID
    receiver_id: uuid.UUID
    amount: int
    message: Optional[str] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class FriendResponse(BaseModel):
    id: uuid.UUID
    pseudonym: str
    real_name: str
    class_name: str
    xp: int
    model_config = ConfigDict(from_attributes=True)

class XPGiftResult(BaseModel):
    success: bool
    message: str
    remaining_weekly_xp: int
    total_xp_receiver: Optional[int] = None

class ScheduleEntryCreate(BaseModel):
    class_id: Optional[uuid.UUID] = None
    subject: str
    day_of_week: int
    start_time: str
    end_time: str
    room: Optional[str] = None
    @field_validator("day_of_week")
    @classmethod
    def validate_day(cls, v):
        if v < 0 or v > 6:
            raise ValueError("Tag muss zwischen Montag und Sonntag liegen")
        return v
    @field_validator("subject")
    @classmethod
    def validate_subject(cls, v):
        if len(v.strip()) < 2:
            raise ValueError("Fach muss mindestens 2 Zeichen haben")
        return v.strip()

class ScheduleEntryResponse(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    subject: str
    day_of_week: int
    start_time: str
    end_time: str
    room: Optional[str] = None
    created_by_role: str
    is_editable: bool
    model_config = ConfigDict(from_attributes=True)

class AvatarUpload(BaseModel):
    image_base64: str
    apply_anime_style: bool = False

class AvatarRegenerate(BaseModel):
    prompt_suffix: Optional[str] = None

class AvatarResponse(BaseModel):
    has_original: bool
    has_anime: bool
    active_version: str
    image_base64: Optional[str] = None
    updated_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)

class ShopItemResponse(BaseModel):
    id: uuid.UUID
    name: str
    icon: str
    item_type: str
    cost_xp: int
    rarity: str
    available_colors: list[str]
    model_config = ConfigDict(from_attributes=True)

class BuyItemRequest(BaseModel):
    shop_item_id: uuid.UUID
    color: str

class BuyItemResponse(BaseModel):
    success: bool
    message: str
    avatar_item_id: Optional[uuid.UUID] = None
    remaining_xp: int = 0

class AvatarItemResponse(BaseModel):
    id: uuid.UUID
    shop_item_id: uuid.UUID
    name: str
    icon: str
    item_type: str
    color: str
    rarity: str
    pos_x: float
    pos_y: float
    scale: float
    is_equipped: bool
    model_config = ConfigDict(from_attributes=True)

class UpdatePositionRequest(BaseModel):
    pos_x: float
    pos_y: float
    scale: float

class SchoolSetupRequest(BaseModel):
    setup_code: str

class SchoolSetupResponse(BaseModel):
    school_id: uuid.UUID
    school_name: str
    has_background: bool
    model_config = ConfigDict(from_attributes=True)

class SchoolBackgroundResponse(BaseModel):
    background_image: str | None
    model_config = ConfigDict(from_attributes=True)

class PromoteStudentRequest(BaseModel):
    student_id: uuid.UUID
    new_class_id: uuid.UUID

class BulkPromoteRequest(BaseModel):
    from_class_id: uuid.UUID
    to_class_id: uuid.UUID
    only_older_than_days: Optional[int] = None

class TransferStudentRequest(BaseModel):
    student_id: uuid.UUID
    new_class_id: uuid.UUID
    transfer_type: str = "school_transfer"

class GraduateStudentRequest(BaseModel):
    student_id: uuid.UUID
    keep_profile: bool = False

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    school_id: uuid.UUID
    school_name: str
    school_type: str = "primary"
    must_change_password: bool = False
    pseudonym: str | None = None
    real_name: str | None = None
    full_name: str | None = None

class ChallengeResponse(BaseModel):
    id: uuid.UUID
    challenge_type: str
    title: str
    description: str
    xp_reward: int
    is_completed: bool
    completed_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)

class QuizQuestionResponse(BaseModel):
    id: uuid.UUID
    question: str
    answer_a: str
    answer_b: str
    answer_c: str
    answer_d: str
    model_config = ConfigDict(from_attributes=True)

class SubmitAnswerRequest(BaseModel):
    challenge_id: uuid.UUID
    question_id: uuid.UUID
    answer: str

class ChallengeStatusResponse(BaseModel):
    is_school_time: bool
    can_play: bool
    message: str
    daily_xp_limit: int = 100
    daily_xp_earned: int = 0
    daily_xp_remaining: int = 100
from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional
import uuid

class SubmitScoreRequest(BaseModel):
    game_type: str
    difficulty: str
    score: int

class SubmitScoreResponse(BaseModel):
    success: bool
    xp_earned: int
    total_xp: int
    is_new_class_record: bool = False
    class_rank: Optional[int] = None

class HighscoreEntry(BaseModel):
    rank: int
    student_name: str
    pseudonym: str | None = None
    score: int
    difficulty: str
    created_at: datetime
    is_me: bool = False

class ClassHighscoresResponse(BaseModel):
    game_type: str
    difficulty: str
    top_scores: list[HighscoreEntry]
    my_best_score: Optional[int] = None
    my_rank: Optional[int] = None
    total_players: int = 0

class TeacherMessageCreate(BaseModel):
    receiver_id: uuid.UUID
    subject: Optional[str] = None
    message: str

class TeacherMessageResponse(BaseModel):
    id: uuid.UUID
    sender_id: uuid.UUID
    sender_name: str
    receiver_id: uuid.UUID
    receiver_name: str
    subject: Optional[str] = None
    message: str
    is_read: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class TeacherContact(BaseModel):
    id: uuid.UUID
    name: str
    email: Optional[str] = None
    school_name: Optional[str] = None

class SchoolUpdate(BaseModel):
    name: Optional[str] = None
    country_code: Optional[str] = None

class ClassUpdate(BaseModel):
    name: Optional[str] = None
    level: Optional[str] = None

class TeacherUpdate(BaseModel):
    email: Optional[str] = None
    full_name: Optional[str] = None

class StudentUpdate(BaseModel):
    class_id: Optional[uuid.UUID] = None

class ExamCreate(BaseModel):
    class_id: uuid.UUID
    subject: str
    exam_date: date
    description: Optional[str] = None
    title: Optional[str] = None

class ExamResponse(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    class_name: str
    teacher_id: uuid.UUID
    title: str = "Prüfung"
    subject: str
    exam_date: date
    created_at: Optional[datetime] = None
    description: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class ConflictCheckResponse(BaseModel):
    has_conflict: bool
    conflicting_exams: list[ExamResponse] = []
    message: Optional[str] = None

class TeacherCreate(BaseModel):
    email: str
    full_name: str
    school_id: uuid.UUID
    initial_password: Optional[str] = None

class TeacherResponse(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str
    school_id: uuid.UUID
    initial_password: str
    model_config = ConfigDict(from_attributes=True)

# --- SCHÜLER ---
class StudentCreate(BaseModel):
    class_id: uuid.UUID
    real_name: str
    initial_password: Optional[str] = None

class StudentResponse(BaseModel):
    id: uuid.UUID
    pseudonym: str
    class_id: uuid.UUID
    initial_password: str
    model_config = ConfigDict(from_attributes=True)

class GradeCreate(BaseModel):
    student_id: uuid.UUID
    subject: str
    value: int
    description: Optional[str] = None
    @field_validator("value")
    @classmethod
    def validate_grade(cls, v):
        if v < 1 or v > 6:
            raise ValueError("Noten gehen von 1 bis 6")
        return v

class GradeResponse(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID
    teacher_id: uuid.UUID
    subject: str
    value: int
    description: Optional[str] = None
    date: datetime
    model_config = ConfigDict(from_attributes=True)

class ClassGradesResponse(BaseModel):
    student_id: uuid.UUID
    real_name: str
    pseudonym: str
    grades: list[GradeResponse]
    average: float

class LessonSignalCreate(BaseModel):
    class_id: uuid.UUID
    subject: str
    window_minutes: int = 7

    @field_validator("subject")
    @classmethod
    def validate_subject(cls, v):
        if len(v.strip()) < 2:
            raise ValueError("Fach muss mindestens 2 Zeichen haben")
        return v.strip()

class LessonSignalResponse(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    subject: str
    signal_time: datetime
    window_minutes: int
    is_active: bool
    model_config = ConfigDict(from_attributes=True)

class LessonRatingCreate(BaseModel):
    signal_id: uuid.UUID
    rating: Optional[int] = None
    is_neutral: bool = False
    comment: Optional[str] = None

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v, info):
        if not info.data.get('is_neutral', False):
            if v is None:
                raise ValueError("Bewertung ist erforderlich")
            if v < 1 or v > 5:
                raise ValueError("Bewertung muss zwischen 1 und 5 sein")
        return v

class LessonRatingResponse(BaseModel):
    id: uuid.UUID
    rating: Optional[int] = None
    is_neutral: bool = False
    comment: Optional[str] = None
    created_at: datetime
    xp_earned: int = 0
    model_config = ConfigDict(from_attributes=True)

class ActiveSignalResponse(BaseModel):
    has_active_signal: bool
    signal_id: Optional[str] = None
    subject: Optional[str] = None
    time_remaining_seconds: Optional[int] = None

class RatingSummary(BaseModel):
    signal_id: str
    subject: str
    signal_time: datetime
    total_ratings: int
    average_rating: float
    neutral_count: int = 0
    ratings: list[LessonRatingResponse]

class InvitationCodeCreate(BaseModel):
    class_id: uuid.UUID
    code: str
    max_uses: Optional[int] = None
    expires_in_days: Optional[int] = 7

    @field_validator("code")
    @classmethod
    def validate_code(cls, v):
        v = v.strip().upper()
        if len(v) < 4:
            raise ValueError("Code muss mindestens 4 Zeichen lang sein")
        if len(v) > 50:
            raise ValueError("Code darf maximal 50 Zeichen lang sein")
        import re
        if not re.match(r'^[A-Z0-9\-]+$', v):
            raise ValueError("Code darf nur Großbuchstaben, Zahlen und Bindestriche enthalten")
        return v

class InvitationCodeResponse(BaseModel):
    id: uuid.UUID
    code: str
    class_name: str
    is_active: bool
    times_used: int
    max_uses: Optional[int] = None
    expires_at: Optional[datetime] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class StudentRegistrationRequest(BaseModel):
    real_name: str
    invitation_code: str

    @field_validator("real_name")
    @classmethod
    def validate_name(cls, v):
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Name muss mindestens 2 Zeichen lang sein")
        if len(v) > 50:
            raise ValueError("Name darf maximal 50 Zeichen lang sein")
        return v

    @field_validator("invitation_code")
    @classmethod
    def validate_code(cls, v):
        return v.strip().upper()

class StudentRegistrationResponse(BaseModel):
    student_id: uuid.UUID
    pseudonym: str
    real_name: str
    class_name: str
    start_password: str
    message: str