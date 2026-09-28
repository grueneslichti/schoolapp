import uuid
import datetime
import secrets
from sqlalchemy import String, Integer, Boolean, DateTime, ForeignKey, Text, Time, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
import datetime

class Base(DeclarativeBase):
    pass

def get_utc_now():
    return datetime.datetime.now(datetime.timezone.utc)

class School(Base):
    __tablename__ = "schools"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100))
    country_code: Mapped[str] = mapped_column(String(2))
    school_type: Mapped[str] = mapped_column(String(20), default="primary")
    classes: Mapped[list["SchoolClass"]] = relationship(back_populates="school", cascade="all, delete-orphan")
    teachers: Mapped[list["Teacher"]] = relationship(back_populates="school", cascade="all, delete-orphan")
    login_background_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    setup_code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        default=lambda: f"SCHULE-{secrets.token_hex(6).upper()}",
    )

    def __str__(self):
        return self.name

class SchoolClass(Base):
    __tablename__ = "classes"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"))
    name: Mapped[str] = mapped_column(String(20))
    level: Mapped[str] = mapped_column(String(20))
    school: Mapped["School"] = relationship(back_populates="classes")
    students: Mapped[list["Student"]] = relationship(back_populates="school_class", cascade="all, delete-orphan")
    tasks: Mapped[list["Task"]] = relationship(back_populates="school_class", cascade="all, delete-orphan")
    
    def __str__(self):
        try:
            school_name = self.school.name if self.school else "Unbekannt"
            return f"{self.name} ({school_name})"
        except Exception:
            return self.name or "Klasse"
    
class Teacher(Base):
    __tablename__ = "teachers"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"))
    email: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(100))
    start_password: Mapped[str | None] = mapped_column(String(20), nullable=True)
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=True, server_default='1')
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    school: Mapped["School"] = relationship(back_populates="teachers")
    
    def __str__(self):
        try:
            school_name = self.school.name if self.school else ""
            return f"{self.full_name} ({school_name})" if school_name else self.full_name
        except Exception:
            return self.full_name

class Student(Base):
    __tablename__ = "students"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    real_name: Mapped[str] = mapped_column(String(100))
    pseudonym: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    start_password: Mapped[str | None] = mapped_column(String(20), nullable=True)
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=True, server_default="1")
    school_class: Mapped["SchoolClass"] = relationship(back_populates="students")
    avatar: Mapped["Avatar"] = relationship(back_populates="student", uselist=False, cascade="all, delete-orphan")
    items: Mapped[list["AvatarItem"]] = relationship(back_populates="student", cascade="all, delete-orphan")
    performance: Mapped["Performance"] = relationship(back_populates="student", uselist=False, cascade="all, delete-orphan")
    xp: Mapped[int] = mapped_column(Integer, default=0)
    function_points: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_xp_notification_seen: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    pending_graduation_photo: Mapped[bool] = mapped_column(Boolean, default=False)
    graduation_classmate_ids: Mapped[str | None] = mapped_column(Text, nullable=True)
    graduation_class_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    graduation_photo_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    login_name: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    
    def __str__(self):
        try:
            class_name = self.school_class.name if self.school_class else ""
            return f"{self.real_name} ({class_name})" if class_name else self.real_name
        except Exception:
            return self.real_name

class Task(Base):
    __tablename__ = "tasks"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    subject: Mapped[str] = mapped_column(String(50))
    title: Mapped[str] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    due_date: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime.datetime] = mapped_column(default=get_utc_now)
    school_class: Mapped["SchoolClass"] = relationship(back_populates="tasks")

class TaskCompletion(Base):
    __tablename__ = "task_completions"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    task_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tasks.id"))
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    completed_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    task = relationship("Task", backref="completions")
    student = relationship("Student")

class Avatar(Base):
    __tablename__ = "avatars"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"), unique=True)
    active_version: Mapped[str] = mapped_column(String(10), default="anime")
    updated_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now, onupdate=get_utc_now)
    student = relationship("Student", back_populates="avatar")
    original_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    anime_path: Mapped[str | None] = mapped_column(String(255), nullable=True)

class AvatarItem(Base):
    __tablename__ = "avatar_items"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    shop_item_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("shop_items.id"))
    color: Mapped[str] = mapped_column(String(7), default="#333333")
    pos_x: Mapped[float] = mapped_column(default=0.5)
    pos_y: Mapped[float] = mapped_column(default=0.3)
    scale: Mapped[float] = mapped_column(default=1.0)
    is_equipped: Mapped[bool] = mapped_column(Boolean, default=False)
    unlocked_at: Mapped[datetime.datetime] = mapped_column(default=get_utc_now)
    student: Mapped["Student"] = relationship(back_populates="items")
    shop_item: Mapped["ShopItem"] = relationship()

class Rating(Base):
    __tablename__ = "ratings"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"))
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    reporter_pseudonym: Mapped[str | None] = mapped_column(String(64), nullable=True)
    score: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=get_utc_now)

