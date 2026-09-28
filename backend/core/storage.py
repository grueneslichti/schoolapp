import uuid
from pathlib import Path
from PIL import Image
import io

UPLOAD_DIR = Path(__file__).parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

def save_image_bytes(
    image_bytes: bytes,
    subfolder: str,
    max_width: int = 1920,
    max_height: int = 1080,
    quality: int = 85,
) -> str:
    img = Image.open(io.BytesIO(image_bytes))
    if img.mode in ('RGBA', 'P'):
        img = img.convert('RGB')
    img.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
    filename = f"{uuid.uuid4()}.jpg"
    subfolder_path = UPLOAD_DIR / subfolder
    subfolder_path.mkdir(exist_ok=True)
    file_path = subfolder_path / filename
    img.save(file_path, 'JPEG', quality=quality, optimize=True)
    return f"uploads/{subfolder}/{filename}"

def get_image_path(relative_path: str) -> Path | None:
    if not relative_path:
        return None
    path = Path(__file__).parent.parent / relative_path
    if path.exists():
        return path
    return None

def delete_image(relative_path: str) -> bool:
    """Löscht ein Bild vom Filesystem."""
    if not relative_path:
        return False
    path = Path(__file__).parent.parent / relative_path
    try:
        if path.exists():
            path.unlink()
            return True
    except Exception:
        pass
    return False