import uuid
import bcrypt
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status, Security
from fastapi.security import OAuth2PasswordBearer, APIKeyHeader
from sqlalchemy.orm import Session
from core.database import get_db 
from models import Teacher, Student
from core.config import settings
import secrets
import hmac
import hashlib

# In der fertigen App gehören diese Werte in eine .env !!!
SECRET_KEY = settings.SECRET_KEY
ALGORITHM = settings.ALGORITHM
ACCESS_TOKEN_EXPIRE_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES

def generate_easy_password(length=6):
    alphabet = "abcdefghijklmnpqrstuvwxyz23456789"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def get_password_hash(password: str) -> str:
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    password_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(password_bytes, hashed_bytes)
pwd_context = CryptContext(schemes=["bcrypt_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login/teacher")
admin_key_header = APIKeyHeader(name="x-admin-key", auto_error=False)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now() + expires_delta
    else:
        expire = datetime.now() + timedelta(minutes=10)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def generate_unique_login_name(db, real_name: str) -> str:
    if not real_name or not real_name.strip():
        return f"Schüler_{secrets.token_hex(4)}"
    real_name = real_name.strip()
    existing = db.query(Student).filter(Student.login_name == real_name).first()
    if not existing:
        return real_name
    n = 2
    while True:
        candidate = f"{real_name}_{n}"
        if not db.query(Student).filter(Student.login_name == candidate).first():
            return candidate
        n += 1

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str: str = payload.get("sub")
        role: str = payload.get("role") 
        if user_id_str is None or role is None:
            raise credentials_exception
        try:
            user_identifier = uuid.UUID(user_id_str)
        except ValueError:
            user_identifier = user_id_str
    except JWTError:
        raise credentials_exception
    user = None
    if role == "teacher":
        user = db.query(Teacher).filter(Teacher.id == user_identifier).first()
    elif role == "student":
        user = db.query(Student).filter(Student.id == user_identifier).first()
    if user is None:
        raise credentials_exception  
    return {"user": user, "role": role}

async def get_current_admin(
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "teacher":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Zugriff verweigert: Nur für Administrator gestattet."
        )
    teacher = current_user["user"]
    if not getattr(teacher, 'is_admin', False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Zugriff verweigert: Nur für Administrator gestattet."
        )
    return teacher

async def get_current_teacher(
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "teacher":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Zugriff verweigert: Nur für Lehrer gestattet."
        )
    return current_user["user"]

async def get_current_student(
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "student":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Zugriff verweigert: Nur für Schüler gestattet."
        )
    return current_user["user"]
from fastapi import Header
from core.config import settings

async def verify_admin(api_key: str = Security(admin_key_header)):
    if not api_key or api_key != settings.ADMIN_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ungültiger Admin-Key"
        )
    return True

def hash_student_id(student_id: str) -> str:
    return hmac.new(
        settings.SECRET_KEY.encode('utf-8'),
        student_id.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()