class Performance(Base):
    __tablename__ = "performance"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"), unique=True)
    xp: Mapped[int] = mapped_column(default=0)
    level: Mapped[int] = mapped_column(default=1)
    streak_days: Mapped[int] = mapped_column(default=0)
    student: Mapped["Student"] = relationship(back_populates="performance")

class Grade(Base):
    __tablename__ = "grades"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    teacher_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("teachers.id"))
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    subject: Mapped[str] = mapped_column(String(50))
    value: Mapped[int] = mapped_column(Integer)
    description: Mapped[str | None] = mapped_column(String(200), nullable=True)
    date: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    created_at: Mapped[datetime.datetime] = mapped_column(default=get_utc_now)
    student = relationship("Student", backref="grades")
    teacher = relationship("Teacher")
    school_class = relationship("SchoolClass")

class FriendRequest(Base):
    __tablename__ = "friend_requests"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    receiver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    sender = relationship("Student", foreign_keys=[sender_id], backref="sent_requests")
    receiver = relationship("Student", foreign_keys=[receiver_id], backref="received_requests")

class Friendship(Base):
    __tablename__ = "friendships"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id_1: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    student_id_2: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    nickname: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=get_utc_now)

class XPTransfer(Base):
    __tablename__ = "xp_transfers"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    receiver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    amount: Mapped[int] = mapped_column(Integer)
    reason: Mapped[str] = mapped_column(String(200))
    created_at: Mapped[datetime.datetime] = mapped_column(default=get_utc_now)

class ShopItem(Base):
    __tablename__ = "shop_items"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100))
    icon: Mapped[str] = mapped_column(String(10))
    item_type: Mapped[str] = mapped_column(String(50))
    cost_xp: Mapped[int] = mapped_column(Integer)
    rarity: Mapped[str] = mapped_column(String(20), default="common")
    is_fixed: Mapped[bool] = mapped_column(Boolean, default=False)
    available_colors: Mapped[str] = mapped_column(Text, default='["#333333"]')
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Exam(Base):
    __tablename__ = "exams"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    teacher_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("teachers.id"))
    subject: Mapped[str] = mapped_column(String(50))
    exam_date: Mapped[datetime.date] = mapped_column()
    description: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    school_class = relationship("SchoolClass")
    teacher = relationship("Teacher")

class Feedback(Base):
    __tablename__ = "feedbacks"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_hash: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    is_anonymous: Mapped[bool] = mapped_column(Boolean, default=True)
    student_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    message: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    school_class = relationship("SchoolClass")

class FocusSession(Base):
    __tablename__ = "focus_sessions"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    planned_minutes: Mapped[int] = mapped_column(Integer)
    actual_minutes: Mapped[int] = mapped_column(Integer)
    xp_earned: Mapped[int] = mapped_column(Integer, default=0)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    student = relationship("Student")

class XPGift(Base):
    __tablename__ = "xp_gifts"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    receiver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    amount: Mapped[int] = mapped_column(Integer)
    message: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    sender = relationship("Student", foreign_keys=[sender_id], backref="sent_gifts")
    receiver = relationship("Student", foreign_keys=[receiver_id], backref="received_gifts")

class InvitationCode(Base):
    __tablename__ = "invitation_codes"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    created_by_teacher_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("teachers.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    expires_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    times_used: Mapped[int] = mapped_column(Integer, default=0)
    max_uses: Mapped[int | None] = mapped_column(Integer, nullable=True)
    school_class = relationship("SchoolClass")
    created_by_teacher = relationship("Teacher")

class ScheduleEntry(Base):
    __tablename__ = "schedule_entries"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    subject: Mapped[str] = mapped_column(String(50))
    day_of_week: Mapped[int] = mapped_column(Integer)
    start_time: Mapped[datetime.time] = mapped_column(Time)
    end_time: Mapped[datetime.time] = mapped_column(Time)
    room: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_by_role: Mapped[str] = mapped_column(String(10))
    created_by_id: Mapped[uuid.UUID] = mapped_column()
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    school_class = relationship("SchoolClass")

class LessonRating(Base):
    __tablename__ = "lesson_ratings"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    signal_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lesson_signals.id"))
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_neutral: Mapped[bool] = mapped_column(Boolean, default=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    signal = relationship("LessonSignal", back_populates="ratings")
    student = relationship("Student")

class LessonSignal(Base):
    __tablename__ = "lesson_signals"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    teacher_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("teachers.id"))
    subject: Mapped[str] = mapped_column(String(50))
    signal_time: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    window_minutes: Mapped[int] = mapped_column(Integer, default=7)
    school_class = relationship("SchoolClass")
    teacher = relationship("Teacher")
    ratings = relationship("LessonRating", back_populates="signal")

class TeacherAssignment(Base):
    __tablename__ = "teacher_assignments"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    teacher_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("teachers.id"))
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    subject: Mapped[str] = mapped_column(String(50))  # Fach das der Lehrer unterrichtet
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    teacher = relationship("Teacher", backref="assignments")
    school_class = relationship("SchoolClass", backref="teacher_assignments")

