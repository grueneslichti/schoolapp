from pathlib import Path

from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # URL vom Server eintragen.!!!!
    DATABASE_URL: str = f"sqlite:///{(Path(__file__).resolve().parent.parent / 'app.db').as_posix()}"
    SECRET_KEY: str = "Super-Secret-Key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 5
    ADMIN_KEY: str ="Hallo" #Später in der env als richtiges Passwort eintragen
    WEEKLY_XP_GIFT_LIMIT: int = 15
    XP_PER_RATING: int = 1
    SD_FORGE_URL: str = "http://127.0.0.1:7860" #Zeichner aufruf derzeit Lokal
    KOBOLDAI_URL: str = "http://localhost:5001" #Chat LLM aufruf derzeit lokal
    class Config:
        env_file = ".env"

settings = Settings()