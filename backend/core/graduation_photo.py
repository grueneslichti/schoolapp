from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import uuid

UPLOAD_DIR = Path(__file__).parent.parent / "uploads"
GRADUATION_DIR = UPLOAD_DIR / "graduation"
GRADUATION_DIR.mkdir(parents=True, exist_ok=True)
THUMB_SIZE = 180
PADDING = 15
PER_ROW = 5
TITLE_HEIGHT = 90
BG_COLOR = (35, 45, 70)
TITLE_COLOR = (255, 255, 255)
PLACEHOLDER_COLOR = (90, 100, 130)

def _load_avatar(image_path: str | None) -> Image.Image | None:
    """Lädt ein Avatar-Bild vom Pfad."""
    if not image_path:
        return None
    full_path = Path(__file__).parent.parent / image_path
    if not full_path.exists():
        return None
    try:
        img = Image.open(full_path).convert("RGB")
        return img
    except Exception:
        return None

def _make_thumbnail(img: Image.Image | None, name: str) -> Image.Image:
    thumb = Image.new("RGB", (THUMB_SIZE, THUMB_SIZE), PLACEHOLDER_COLOR)  
    if img is not None:
        w, h = img.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img_cropped = img.crop((left, top, left + side, top + side))
        img_resized = img_cropped.resize((THUMB_SIZE, THUMB_SIZE), Image.Resampling.LANCZOS)
        thumb.paste(img_resized, (0, 0))
    else:
        draw = ImageDraw.Draw(thumb)
        initials = "".join([p[0].upper() for p in name.split()[:2]]) if name else "?"
        try:
            font = ImageFont.truetype("arial.ttf", 60)
        except Exception:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), initials, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text(((THUMB_SIZE - tw) // 2, (THUMB_SIZE - th) // 2 - 10), initials, fill=(220, 220, 230), font=font)
    return thumb

def generate_class_photo(students_data: list[dict], class_name: str, school_name: str, year: int) -> str:
    count = len(students_data)
    if count == 0:
        return None
    rows = (count + PER_ROW - 1) // PER_ROW
    cols = min(count, PER_ROW)
    canvas_width = cols * THUMB_SIZE + (cols + 1) * PADDING
    canvas_height = TITLE_HEIGHT + rows * THUMB_SIZE + (rows + 1) * PADDING + 40
    canvas = Image.new("RGB", (canvas_width, canvas_height), BG_COLOR)
    draw = ImageDraw.Draw(canvas)
    title = f"Klasse {class_name} – Abschluss {year}"
    subtitle = school_name
    try:
        title_font = ImageFont.truetype("arial.ttf", 32)
        sub_font = ImageFont.truetype("arial.ttf", 18)
    except Exception:
        title_font = ImageFont.load_default()
        sub_font = ImageFont.load_default()
    tbbox = draw.textbbox((0, 0), title, font=title_font)
    tw = tbbox[2] - tbbox[0]
    draw.text(((canvas_width - tw) // 2, 15), title, fill=TITLE_COLOR, font=title_font)
    sbbox = draw.textbbox((0, 0), subtitle, font=sub_font)
    sw = sbbox[2] - sbbox[0]
    draw.text(((canvas_width - sw) // 2, 55), subtitle, fill=(180, 190, 210), font=sub_font)
    for i, student in enumerate(students_data):
        row = i // PER_ROW
        col = i % PER_ROW
        items_in_row = min(PER_ROW, count - row * PER_ROW)
        row_width = items_in_row * THUMB_SIZE + (items_in_row - 1) * PADDING
        row_offset_x = (canvas_width - row_width) // 2
        x = row_offset_x + col * (THUMB_SIZE + PADDING)
        y = TITLE_HEIGHT + PADDING + row * (THUMB_SIZE + PADDING)
        avatar_path = student.get("anime_path") or student.get("avatar_path")
        img = _load_avatar(avatar_path)
        thumb = _make_thumbnail(img, student.get("name", ""))
        canvas.paste(thumb, (x, y))
        name = student.get("name", "")
        if len(name) > 14:
            name = name[:13] + "…"
        try:
            name_font = ImageFont.truetype("arial.ttf", 13)
        except Exception:
            name_font = ImageFont.load_default()
        nbbox = draw.textbbox((0, 0), name, font=name_font)
        nw = nbbox[2] - nbbox[0]
        draw.text((x + (THUMB_SIZE - nw) // 2, y + THUMB_SIZE - 18), name, fill=(230, 230, 240), font=name_font)
    filename = f"class_photo_{uuid.uuid4()}.jpg"
    file_path = GRADUATION_DIR / filename
    canvas.save(file_path, "JPEG", quality=90, optimize=True)
    return f"uploads/graduation/{filename}"