class TeacherSchoolAssignment(Base):
    __tablename__ = "teacher_school_assignments"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teachers.id", ondelete="CASCADE"),
        index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"),
        index=True
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_utc_now
    )
    teacher = relationship("Teacher", backref="school_assignments")
    school = relationship("School")
    __table_args__ = (
        UniqueConstraint("teacher_id", "school_id", name="uq_teacher_school_assignment"),
    )
    def __str__(self):
        try:
            return f"{self.teacher.full_name} → {self.school.name}"
        except Exception:
            return "Lehrer-Schul-Zuweisung"

class PromotionHistory(Base):
    __tablename__ = "promotion_history"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    from_class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    to_class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    transfer_type: Mapped[str] = mapped_column(String(20), default="class_transfer")
    from_school_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("schools.id"), nullable=True)
    to_school_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("schools.id"), nullable=True)
    promoted_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    promoted_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    student: Mapped["Student"] = relationship(backref="promotion_history")
    from_class: Mapped["SchoolClass"] = relationship(foreign_keys=[from_class_id])
    to_class: Mapped["SchoolClass"] = relationship(foreign_keys=[to_class_id])

class DailyChallenge(Base):
    __tablename__ = "daily_challenges"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    challenge_type: Mapped[str] = mapped_column(String(50))
    challenge_date: Mapped[datetime.date] = mapped_column()
    title: Mapped[str] = mapped_column(String(100))
    description: Mapped[str] = mapped_column(String(200))
    xp_reward: Mapped[int] = mapped_column(Integer, default=10)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    completed_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    student: Mapped["Student"] = relationship(backref="daily_challenges")

class QuizQuestion(Base):
    __tablename__ = "quiz_questions"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    school_type: Mapped[str] = mapped_column(String(20))
    subject: Mapped[str] = mapped_column(String(50))
    question: Mapped[str] = mapped_column(Text)
    answer_a: Mapped[str] = mapped_column(String(200))
    answer_b: Mapped[str] = mapped_column(String(200))
    answer_c: Mapped[str] = mapped_column(String(200))
    answer_d: Mapped[str] = mapped_column(String(200))
    correct_answer: Mapped[str] = mapped_column(String(1))
    difficulty: Mapped[int] = mapped_column(Integer, default=1)

class ChallengeAttempt(Base):
    __tablename__ = "challenge_attempts"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    challenge_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("daily_challenges.id"))
    question_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quiz_questions.id"))
    student_answer: Mapped[str] = mapped_column(String(1))
    is_correct: Mapped[bool] = mapped_column(Boolean)
    answered_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)

class SchoolHoliday(Base):
    __tablename__ = "school_holidays"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"))
    name: Mapped[str] = mapped_column(String(100))
    start_date: Mapped[datetime.date] = mapped_column()
    end_date: Mapped[datetime.date] = mapped_column()
    school: Mapped["School"] = relationship(backref="holidays")
    def __str__(self):
        return f"{self.name} ({self.start_date} - {self.end_date})"

class FunctionTask(Base):
    __tablename__ = "function_tasks"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    difficulty: Mapped[str] = mapped_column(String(20))
    task_type: Mapped[str] = mapped_column(String(50))
    question: Mapped[str] = mapped_column(Text)
    correct_answer: Mapped[str] = mapped_column(String(50))
    is_correct: Mapped[bool] = mapped_column(Boolean, nullable=True)
    xp_earned: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    student: Mapped["Student"] = relationship(backref="function_tasks")

class GameHighscore(Base):
    __tablename__ = "game_highscores"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"))
    game_type: Mapped[str] = mapped_column(String(50))
    difficulty: Mapped[str] = mapped_column(String(20))
    score: Mapped[int] = mapped_column(Integer, default=0)
    xp_earned: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    student: Mapped["Student"] = relationship(backref="game_highscores")
    school_class: Mapped["SchoolClass"] = relationship(backref="game_highscores")

class GameUnlock(Base):
    __tablename__ = "Spiel_freischalten"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    game_type: Mapped[str] = mapped_column(String(50))
    is_unlocked: Mapped[bool] = mapped_column(Boolean, default=False)
    trial_started_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    unlocked_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    student: Mapped["Student"] = relationship(backref="Spiel_freischalten")

class TeacherMessage(Base):
    __tablename__ = "teacher_messages"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("teachers.id"))
    receiver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("teachers.id"))
    subject: Mapped[str | None] = mapped_column(String(150), nullable=True)
    message: Mapped[str] = mapped_column(Text)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_by_sender: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_by_receiver: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), default=get_utc_now)
    sender: Mapped["Teacher"] = relationship(foreign_keys=[sender_id])
    receiver: Mapped["Teacher"] = relationship(foreign_keys=[receiver_id])