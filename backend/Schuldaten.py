from pydantic import BaseModel, Field, HttpUrl, ConfigDict
from typing import Optional
from enum import Enum
from datetime import datetime
import uuid

class SchoolLevel(str, Enum):
    PRIMARY = "primary"
    SECONDARY = "secondary"
    HIGH = "high"

class TicketCategory(str, Enum):
    LEARNING_ISSUE = "learning_issue"
    CONFLICT = "conflict"
    GENERAL_FEEDBACK = "general"

class ItemType(str, Enum):
    HAIR = "hair"
    TOP = "top"
    BOTTOM = "bottom"
    ACCESSORY = "accessory"

class SchoolBase(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    name: str = Field(..., max_length=100)
    country_code: str = Field(..., min_length=2, max_length=2)
    model_config = ConfigDict(from_attributes=True)

class ClassBase(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    school_id: uuid.UUID
    name: str = Field(..., max_length=20)
    level: SchoolLevel

class UserBase(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    pseudonym: str = Field(..., unique=True, max_length=64)
    class_id: uuid.UUID

class TaskBase(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    class_id: uuid.UUID
    subject: str = Field(..., max_length=50)
    title: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    due_date: datetime
    created_at: datetime = Field(default_factory=datetime.now)

class FeedbackTicketBase(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    school_id: uuid.UUID
    category: TicketCategory
    message: str = Field(..., max_length=1000)
    reporter_pseudonym: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.now)

class AvatarBase(BaseModel):
    user_pseudonym: str
    rpm_avatar_url: HttpUrl
    rpm_avatar_id: str = Field(..., max_length=64)

class AvatarItemBase(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    user_pseudonym: str
    item_id: str = Field(..., max_length=64)
    item_type: ItemType
    is_equipped: bool = False
    unlocked_at: datetime = Field(default_factory=datetime.now)